import SwiftUI
import UIKit

enum GesturePadSlot: String {
    case through, shoot, pass, dash

    func label(attacking: Bool) -> String {
        if attacking { return rawValue.uppercased() }
        switch self {
        case .through: return "PRESS"
        case .shoot: return "TACKLE"
        case .pass: return "SWITCH"
        case .dash: return "MATCH-UP"
        }
    }

    func keys(attacking: Bool, swipe: PadSwipe?) -> [String] {
        if attacking {
            switch self {
            case .through:
                switch swipe {
                case .up: return ["l1", "triangle"]
                case .left: return ["r1", "triangle"]
                case .right: return ["l1", "r1", "triangle"]
                case .down: return ["l2", "triangle"]
                case nil: return ["triangle"]
                }
            case .shoot:
                switch swipe {
                case .up: return ["l1", "circle"]
                case .left: return ["r1", "circle"]
                case .right: return ["l1", "r1", "circle"]
                case .down: return [] // Fake shot is a sequence.
                case nil: return ["circle"]
                }
            case .pass:
                switch swipe {
                case .up: return ["square"]
                case .left: return ["l1", "cross"]
                case .right: return ["r1", "cross"]
                case .down: return [] // Pass & Follow is a sequence.
                case nil: return ["cross"]
                }
            case .dash: return swipe == .left ? ["r1"] : ["r2"]
            }
        }
        switch self {
        case .through:
            switch swipe {
            case .up: return ["r1"] // Teammate contain
            case .right: return ["r1", "cross"] // Professional foul; context-sensitive
            case .down: return ["triangle"] // Keeper rush
            default: return ["cross"] // Advanced physical tackle / Tactical contain
            }
        case .shoot:
            switch swipe {
            case .up, .left: return ["square"]
            case .right: return ["r1", "circle"]
            case .down: return ["r1", "square"]
            case nil: return ["circle"]
            }
        case .pass: return swipe == nil ? ["l1"] : [] // Swipes: right-stick flick.
        case .dash:
            switch swipe {
            case .up: return ["l2", "r2"]
            case .left, .right: return ["r2"]
            default: return ["l2"]
            }
        }
    }

    func swipeTitle(attacking: Bool, swipe: PadSwipe?) -> String {
        guard let swipe else { return label(attacking: attacking) }
        if attacking {
            switch self {
            case .through:
                switch swipe {
                case .up: return "LOB"
                case .left: return "PRECISION"
                case .right: return "DRIVEN"
                case .down: return "FLAIR"
                }
            case .shoot:
                switch swipe {
                case .up: return "CHIP"
                case .left: return "CURVE"
                case .right: return "POWER"
                case .down: return "FAKE"
                }
            case .pass:
                switch swipe {
                case .up: return "CROSS"
                case .left: return "PASS & GO"
                case .right: return "DRIVEN"
                case .down: return "FOLLOW"
                }
            case .dash: return swipe == .left ? "CONTROL" : "DASH"
            }
        }
        switch self {
        case .through: return swipe == .up ? "2ND PRESS" : "PRESS"
        case .shoot: return swipe == .right ? "HARD" : "SLIDE"
        case .pass: return "SWITCH"
        case .dash: return swipe == .up ? "SPRINT JOCKEY" : "MATCH-UP"
        }
    }
}

enum PadSwipe { case up, down, left, right
    static func detect(_ size: CGSize) -> PadSwipe? {
        guard hypot(size.width, size.height) > 22 else { return nil }
        if abs(size.width) > abs(size.height) { return size.width > 0 ? .right : .left }
        return size.height < 0 ? .up : .down
    }

    var point: CGPoint {
        switch self {
        case .up: return CGPoint(x: 0, y: 1)
        case .down: return CGPoint(x: 0, y: -1)
        case .left: return CGPoint(x: -1, y: 0)
        case .right: return CGPoint(x: 1, y: 0)
        }
    }
}

struct GesturePadButton: View {
    let slot: GesturePadSlot
    let attacking: Bool
    let diameter: CGFloat

    @EnvironmentObject private var controller: ControllerModel
    @AppStorage("touchpadfc.instantPass") private var instantPass = false
    @State private var touching = false
    @State private var currentID = 0
    @State private var started = Date.distantPast
    @State private var source = ""
    @State private var activeKeys: [String] = []
    @State private var selectedSwipe: PadSwipe?
    @State private var actionStarted = Date.distantPast
    @State private var activation: Task<Void, Never>?
    @State private var pendingSingle: Task<Void, Never>?
    @State private var lastTap = Date.distantPast
    @State private var secondTap = false
    @State private var lastShotEnd = Date.distantPast
    @State private var followUpShot = false

    var body: some View {
        ZStack {
            Circle().fill(touching ? Color.green.opacity(0.83) : Color(red: 0.17, green: 0.37, blue: 0.28))
            Circle().stroke(Color.green.opacity(0.6), lineWidth: 3)
            Text(slot.swipeTitle(attacking: attacking, swipe: selectedSwipe))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6).lineLimit(2).multilineTextAlignment(.center)
                .padding(.horizontal, 6).foregroundStyle(.white)
            if slot == .dash && attacking && !touching {
                Text("×2 CURVE").font(.system(size: 7, weight: .bold))
                    .offset(y: diameter * 0.30)
            }
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { gesture in changed(gesture) }
            .onEnded { _ in ended() })
        .onChange(of: attacking) { _ in reset() }
        .onChange(of: controller.cancellationEpoch) { _ in reset() }
        .onDisappear { reset() }
    }

    private func changed(_ gesture: DragGesture.Value) {
        if !touching { began() }
        guard selectedSwipe == nil, Date().timeIntervalSince(started) < 0.38 else { return }
        guard let swipe = PadSwipe.detect(gesture.translation) else { return }
        // Never replace an already-charging pass/shot with a different shot type.
        guard activeKeys.isEmpty || slot == .dash else { return }
        selectedSwipe = swipe
        activation?.cancel()
        activation = nil
        secondTap = false
        pendingSingle?.cancel()
        pendingSingle = nil
        lastTap = .distantPast

        if !activeKeys.isEmpty {
            controller.setHold(source: source, keys: [], down: false)
            activeKeys = []
        }
        if !attacking && slot == .pass {
            let p = swipe.point
            controller.flickRight(x: p.x, y: p.y, channel: "switch")
        } else if attacking && slot == .shoot && swipe == .down {
            controller.fakeShot()
        } else if attacking && slot == .pass && swipe == .down {
            controller.combo(["l1", "r1"], "cross", channel: "passFollow")
        } else {
            press(slot.keys(attacking: attacking, swipe: swipe))
        }
    }

    private func began() {
        touching = true
        currentID &+= 1
        started = Date()
        actionStarted = .distantPast
        source = "gesture.\(slot.rawValue).\(currentID)"
        selectedSwipe = nil
        activeKeys = []
        followUpShot = false
        secondTap = false
        activation?.cancel()

        if attacking && slot == .shoot && Date().timeIntervalSince(lastShotEnd) < 0.35 {
            lastShotEnd = .distantPast
            followUpShot = true
            // The first shot may still be releasing asynchronously. Delay the
            // follow-up pulse to ensure FC sees a real button-up interval.
            controller.playSequence([
                InputStep.neutral(125),
                InputStep(["circle"], 95),
                .neutral()
            ], channel: "shotFollowUp")
            return
        }

        if attacking && (slot == .pass || slot == .through || slot == .dash) &&
           Date().timeIntervalSince(lastTap) < 0.29 && pendingSingle != nil {
            pendingSingle?.cancel()
            pendingSingle = nil
            secondTap = true
            let id = currentID
            activation = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(170))
                guard !Task.isCancelled, touching, currentID == id, secondTap else { return }
                secondTap = false
                // Long second press is normal held action, not a double-tap.
                if slot == .dash { press(["r2"]) }
                else { press(slot.keys(attacking: attacking, swipe: nil)) }
            }
            return
        }

        if slot == .dash { press(slot.keys(attacking: attacking, swipe: nil)) }
        else {
            let id = currentID
            activation = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(slot == .shoot ? 170 : 155))
                guard !Task.isCancelled, touching, currentID == id,
                      activeKeys.isEmpty, selectedSwipe == nil else { return }
                press(slot.keys(attacking: attacking, swipe: nil))
            }
        }
    }

    private func press(_ keys: [String]) {
        guard touching, !keys.isEmpty else { return }
        activeKeys = keys
        actionStarted = Date()
        controller.setHold(source: source, keys: keys, down: true)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func ended() {
        guard touching else { return }
        activation?.cancel()
        activation = nil
        let now = Date()
        let wasSwipe = selectedSwipe != nil
        let wasSecond = secondTap
        let isFollowUp = followUpShot
        let held = activeKeys
        let localSource = source
        let age = now.timeIntervalSince(started)
        let downAge = now.timeIntervalSince(actionStarted)
        touching = false
        secondTap = false
        followUpShot = false
        activeKeys = []
        selectedSwipe = nil

        if wasSecond && !wasSwipe && age < 0.17 {
            lastTap = .distantPast
            if attacking {
                switch slot {
                case .pass: controller.combo(["l1", "r1"], "cross", channel: "passFollow")
                case .through: controller.doubleTap("triangle", channel: "through")
                case .dash: controller.tap(["l1", "r1"], channel: "curvedRun")
                case .shoot: break
                }
            }
            return
        }

        if isFollowUp { return }

        if !held.isEmpty {
            if attacking && slot == .shoot && !wasSwipe && downAge > 0.16 {
                lastShotEnd = now
            } else if attacking && slot == .shoot && wasSwipe && downAge > 0.16 {
                // Low-driven follow-up can also follow finesse/power.
                if held.contains("circle") && !held.contains("l1") { lastShotEnd = now }
            }
            let epoch = controller.cancellationEpoch
            let delay = UInt64(max(0, 0.10 - downAge) * 1000)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(Int(delay)))
                guard controller.cancellationEpoch == epoch else { return }
                controller.setHold(source: localSource, keys: [], down: false)
            }
        } else if !wasSwipe {
            if attacking && (slot == .pass || slot == .through || slot == .dash) &&
               (slot != .pass || !instantPass) {
                lastTap = now
                pendingSingle?.cancel()
                pendingSingle = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(210))
                    guard !Task.isCancelled else { return }
                    if slot == .dash { controller.tap(["r2"], channel: "dash") }
                    else if slot == .pass { controller.tap(["cross"], channel: "pass") }
                    else { controller.tap(["triangle"], channel: "through") }
                    pendingSingle = nil
                }
            } else {
                controller.tap(slot.keys(attacking: attacking, swipe: nil), channel: "button.\(slot.rawValue)")
            }
        }

        // For a short DASH press, the held R2 pulse already happened; keep
        // a detection window without scheduling another redundant tap.
        if attacking && slot == .dash && !wasSwipe && !held.isEmpty && age < 0.17 {
            lastTap = now
            pendingSingle?.cancel()
            pendingSingle = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(210))
                if !Task.isCancelled { pendingSingle = nil }
            }
        }
    }

    private func reset() {
        activation?.cancel()
        pendingSingle?.cancel()
        activation = nil
        pendingSingle = nil
        controller.setHold(source: source, keys: [], down: false)
        touching = false
        activeKeys = []
        selectedSwipe = nil
        secondTap = false
        followUpShot = false
        lastShotEnd = .distantPast
        lastTap = .distantPast
        currentID &+= 1
    }
}
