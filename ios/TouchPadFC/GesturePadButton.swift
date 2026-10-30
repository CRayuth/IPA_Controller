
import SwiftUI
import UIKit

enum GesturePadSlot: String {
    case through, shoot, pass, dash

    func label(attacking: Bool) -> String {
        switch self {
        case .through:
            return attacking ? "THROUGH" : "PRESS"
        case .shoot:
            return attacking ? "SHOOT" : "TACKLE"
        case .pass:
            return attacking ? "PASS" : "SWITCH"
        case .dash:
            return attacking ? "DASH" : "MATCH-UP"
        }
    }

    func command(attacking: Bool, swipe: PadSwipe?) -> PadCommand {
        if attacking {
            switch self {
            case .through:
                switch swipe {
                case .up:
                    return .buttons(["l1", "triangle"])
                case .right:
                    return .buttons(["l1", "r1", "triangle"])
                case .left:
                    return .buttons(["r1", "triangle"])
                default:
                    return .buttons(["triangle"])
                }

            case .shoot:
                switch swipe {
                case .up:
                    return .buttons(["l1", "circle"])
                case .right:
                    return .buttons(["l1", "r1", "circle"])
                case .left:
                    return .buttons(["r1", "circle"])
                default:
                    return .buttons(["circle"])
                }

            case .pass:
                switch swipe {
                case .up:
                    return .buttons(["square"])
                case .right:
                    return .buttons(["r1", "cross"])
                case .left:
                    return .buttons(["l1", "cross"])
                default:
                    return .buttons(["cross"])
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
            case .up:
                return .buttons(["r1"])
            case .right:
                return .buttons(["r2", "cross"])
            case .down:
                return .buttons(["triangle"])
            default:
                return .buttons(["cross"])
            }

        case .shoot:
            switch swipe {
            case .up, .left:
                return .buttons(["square"])
            case .right:
                return .buttons(["r1", "circle"])
            default:
                return .buttons(["circle"])
            }

        case .pass:
            switch swipe {
            case .up:
                return .rightStick(x: 0, y: 1)
            case .down:
                return .rightStick(x: 0, y: -1)
            case .left:
                return .rightStick(x: -1, y: 0)
            case .right:
                return .rightStick(x: 1, y: 0)
            default:
                return .buttons(["l1"])
            }

        case .dash:
            switch swipe {
            case .up:
                return .buttons(["l2", "r2"])
            case .right, .left:
                return .buttons(["r2"])
            default:
                return .buttons(["l2"])
            }
        }
    }

    func selectedLabel(attacking: Bool, swipe: PadSwipe?) -> String {
        guard let swipe else {
            return label(attacking: attacking)
        }

        if attacking {
            switch self {
            case .shoot:
                switch swipe {
                case .up:
                    return "CHIP"
                case .left:
                    return "FINESSE"
                case .right:
                    return "POWER"
                case .down:
                    return "SHOOT"
                }

            case .pass:
                switch swipe {
                case .up:
                    return "CROSS"
                case .right:
                    return "DRIVEN"
                case .left:
                    return "PASS & GO"
                case .down:
                    return "PASS"
                }

            case .through:
                switch swipe {
                case .up:
                    return "LOB THROUGH"
                case .right:
                    return "L1+R1 THROUGH"
                case .left:
                    return "R1 THROUGH"
                case .down:
                    return "THROUGH"
                }

            case .dash:
                return swipe == .left ? "R1" : "DASH"
            }
        }

        switch self {
        case .through:
            switch swipe {
            case .up:
                return "2ND PRESS"
            case .right:
                return "SPRINT PRESS"
            case .down:
                return "GK RUSH"
            case .left:
                return "PRESS"
            }

        case .shoot:
            return swipe == .right ? "HARD TACKLE" : "SLIDE"

        case .pass:
            return "SELECT"

        case .dash:
            return swipe == .up ? "SPRINT JOCKEY" : "SPRINT"
        }
    }
}

enum PadSwipe {
    case up, down, left, right

    static func detect(
        _ translation: CGSize,
        threshold: CGFloat
    ) -> PadSwipe? {
        guard hypot(
            translation.width,
            translation.height
        ) >= threshold else {
            return nil
        }

        if abs(translation.width) > abs(translation.height) {
            return translation.width > 0 ? .right : .left
        }

        return translation.height < 0 ? .up : .down
    }
}

enum PadCommand {
    case buttons([String])
    case rightStick(x: CGFloat, y: CGFloat)
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
    @State private var commandInUse: PadCommand?
    @State private var sourceInUse = ""
    @State private var selectedSwipe: PadSwipe?
    @State private var swipeLocked = false
    @State private var stickOwner: Int?

    // Wait briefly for a swipe before starting a normal action.
    // DASH remains immediate.
    private var selectionWindow: TimeInterval {
        switch slot {
        case .shoot:
            return 0.34
        case .through, .pass:
            return 0.24
        case .dash:
            return 0
        }
    }

    private let swipeDistance: CGFloat = 22
    private let minimumPressTime: TimeInterval = 0.12
    private let modifierReleaseDelay: TimeInterval = 0.05

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    touching
                        ? Color.green.opacity(0.85)
                        : Color(
                            red: 0.20,
                            green: 0.38,
                            blue: 0.30
                        )
                )

            Circle()
                .stroke(
                    .green.opacity(0.55),
                    lineWidth: 4
                )

            Text(
                slot.selectedLabel(
                    attacking: attacking,
                    swipe: selectedSwipe
                )
            )
            .font(
                .system(
                    size: 11,
                    weight: .bold,
                    design: .rounded
                )
            )
            .minimumScaleFactor(0.65)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)

            if !touching && slot != .dash {
                Text("↑")
                    .offset(y: -diameter * 0.38)

                Text("→")
                    .offset(x: diameter * 0.38)

                Text("←")
                    .offset(x: -diameter * 0.38)
            }
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(.white.opacity(0.8))
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged(handleChange)
                .onEnded(handleEnd)
        )
        .onChange(of: attacking) { _ in
            cancelCurrent()
        }
        .onDisappear {
            cancelCurrent()
        }
    }

    private func handleChange(_ drag: DragGesture.Value) {
        if !touching {
            beginTouch()
        }

        guard !swipeLocked else {
            return
        }

        guard Date().timeIntervalSince(startedAt) <= 0.40 else {
            return
        }

        guard let direction = PadSwipe.detect(
            drag.translation,
            threshold: swipeDistance
        ) else {
            return
        }

        if slot == .dash {
            releaseCurrent(staggerModifiers: false)
            swipeLocked = true
            selectedSwipe = direction

            activate(
                slot.command(
                    attacking: attacking,
                    swipe: direction
                )
            )

        } else if commandInUse == nil {
            swipeLocked = true
            selectedSwipe = direction

            activate(
                slot.command(
                    attacking: attacking,
                    swipe: direction
                )
            )
        }
    }

    private func beginTouch() {
        touching = true
        gestureID += 1
        startedAt = Date()
        pressedAt = .distantPast
        selectedSwipe = nil
        swipeLocked = false
        commandInUse = nil

        sourceInUse = "gesture.\(slot.rawValue).\(gestureID).base"

        let id = gestureID

        if slot == .dash {
            activate(
                slot.command(
                    attacking: attacking,
                    swipe: nil
                )
            )
            return
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + selectionWindow
        ) {
            guard touching,
                  gestureID == id,
                  commandInUse == nil else {
                return
            }

            activate(
                slot.command(
                    attacking: attacking,
                    swipe: nil
                )
            )
        }
    }

    private func activate(_ command: PadCommand) {
        guard touching else {
            return
        }

        commandInUse = command
        pressedAt = Date()

        switch command {
        case .buttons(let keys):
            // Keep action and modifiers separate so the action
            // can be released first after charging.
            if let primary = keys.last {
                controller.setHold(
                    source: sourceInUse + ".action",
                    keys: [primary],
                    down: true
                )

                let modifiers = Array(keys.dropLast())

                if !modifiers.isEmpty {
                    controller.setHold(
                        source: sourceInUse + ".modifiers",
                        keys: modifiers,
                        down: true
                    )
                }
            }

        case .rightStick(let x, let y):
            stickOwner = gestureID

            controller.setStick(
                left: false,
                x: x,
                y: y
            )
        }

        UIImpactFeedbackGenerator(
            style: .light
        ).impactOccurred()
    }

    private func handleEnd(_ drag: DragGesture.Value) {
        guard touching else {
            return
        }

        if commandInUse == nil {
            if let swipe = PadSwipe.detect(
                drag.translation,
                threshold: swipeDistance
            ) {
                selectedSwipe = swipe

                activate(
                    slot.command(
                        attacking: attacking,
                        swipe: swipe
                    )
                )
            } else {
                activate(
                    slot.command(
                        attacking: attacking,
                        swipe: nil
                    )
                )
            }
        }

        let command = commandInUse
        let source = sourceInUse
        let id = gestureID

        let elapsed = Date().timeIntervalSince(pressedAt)
        let remaining = max(
            0,
            minimumPressTime - elapsed
        )

        touching = false
        commandInUse = nil
        selectedSwipe = nil
        swipeLocked = false

        DispatchQueue.main.asyncAfter(
            deadline: .now() + remaining
        ) {
            release(
                command,
                source: source,
                id: id,
                staggerModifiers: true
            )
        }
    }

    private func releaseCurrent(staggerModifiers: Bool) {
        release(
            commandInUse,
            source: sourceInUse,
            id: gestureID,
            staggerModifiers: staggerModifiers
        )

        commandInUse = nil

        sourceInUse = "gesture.\(slot.rawValue).\(gestureID).swipe"
    }

    private func release(
        _ command: PadCommand?,
        source: String,
        id: Int,
        staggerModifiers: Bool
    ) {
        guard let command else {
            return
        }

        switch command {
        case .buttons:
            controller.setHold(
                source: source + ".action",
                keys: [],
                down: false
            )

            if staggerModifiers {
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + modifierReleaseDelay
                ) {
                    controller.setHold(
                        source: source + ".modifiers",
                        keys: [],
                        down: false
                    )
                }
            } else {
                controller.setHold(
                    source: source + ".modifiers",
                    keys: [],
                    down: false
                )
            }

        case .rightStick:
            if stickOwner == id {
                controller.setStick(
                    left: false,
                    x: 0,
                    y: 0
                )

                stickOwner = nil
            }
        }
    }

    private func cancelCurrent() {
        releaseCurrent(staggerModifiers: false)

        gestureID += 1
        touching = false
        selectedSwipe = nil
        swipeLocked = false
    }
}
