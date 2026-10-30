
import SwiftUI
import UIKit

private enum SetPieceCommand {
    case buttons([String])
    case dive(CGPoint)
}

private struct SetPieceAction: Identifiable {
    let id: String
    let title: String
    let detail: String
    let command: SetPieceCommand

    init(_ id: String, _ title: String, _ detail: String, _ command: SetPieceCommand) {
        self.id = id
        self.title = title
        self.detail = detail
        self.command = command
    }
}

struct SetPiecePad: View {
    let screen: SetPieceScreen

    @EnvironmentObject private var controller: ControllerModel
    @State private var showCornerTactics = false
    @State private var tacticsPulse = 0

    private var hasRightStick: Bool {
        screen != .penalty
    }

    private var actions: [SetPieceAction] {
        switch screen {
        case .match:
            return []
        case .penalty:
            return [
                .init("penalty.shoot", "SHOOT", "Hold to charge", .buttons(["circle"])),
                .init("penalty.finesse", "FINESSE", "R1 + Shoot", .buttons(["r1", "circle"])),
                .init("penalty.chip", "CHIP", "L1 + Shoot", .buttons(["l1", "circle"])),
                .init("penalty.taker", "KICKER", "Change taker", .buttons(["r2"]))
            ]
        case .penaltySave:
            return [
                .init("save.left", "DIVE ←", "Right stick left", .dive(CGPoint(x: -1, y: 0))),
                .init("save.right", "DIVE →", "Right stick right", .dive(CGPoint(x: 1, y: 0))),
                .init("save.upLeft", "DIVE ↖", "Upper left", .dive(CGPoint(x: -0.72, y: 0.72))),
                .init("save.upRight", "DIVE ↗", "Upper right", .dive(CGPoint(x: 0.72, y: 0.72)))
            ]
        case .freeKick:
            return [
                .init("free.shoot", "SHOOT", "Hold to charge", .buttons(["circle"])),
                .init("free.pass", "PASS", "Ground pass", .buttons(["cross"])),
                .init("free.cross", "CROSS", "Lob / cross", .buttons(["square"])),
                .init("free.second", "2ND SHOT", "L2 + Shoot", .buttons(["l2", "circle"]))
            ]
        case .corner:
            if showCornerTactics {
                return [
                    .init("corner.near", "NEAR POST", "D-pad left", .buttons(["d_left"])),
                    .init("corner.far", "FAR POST", "D-pad right", .buttons(["d_right"])),
                    .init("corner.add", "ADD PLAYER", "D-pad up", .buttons(["d_up"])),
                    .init("corner.remove", "REMOVE", "D-pad down", .buttons(["d_down"]))
                ]
            }
            return [
                .init("corner.cross", "CROSS", "Hold to charge", .buttons(["square"])),
                .init("corner.pass", "SHORT", "Short corner", .buttons(["cross"])),
                .init("corner.avoid", "AVOID", "Hold R1", .buttons(["r1"]))
            ]
        }
    }

    private var instruction: String {
        switch screen {
        case .match: return ""
        case .penalty:
            return "Aim with LEFT stick. Hold SHOOT, FINESSE or CHIP, then release."
        case .penaltySave:
            return "LEFT stick moves the keeper. RIGHT stick or DIVE buttons choose the dive."
        case .freeKick:
            return "LEFT stick aims; RIGHT stick moves the reticle. Hold a kick to charge."
        case .corner:
            return showCornerTactics
                ? "Choose a corner run tactic, then return to the kick controls."
                : "Aim the delivery, charge CROSS or SHORT, then hold AVOID to move through traffic."
        }
    }

    var body: some View {
        GeometryReader { area in
            let scale = min(1.0, max(0.69, area.size.width / 830))
            let stickSize: CGFloat = 134 * scale
            let buttonSize: CGFloat = 92 * scale

            VStack(spacing: 3) {
                HStack {
                    Text(screen.title)
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("SET PIECE • MANUAL MODE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 10)

                Text(instruction)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)

                Spacer(minLength: 0)

                HStack(alignment: .bottom, spacing: 18 * scale) {
                    VStack(spacing: 4) {
                        SetPieceStick(isLeft: true, diameter: stickSize)
                        Text(screen == .penaltySave ? "MOVE GK" : "AIM / MOVE")
                            .font(.system(size: 10, weight: .bold))
                    }

                    if hasRightStick {
                        VStack(spacing: 4) {
                            SetPieceStick(isLeft: false, diameter: stickSize)
                            Text(screen == .penaltySave ? "DIVE" : "RETICLE / MOVE")
                                .font(.system(size: 10, weight: .bold))
                        }
                    }

                    Spacer(minLength: 0)

                    VStack(spacing: 8 * scale) {
                        if screen == .corner && showCornerTactics {
                            Button("BACK TO KICK") {
                                showCornerTactics = false
                                controller.releaseInputs()
                            }
                            .font(.system(size: 10, weight: .bold))
                            .buttonStyle(.bordered)
                        }

                        LazyVGrid(
                            columns: [GridItem(.fixed(buttonSize)), GridItem(.fixed(buttonSize))],
                            spacing: 8 * scale
                        ) {
                            ForEach(actions) { action in
                                SetPieceActionButton(action: action, diameter: buttonSize)
                            }

                            if screen == .corner && !showCornerTactics {
                                Button {
                                    openTactics()
                                } label: {
                                    VStack(spacing: 2) {
                                        Text("TACTICS")
                                            .font(.system(size: 11, weight: .bold))
                                        Text("Choose run")
                                            .font(.system(size: 8))
                                    }
                                    .frame(width: buttonSize, height: buttonSize)
                                    .background(Color.teal.opacity(0.55), in: Circle())
                                    .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.bottom, 9)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.025, green: 0.035, blue: 0.075),
                        Color(red: 0.065, green: 0.15, blue: 0.13)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .onChange(of: screen) { _ in
            showCornerTactics = false
            tacticsPulse += 1
        }
        .onDisappear {
            tacticsPulse += 1
            controller.releaseInputs()
        }
    }

    private func openTactics() {
        showCornerTactics = true
        tacticsPulse += 1
        let pulse = tacticsPulse
        let source = "corner.tactics.open.\(pulse)"
        controller.setHold(source: source, keys: ["d_up"], down: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            controller.setHold(source: source, keys: [], down: false)
        }
    }
}

private struct SetPieceActionButton: View {
    let action: SetPieceAction
    let diameter: CGFloat

    @EnvironmentObject private var controller: ControllerModel
    @State private var touching = false
    @State private var touchID = 0
    @State private var source = ""
    @State private var beganAt = Date.distantPast

    var body: some View {
        VStack(spacing: 2) {
            Text(action.title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(action.detail)
                .font(.system(size: 8))
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .foregroundStyle(.white.opacity(0.78))
        }
        .frame(width: diameter, height: diameter)
        .background(
            touching ? Color.green : Color(red: 0.20, green: 0.38, blue: 0.30),
            in: Circle()
        )
        .overlay(Circle().stroke(Color.green.opacity(0.55), lineWidth: 3))
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in start() }
                .onEnded { _ in finish() }
        )
        .onDisappear { finish() }
    }

    private func start() {
        guard !touching else { return }
        touching = true
        touchID += 1
        source = "setpiece.\(action.id).\(touchID)"
        beganAt = Date()
        switch action.command {
        case .buttons(let keys):
            controller.setHold(source: source, keys: keys, down: true)
        case .dive(let point):
            controller.setStick(left: false, x: point.x, y: point.y)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func finish() {
        guard touching else { return }
        touching = false
        let sourceAtEnd = source
        let elapsed = Date().timeIntervalSince(beganAt)
        let wait = max(0, 0.12 - elapsed)
        let command = action.command
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
            switch command {
            case .buttons:
                controller.setHold(source: sourceAtEnd, keys: [], down: false)
            case .dive:
                controller.setStick(left: false, x: 0, y: 0)
            }
        }
    }
}

private struct SetPieceStick: View {
    @EnvironmentObject private var controller: ControllerModel
    let isLeft: Bool
    let diameter: CGFloat

    var body: some View {
        let value = isLeft ? controller.leftStick : controller.rightStick
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.10))
                .overlay(Circle().stroke(Color.white.opacity(0.44), lineWidth: 2))
            Circle()
                .fill(Color.gray.opacity(0.9))
                .frame(width: diameter * 0.50, height: diameter * 0.50)
                .offset(x: value.x * diameter * 0.28, y: -value.y * diameter * 0.28)
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    let dx = (gesture.location.x - diameter / 2) / (diameter * 0.3)
                    let dy = (diameter / 2 - gesture.location.y) / (diameter * 0.3)
                    let length = hypot(dx, dy)
                    let magnitude = length <= 0.08 ? 0 : min(1, (length - 0.08) / 0.92)
                    let x = length == 0 ? 0 : dx / length * magnitude
                    let y = length == 0 ? 0 : dy / length * magnitude
                    controller.setStick(left: isLeft, x: x, y: y)
                }
                .onEnded { _ in
                    controller.setStick(left: isLeft, x: 0, y: 0)
                }
        )
        .accessibilityLabel(isLeft ? "Aim or move" : "Reticle or goalkeeper dive")
    }
}
