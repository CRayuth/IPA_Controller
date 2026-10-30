
import Foundation
import Network
import SwiftUI
import UIKit

private struct InputPacket: Encodable {
    let v = 1
    let token: String
    let seq: UInt32
    let lx: Double
    let ly: Double
    let rx: Double
    let ry: Double
    let buttons: [String]
}

private struct ReceiverAck: Decodable {
    let v: Int
    let type: String
    let token: String
    let mode: String?
    let confidence: Double?
}

struct InputStep {
    let buttons: [String]
    let milliseconds: UInt64

    init(_ buttons: [String], _ milliseconds: UInt64) {
        self.buttons = buttons
        self.milliseconds = milliseconds
    }
}

@MainActor
final class ControllerModel: ObservableObject {
    @Published var host = UserDefaults.standard.string(forKey: "pcHost") ?? ""
    @Published var pin = ""
    @Published private(set) var streaming = false
    @Published private(set) var paired = false
    @Published private(set) var message = "Enter your PC address and PIN"
    @Published private(set) var leftStick = CGPoint.zero
    @Published private(set) var rightStick = CGPoint.zero
    @Published private(set) var detectedMode: String?
    @Published private(set) var detectionConfidence = 0.0
    @Published private(set) var cancellationEpoch = 0

    @Published var autoModeEnabled =
        UserDefaults.standard.bool(forKey: "touchpadfc.autoMode.v4") {
        didSet {
            UserDefaults.standard.set(
                autoModeEnabled,
                forKey: "touchpadfc.autoMode.v4"
            )
        }
    }

    private var holds: [String: Set<String>] = [:]
    private var sequences: [UUID: Task<Void, Never>] = [:]
    private var connection: NWConnection?
    private var clock: Timer?
    private var sequenceNumber: UInt32 = 0
    private var lastAck = Date.distantPast

    func connect() {
        let ip = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard IPv4Address(ip) != nil else {
            message = "Enter your Windows PC IPv4 address"
            return
        }
        guard pin.count == 6,
              pin.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            message = "Enter the six-digit PIN shown in PowerShell"
            return
        }

        disconnect()
        host = ip
        UserDefaults.standard.set(ip, forKey: "pcHost")
        sequenceNumber = 0
        message = "Connecting…"

        let next = NWConnection(
            host: .init(ip),
            port: .init(rawValue: 52777)!,
            using: .udp
        )
        connection = next
        next.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self, self.connection === next else { return }
                switch state {
                case .ready:
                    self.startStreaming(on: next)
                case .failed(let error):
                    self.disconnect()
                    self.message = "Network error: \(error.localizedDescription)"
                default:
                    break
                }
            }
        }
        next.start(queue: DispatchQueue(label: "touchpadfc.udp"))
    }

    func disconnect() {
        releaseInputs()
        if connection != nil { sendPacket() }
        clock?.invalidate()
        clock = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        streaming = false
        paired = false
        detectedMode = nil
        detectionConfidence = 0
        lastAck = .distantPast
        message = "Disconnected"
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func releaseInputs() {
        stopSequences()
        holds.removeAll()
        leftStick = .zero
        rightStick = .zero
        cancellationEpoch &+= 1
    }

    func setHold(source: String, keys: [String], down: Bool) {
        if down && !keys.isEmpty {
            holds[source] = Set(keys)
        } else {
            holds.removeValue(forKey: source)
        }
    }

    func isHeld(_ source: String) -> Bool {
        holds[source] != nil
    }

    func setStick(left: Bool, x: CGFloat, y: CGFloat) {
        let point = CGPoint(
            x: max(-1, min(1, x)),
            y: max(-1, min(1, y))
        )
        if left { leftStick = point } else { rightStick = point }
    }

    // Each sequence owns only its own source, so other held buttons are safe.
    // A stage is a full button snapshot for that source, not a key-up event.
    func playSequence(_ steps: [InputStep]) {
        guard paired, !steps.isEmpty else { return }
        let id = UUID()
        let source = "sequence.\(id.uuidString)"
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            for step in steps {
                if Task.isCancelled { break }
                self.setHold(source: source, keys: step.buttons, down: true)
                do {
                    try await Task.sleep(for: .milliseconds(step.milliseconds))
                } catch {
                    break
                }
            }
            self.setHold(source: source, keys: [], down: false)
            self.sequences.removeValue(forKey: id)
        }
        sequences[id] = task
    }

    func tap(_ keys: [String], duration: UInt64 = 95) {
        playSequence([InputStep(keys, duration), InputStep([], 35)])
    }

    func playCombo(modifiers: [String], action: String) {
        playSequence([
            InputStep(modifiers, 45),
            InputStep(modifiers + [action], 110),
            InputStep(modifiers, 45),
            InputStep([], 35)
        ])
    }

    func fakeShot() {
        playSequence([
            InputStep(["circle"], 85),
            InputStep([], 30),
            InputStep(["cross"], 95),
            InputStep([], 35)
        ])
    }

    // Custom eFootball-style gesture, not a native FC touchscreen action.
    // FC shot/pass cancel is commonly L2+R2; it only works before contact.
    func cancelKick() {
        stopSequences()
        let kickKeys: Set<String> = ["cross", "circle", "square", "triangle"]
        for source in Array(holds.keys) {
            guard let current = holds[source] else { continue }
            let remaining = current.subtracting(kickKeys)
            setHold(source: source, keys: Array(remaining), down: !remaining.isEmpty)
        }
        cancellationEpoch &+= 1
        playSequence([
            InputStep(["l2", "r2"], 170),
            InputStep([], 40)
        ])
    }

    private func stopSequences() {
        for task in sequences.values { task.cancel() }
        sequences.removeAll()
        for source in Array(holds.keys) where source.hasPrefix("sequence.") {
            holds.removeValue(forKey: source)
        }
    }

    private func startStreaming(on current: NWConnection) {
        guard !streaming else { return }
        streaming = true
        paired = false
        message = "Waiting for PC confirmation…"
        UIApplication.shared.isIdleTimerDisabled = true
        receiveAck(on: current)
        sendPacket()
        clock = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.paired && Date().timeIntervalSince(self.lastAck) > 2.0 {
                    self.paired = false
                    self.detectedMode = nil
                    self.detectionConfidence = 0
                    self.message = "PC stopped responding"
                    self.releaseInputs()
                }
                self.sendPacket()
            }
        }
    }

    private func receiveAck(on current: NWConnection) {
        current.receiveMessage { [weak self] data, _, _, error in
            Task { @MainActor [weak self] in
                guard let self, self.connection === current else { return }
                if let data,
                   let ack = try? JSONDecoder().decode(ReceiverAck.self, from: data),
                   ack.v == 1,
                   ack.type == "ack",
                   ack.token == self.pin {
                    self.lastAck = Date()
                    self.paired = true
                    self.message = "PC connected"
                    self.detectedMode = (ack.mode == "attack" || ack.mode == "defend")
                        ? ack.mode : nil
                    self.detectionConfidence = max(0, min(1, ack.confidence ?? 0))
                }
                if error == nil {
                    self.receiveAck(on: current)
                } else {
                    self.paired = false
                    self.detectedMode = nil
                    self.message = "Receiver connection lost"
                    self.releaseInputs()
                }
            }
        }
    }

    private func sendPacket() {
        guard let connection else { return }
        let packet = InputPacket(
            token: pin,
            seq: sequenceNumber,
            lx: Double(leftStick.x),
            ly: Double(leftStick.y),
            rx: Double(rightStick.x),
            ry: Double(rightStick.y),
            buttons: Set(holds.values.flatMap { $0 }).sorted()
        )
        sequenceNumber &+= 1
        guard let bytes = try? JSONEncoder().encode(packet) else { return }
        connection.send(content: bytes, completion: .contentProcessed { _ in })
    }
}
