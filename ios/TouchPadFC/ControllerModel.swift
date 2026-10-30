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

// A step replaces only this sequence's held keys and optional right-stick position.
// nil for rightStick means return the scripted stick to neutral.
struct InputStep {
    let buttons: [String]
    let milliseconds: UInt64
    let rightStick: CGPoint?

    init(_ buttons: [String], _ milliseconds: UInt64, rightStick: CGPoint? = nil) {
        self.buttons = buttons
        self.milliseconds = milliseconds
        self.rightStick = rightStick
    }

    static func neutral(_ ms: UInt64 = 45) -> InputStep { InputStep([], ms) }
    static func flick(_ point: CGPoint, modifiers: [String] = [], duration: UInt64 = 95) -> [InputStep] {
        [InputStep(modifiers, 45),
         InputStep(modifiers, duration, rightStick: point),
         InputStep(modifiers, 45),
         .neutral()]
    }
}

@MainActor
final class ControllerModel: ObservableObject {
    @Published var host = UserDefaults.standard.string(forKey: "pcHost") ?? ""
    @Published var port = UserDefaults.standard.string(forKey: "pcPort") ?? "52777"
    @Published var pin = ""
    @Published private(set) var streaming = false
    @Published private(set) var paired = false
    @Published private(set) var message = "Enter PC address and pairing PIN"
    @Published private(set) var leftStick = CGPoint.zero
    @Published private(set) var rightStick = CGPoint.zero
    @Published private(set) var detectedMode: String?
    @Published private(set) var detectionConfidence = 0.0
    @Published private(set) var cancellationEpoch = 0
    @Published var autoModeEnabled = UserDefaults.standard.bool(forKey: "touchpadfc.autoMode.v4") {
        didSet { UserDefaults.standard.set(autoModeEnabled, forKey: "touchpadfc.autoMode.v4") }
    }

    private var holds: [String: Set<String>] = [:]
    private var manualRightStick = CGPoint.zero
    private var scriptedRightStick: [String: CGPoint] = [:]
    private var scriptOrder: [String] = []
    private var sequenceTasks: [String: Task<Void, Never>] = [:]
    private var sequenceOwners: [String: String] = [:]
    private var connection: NWConnection?
    private var clock: Timer?
    private var sequenceNumber: UInt32 = 0
    private var lastAck = Date.distantPast

    func connect() {
        let ip = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard IPv4Address(ip) != nil else {
            message = "Enter a valid PC IPv4 address"
            return
        }
        let portText = port.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let portNumber = UInt16(portText), portNumber > 0 else {
            message = "Enter the receiver UDP port (1-65535)"
            return
        }
        guard pin.count == 6, pin.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            message = "Enter the six-digit PIN from PowerShell"
            return
        }

        disconnect()
        host = ip
        port = portText
        UserDefaults.standard.set(ip, forKey: "pcHost")
        UserDefaults.standard.set(portText, forKey: "pcPort")
        sequenceNumber = 0
        message = "Connecting…"

        let next = NWConnection(host: NWEndpoint.Host(ip),
                                port: NWEndpoint.Port(rawValue: portNumber)!, using: .udp)
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
                default: break
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
        for task in sequenceTasks.values { task.cancel() }
        sequenceTasks.removeAll()
        sequenceOwners.removeAll()
        holds.removeAll()
        scriptedRightStick.removeAll()
        scriptOrder.removeAll()
        manualRightStick = .zero
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

    func isHeld(_ source: String) -> Bool { holds[source] != nil }

    func setStick(left: Bool, x: CGFloat, y: CGFloat) {
        let point = CGPoint(x: max(-1, min(1, x)), y: max(-1, min(1, y)))
        if left {
            leftStick = point
        } else {
            manualRightStick = point
            refreshRightStick()
        }
    }

    // Used by continuous stick actions in the advanced action sheet.
    func setRightStickHold(source: String, x: CGFloat, y: CGFloat, down: Bool) {
        if down {
            setScriptRight(CGPoint(x: max(-1, min(1, x)), y: max(-1, min(1, y))), source: source)
        } else {
            setScriptRight(nil, source: source)
        }
    }

    private func setScriptRight(_ point: CGPoint?, source: String) {
        if let point {
            scriptedRightStick[source] = point
            scriptOrder.removeAll { $0 == source }
            scriptOrder.append(source)
        } else {
            scriptedRightStick.removeValue(forKey: source)
            scriptOrder.removeAll { $0 == source }
        }
        refreshRightStick()
    }

    private func refreshRightStick() {
        if let source = scriptOrder.last, let point = scriptedRightStick[source] {
            rightStick = point
        } else {
            rightStick = manualRightStick
        }
    }

    // Named channels prevent two copies of the same scripted action overlapping.
    // Old tasks use unique input sources, so cancellation cannot clear a newer action.
    func playSequence(_ steps: [InputStep], channel: String = UUID().uuidString) {
        guard paired, !steps.isEmpty else { return }
        cancelSequence(channel)
        let owner = UUID().uuidString
        let source = "sequence.\(owner)"
        sequenceOwners[channel] = source
        sequenceTasks[channel] = Task { @MainActor [weak self] in
            guard let self else { return }
            for step in steps {
                if Task.isCancelled { break }
                self.setHold(source: source, keys: step.buttons, down: true)
                self.setScriptRight(step.rightStick, source: source)
                do {
                    try await Task.sleep(for: .milliseconds(Int(step.milliseconds)))
                } catch { break }
            }
            self.setHold(source: source, keys: [], down: false)
            self.setScriptRight(nil, source: source)
            if self.sequenceOwners[channel] == source {
                self.sequenceOwners.removeValue(forKey: channel)
                self.sequenceTasks.removeValue(forKey: channel)
            }
        }
    }

    func cancelSequence(_ channel: String) {
        sequenceTasks[channel]?.cancel()
        sequenceTasks.removeValue(forKey: channel)
        if let source = sequenceOwners.removeValue(forKey: channel) {
            setHold(source: source, keys: [], down: false)
            setScriptRight(nil, source: source)
        }
    }

    func tap(_ keys: [String], duration: UInt64 = 100, channel: String = UUID().uuidString) {
        playSequence([InputStep(keys, duration), .neutral()], channel: channel)
    }

    func combo(_ modifiers: [String], _ key: String, channel: String = UUID().uuidString) {
        playSequence([
            InputStep(modifiers, 50),
            InputStep(modifiers + [key], 105),
            InputStep(modifiers, 45),
            .neutral()
        ], channel: channel)
    }

    // Compatibility for older set-piece/gesture callers.
    func playCombo(modifiers: [String], action: String) { combo(modifiers, action) }

    func doubleTap(_ key: String, modifiers: [String] = [], channel: String = UUID().uuidString) {
        playSequence([
            InputStep(modifiers + [key], 95),
            InputStep(modifiers, 75),
            InputStep(modifiers + [key], 95),
            InputStep(modifiers, 40), .neutral()
        ], channel: channel)
    }

    func fakeShot() {
        playSequence([
            InputStep(["circle"], 75),
            InputStep(["circle", "cross"], 55),
            InputStep(["cross"], 75), .neutral()
        ], channel: "fake")
    }

    func fakePass() {
        playSequence([
            InputStep(["square"], 75),
            InputStep(["square", "cross"], 55),
            InputStep(["cross"], 75), .neutral()
        ], channel: "fake")
    }

    func lowDriven(modifiers: [String] = [], chargeMilliseconds: UInt64 = 370) {
        playSequence([
            InputStep(modifiers, 45),
            InputStep(modifiers + ["circle"], chargeMilliseconds),
            InputStep(modifiers, 50),
            InputStep(modifiers + ["circle"], 90),
            InputStep(modifiers, 45), .neutral()
        ], channel: "shot")
    }

    func flickRight(x: CGFloat, y: CGFloat, modifiers: [String] = [], channel: String = "rightFlick") {
        playSequence(InputStep.flick(CGPoint(x: x, y: y), modifiers: modifiers), channel: channel)
    }

    func dPadSequence(_ directions: [String]) {
        var steps: [InputStep] = []
        for direction in directions {
            steps.append(InputStep([direction], 100))
            steps.append(.neutral(95))
        }
        playSequence(steps, channel: "tactics")
    }

    // Hard Super Cancel is NOT guaranteed to undo an already-triggered animation.
    func cancelKick() {
        releaseInputs()
        playSequence([
            InputStep(["l1", "r1", "l2", "r2"], 160),
            .neutral()
        ], channel: "cancel")
    }

    private func startStreaming(on current: NWConnection) {
        guard !streaming else { return }
        streaming = true
        paired = false
        message = "Waiting for PC confirmation…"
        UIApplication.shared.isIdleTimerDisabled = true
        receiveAck(on: current)
        sendPacket()
        clock = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.paired && Date().timeIntervalSince(self.lastAck) > 2 {
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
                   ack.v == 1, ack.type == "ack", ack.token == self.pin {
                    self.lastAck = Date()
                    self.paired = true
                    self.message = "PC connected"
                    self.detectedMode = ["attack", "defend"].contains(ack.mode ?? "") ? ack.mode : nil
                    self.detectionConfidence = max(0, min(1, ack.confidence ?? 0))
                }
                if error == nil { self.receiveAck(on: current) }
                else {
                    self.paired = false
                    self.message = "Receiver connection lost"
                    self.releaseInputs()
                }
            }
        }
    }

    private func sendPacket() {
        guard let connection else { return }
        let packet = InputPacket(
            token: pin, seq: sequenceNumber,
            lx: Double(leftStick.x), ly: Double(leftStick.y),
            rx: Double(rightStick.x), ry: Double(rightStick.y),
            buttons: Set(holds.values.flatMap { $0 }).sorted()
        )
        sequenceNumber &+= 1
        guard let bytes = try? JSONEncoder().encode(packet) else { return }
        connection.send(content: bytes, completion: .contentProcessed { _ in })
    }
}
