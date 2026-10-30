
import SwiftUI
import UIKit

enum GesturePadSlot: String {
    case through, shoot, pass, dash

    func label(attacking: Bool) -> String {
        switch self {
        case .through: return attacking ? "THROUGH" : "PRESS"
        case .shoot: return attacking ? "SHOOT" : "TACKLE"
        case .pass: return attacking ? "PASS" : "SWITCH"
        case .dash: return attacking ? "DASH" : "MATCH-UP"
        }
    }

    func command(attacking: Bool, swipe: PadSwipe?) -> PadCommand {
        if attacking {
            switch self {
            case .through:
                switch swipe {
                case .up: return .buttons(["l1", "triangle"])
                case .right: return .buttons(["l1", "r1", "triangle"])
                case .left: return .buttons(["r1", "triangle"])
                case .down: return .buttons(["l2", "triangle"])
                case nil: return .buttons(["triangle"])
                }
            case .shoot:
                switch swipe {
                case .up: return .buttons(["l1", "circle"])
                case .right: return .buttons(["l1", "r1", "circle"])
                case .left: return .buttons(["r1", "circle"])
                case .down: return .fakeShot
                case nil: return .buttons(["circle"])
                }
            case .pass:
                switch swipe {
                case .up: return .buttons(["square"])
                case .right: return .buttons(["r1", "cross"])
                case .left: return .buttons(["l1", "cross"])
                case .down: return .passFollow
                case nil: return .buttons(["cross"])
                }
            case .dash:
                return swipe == .left
                    ? .buttons(["r1"])
                    : .buttons(["r2"])
            }
        }

        switch self {
        case .through:
            switch swipe {
            case .up: return .buttons(["r1"])
            case .right: return .buttons(["r2", "cross"])
            case .down: return .buttons(["triangle"])
            default: return .buttons(["cross"])
            }
        case .shoot:
            switch swipe {
            case .up, .left: return .buttons(["square"])
            case .right: return .buttons(["r1", "circle"])
            default: return .buttons(["circle"])
            }
        case .pass:
            switch swipe {
            case .up: return .rightStick(x: 0, y: 1)
            case .down: return .rightStick(x: 0, y: -1)
            case .left: return .rightStick(x: -1, y: 0)
            case .right: return .rightStick(x: 1, y: 0)
            case nil: return .buttons(["l1"])
            }
        case .dash:
            switch swipe {
            case .up: return .buttons(["l2", "r2"])
            case .right, .left: return .buttons(["r2"])
            default: return .buttons(["l2"])
            }
        }
    }

    func selectedLabel(attacking: Bool, swipe: PadSwipe?) -> String {
        guard let swipe else { return label(attacking: attacking) }
        if attacking {
            switch self {
            case .shoot:
                switch swipe {
                case .up: return "CHIP"
                case .left: return "FINESSE"
                case .right: return "POWER"
                case .down: return "FAKE SHOT"
                }
            case .pass:
                switch swipe {
                case .up: return "CROSS"
                case .left: return "PASS & GO"
                case .right: return "DRIVEN"
                case .down: return "PASS & FOLLOW"
                }
            case .through:
                switch swipe {
                case .up: return "LOB THROUGH"
                case .left: return "R1 THROUGH"
                case .right: return "L1+R1 THROUGH"
                case .down: return "FLAIR THROUGH"
                }
            case .dash: return swipe == .left ? "R1" : "DASH"
            }
        }
        switch self {
        case .through: return swipe == .up ? "2ND PRESS" : "PRESS"
        case .shoot: return swipe == .right ? "HARD TACKLE" : "SLIDE"
        case .pass: return "SELECT"
        case .dash: return swipe == .up ? "SPRINT JOCKEY" : "SPRINT"
        }
    }
}

enum PadSwipe {
    case up, down, left, right

    static func detect(_ movement: CGSize, threshold: CGFloat = 22) -> PadSwipe? {
        guard hypot(movement.width, movement.height) >= threshold else {
            return nil
        }
        if abs(movement.width) > abs(movement.height) {
            return movement.width > 0 ? .right : .left
        }
        return movement.height < 0 ? .up : .down
    }
}

enum PadCommand {
    case buttons([String])
    case rightStick(x: CGFloat, y: CGFloat)
    case fakeShot
    case passFollow
}

struct GesturePadButton: View {
    let slot: GesturePadSlot
    let attacking: Bool
    let diameter: CGFloat

    @EnvironmentObject private var controller: ControllerModel
    @State private var touching = false
    @State private var gestureID = 0
    @State private var startedAt = Date.distantPast
    @State private var pressedAt = Date.distantPast
    @State private var source = ""
    @State private var current: PadCommand?
    @State private var selectedSwipe: PadSwipe?
    @State private var consumed = false
    @State private var timer: Task<Void, Never>?
    @State private var pendingPass: Task<Void, Never>?
    @State private var lastPassTap = Date.distantPast
    @State private var lastThroughTap = Date.distantPast
    @State private var lastShotRelease = Date.distantPast

    private var selectionDelay: UInt64 {
        switch slot {
        case .shoot: return 230
        case .pass, .through: return 120
        case .dash: return 0
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(touching ? Color.green.opacity(0.85) : Color(
                    red: 0.20, green: 0.38, blue: 0.30
                ))
            Circle().stroke(Color.green.opacity(0.55), lineWidth: 4)
            Text(slot.selectedLabel(attacking: attacking, swipe: selectedSwipe))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.65)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
            if !touching && slot != .dash {
                Text("↑").offset(y: -diameter * 0.38)
                Text("→").offset(x: diameter * 0.38)
                Text("←").offset(x: -diameter * 0.38)
            }
        }
        .foregroundStyle(.white.opacity(0.8))
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged(change)
                .onEnded { _ in endTouch() }
        )
        .onChange(of: attacking) { _ in cancelTouch() }
        .onChange(of: controller.cancellationEpoch) { _ in cancelTouch() }
        .onDisappear { cancelTouch() }
    }

    private func change(_ drag: DragGesture.Value) {
        if !touching { beginTouch() }
        guard !consumed, selectedSwipe == nil else { return }
        guard Date().timeIntervalSince(startedAt) < 0.40 else { return }
        guard let swipe = PadSwipe.detect(drag.translation) else { return }
        // Once charging started, a flick cannot rewrite the action.
        guard current == nil || slot == .dash else { return }
        timer?.cancel()
        timer = nil
        selectedSwipe = swipe
        if slot == .dash { releaseCurrent() }
        activate(slot.command(attacking: attacking, swipe: swipe))
    }

    private func beginTouch() {
        touching = true
        gestureID &+= 1
        startedAt = Date()
        pressedAt = .distantPast
        source = "gesture.\(slot.rawValue).\(gestureID)"
        current = nil
        selectedSwipe = nil
        consumed = false
        timer?.cancel()

        // Defer only a quick PASS tap so the second tap can replace it
        // with one Pass & Follow combination, avoiding two passes.
        if attacking && slot == .pass && pendingPass != nil &&
            Date().timeIntervalSince(lastPassTap) < 0.29 {
            pendingPass?.cancel()
            pendingPass = nil
            consumed = true
            controller.playCombo(modifiers: ["l1", "r1"], action: "cross")
            return
        }

        // A second SHOOT tap shortly after releasing a charged shot
        // supplies the FC low-driven modifier (not available for chip).
        if attacking && slot == .shoot &&
            Date().timeIntervalSince(lastShotRelease) < 0.38 {
            let elapsed = Date().timeIntervalSince(lastShotRelease)
            let gap = UInt64(max(0, 0.16 - elapsed) * 1000)
            lastShotRelease = .distantPast
            consumed = true
            controller.playSequence([
                InputStep([], gap),
                InputStep(["circle"], 95),
                InputStep([], 35)
            ])
            return
        }

        if slot == .dash {
            activate(slot.command(attacking: attacking, swipe: nil))
        } else {
            let id = gestureID
            timer = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(selectionDelay))
                if Task.isCancelled { return }
                guard touching, gestureID == id,
                      !consumed, current == nil else { return }
                activate(slot.command(attacking: attacking, swipe: nil))
            }
        }
    }

    private func activate(_ command: PadCommand) {
        guard touching else { return }
        pressedAt = Date()
        current = command
        switch command {
        case .buttons(let keys):
            controller.setHold(source: source, keys: keys, down: true)
        case .rightStick(let x, let y):
            controller.setStick(left: false, x: x, y: y)
        case .fakeShot:
            consumed = true
            controller.fakeShot()
        case .passFollow:
            consumed = true
            controller.playCombo(modifiers: ["l1", "r1"], action: "cross")
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func endTouch() {
        guard touching else { return }
        timer?.cancel()
        timer = nil
        let wasQuick = current == nil && selectedSwipe == nil && !consumed
        let now = Date()

        if wasQuick && attacking && slot == .pass {
            lastPassTap = now
            let id = gestureID
            pendingPass?.cancel()
            pendingPass = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(215))
                if Task.isCancelled { return }
                guard id == gestureID else { return }
                controller.tap(["cross"])
                pendingPass = nil
            }
        } else if wasQuick && attacking && slot == .through {
            // Two distinct triangle pulses trigger FC 27's dinked through.
            let since = now.timeIntervalSince(lastThroughTap)
            lastThroughTap = now
            if since < 0.16 {
                let remaining = UInt64((0.16 - since) * 1000)
                controller.playSequence([
                    InputStep([], remaining),
                    InputStep(["triangle"], 95),
                    InputStep([], 35)
                ])
            } else {
                controller.tap(["triangle"])
            }
        } else if wasQuick && !consumed {
            activate(slot.command(attacking: attacking, swipe: nil))
        }

        let finishing = current
        let finishingSource = source
        let elapsed = Date().timeIntervalSince(pressedAt)
        let remaining = max(0, 0.11 - elapsed)

        if attacking && slot == .shoot && !consumed &&
            selectedSwipe != .up && finishing != nil {
            lastShotRelease = now
        }

        touching = false
        current = nil
        selectedSwipe = nil
        consumed = false
        let delay = UInt64(remaining * 1000)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delay))
            release(finishing, source: finishingSource)
        }
    }

    private func release(_ command: PadCommand?, source: String) {
        guard let command else { return }
        switch command {
        case .buttons(let keys):
            if keys.count > 1 {
                controller.setHold(source: source, keys: Array(keys.dropLast()), down: true)
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(45))
                    controller.setHold(source: source, keys: [], down: false)
                }
            } else {
                controller.setHold(source: source, keys: [], down: false)
            }
        case .rightStick:
            controller.setStick(left: false, x: 0, y: 0)
        case .fakeShot, .passFollow:
            break
        }
    }

    private func releaseCurrent() {
        release(current, source: source)
        current = nil
        source += ".swipe"
    }

    private func cancelTouch() {
        timer?.cancel()
        timer = nil
        pendingPass?.cancel()
        pendingPass = nil
        timer?.cancel()
        controller.setHold(source: source, keys: [], down: false)
        if case .rightStick? = current {
            controller.setStick(left: false, x: 0, y: 0)
        }
        current = nil
        touching = false
        consumed = false
        selectedSwipe = nil
        lastShotRelease = .distantPast
        lastPassTap = .distantPast
        lastThroughTap = .distantPast
        gestureID &+= 1
    }
}
