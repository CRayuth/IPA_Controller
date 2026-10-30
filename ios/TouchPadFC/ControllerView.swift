
import SwiftUI
import UIKit

private let ink = Color(red: 0.025, green: 0.035, blue: 0.075)
private let surface = Color(red: 0.13, green: 0.18, blue: 0.22)

private enum MatchMode: String, CaseIterable {
    case attack, defend

    var title: String {
        self == .attack ? "ATTACKING" : "DEFENDING"
    }
}

struct ControllerView: View {
    @EnvironmentObject private var controller: ControllerModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var layout = ControllerLayoutStore()

    @AppStorage("touchpadfc.pes.advanced")
    private var advanced = false

    @AppStorage("touchpadfc.pes.manual")
    private var savedMode = "attack"

    @State private var showSettings = true
    @State private var confirmReset = false

    private var manualMode: MatchMode {
        MatchMode(rawValue: savedMode) ?? .attack
    }

    private var effectiveMode: MatchMode {
        if controller.autoModeEnabled,
           controller.detectionConfidence >= 0.70,
           let found = controller.detectedMode,
           let mode = MatchMode(rawValue: found) {
            return mode
        }
        return manualMode
    }

    private var attacking: Bool {
        effectiveMode == .attack
    }

    var body: some View {
        VStack(spacing: 0) {
            header.frame(height: 44)

            GeometryReader { area in
                let canvas = area.size
                let adaptation = min(
                    1.15,
                    max(
                        0.72,
                        min(
                            canvas.width / 810,
                            canvas.height / 290
                        )
                    )
                )

                ZStack(alignment: .topLeading) {
                    Rectangle().fill(ink)

                    LinearGradient(
                        colors: [.blue.opacity(0.20), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    positioned(
                        .move,
                        in: canvas,
                        adaptation: adaptation
                    ) {
                        TouchStick(left: true, size: 132)
                    }

                    positioned(
                        .through,
                        in: canvas,
                        adaptation: adaptation
                    ) {
                        GesturePadButton(
                            slot: .through,
                            attacking: attacking,
                            diameter: 82
                        )
                    }

                    positioned(
                        .shoot,
                        in: canvas,
                        adaptation: adaptation
                    ) {
                        GesturePadButton(
                            slot: .shoot,
                            attacking: attacking,
                            diameter: 82
                        )
                    }

                    positioned(
                        .pass,
                        in: canvas,
                        adaptation: adaptation
                    ) {
                        GesturePadButton(
                            slot: .pass,
                            attacking: attacking,
                            diameter: 82
                        )
                    }

                    positioned(
                        .dash,
                        in: canvas,
                        adaptation: adaptation
                    ) {
                        GesturePadButton(
                            slot: .dash,
                            attacking: attacking,
                            diameter: 82
                        )
                    }

                    if advanced || layout.editing {
                        positioned(
                            .cross,
                            in: canvas,
                            adaptation: adaptation
                        ) {
                            HoldButton(
                                title: attacking ? "CROSS" : "SLIDE",
                                source: "cross",
                                keys: ["square"],
                                width: 86
                            )
                        }

                        positioned(
                            .finesse,
                            in: canvas,
                            adaptation: adaptation
                        ) {
                            HoldButton(
                                title: attacking ? "FINESSE" : "GK RUSH",
                                source: "finesse",
                                keys: attacking
                                    ? ["r1", "circle"]
                                    : ["triangle"],
                                width: 86
                            )
                        }

                        positioned(
                            .chip,
                            in: canvas,
                            adaptation: adaptation
                        ) {
                            HoldButton(
                                title: attacking
                                    ? "CHIP SHOT"
                                    : "SPRINT JOCKEY",
                                source: "chip",
                                keys: attacking
                                    ? ["l1", "circle"]
                                    : ["l2", "r2"],
                                width: 86
                            )
                        }

                        positioned(
                            .slide,
                            in: canvas,
                            adaptation: adaptation
                        ) {
                            HoldButton(
                                title: attacking
                                    ? "RUN"
                                    : "HARD SLIDE",
                                source: "extra",
                                keys: attacking
                                    ? ["l1"]
                                    : ["r1", "square"],
                                width: 86
                            )
                        }

                        positioned(
                            .skill,
                            in: canvas,
                            adaptation: adaptation
                        ) {
                            TouchStick(left: false, size: 80)
                        }

                        shoulder(
                            .l1,
                            keys: ["l1"],
                            canvas: canvas,
                            adaptation: adaptation
                        )

                        shoulder(
                            .l2,
                            keys: ["l2"],
                            canvas: canvas,
                            adaptation: adaptation
                        )

                        shoulder(
                            .r1,
                            keys: ["r1"],
                            canvas: canvas,
                            adaptation: adaptation
                        )

                        shoulder(
                            .r2,
                            keys: ["r2"],
                            canvas: canvas,
                            adaptation: adaptation
                        )

                        positioned(
                            .options,
                            in: canvas,
                            adaptation: adaptation
                        ) {
                            HoldButton(
                                title: "OPTIONS",
                                source: "options",
                                keys: ["options"],
                                width: 64,
                                height: 30
                            )
                        }
                    }
                }
                .frame(
                    width: canvas.width,
                    height: canvas.height
                )
                .clipped()
            }

            if layout.editing {
                editBar.frame(height: 54)
            } else {
                HStack {
                    Text(
                        controller.autoModeEnabled
                            ? (
                                controller.detectedMode == nil
                                    ? "AUTO: NO RELIABLE SIGNAL — MANUAL FALLBACK"
                                    : "AUTO DETECTION: \(Int(controller.detectionConfidence * 100))% CONFIDENCE"
                            )
                            : "MANUAL • TAP, HOLD OR SWIPE THE FOUR ACTION BUTTONS"
                    )

                    Spacer(minLength: 4)
                    Text("FC 27 CLASSIC")
                }
                .font(
                    .system(
                        size: 9,
                        weight: .medium,
                        design: .monospaced
                    )
                )
                .foregroundStyle(.white.opacity(0.67))
                .frame(height: 19)
            }
        }
        .padding(.horizontal, 5)
        .foregroundStyle(.white)
        .background(ink.ignoresSafeArea())
        .environmentObject(layout)
        .sheet(isPresented: $showSettings) {
            ConnectionSheet(isPresented: $showSettings)
                .environmentObject(controller)
        }
        .confirmationDialog(
            "Reset all button positions?",
            isPresented: $confirmReset
        ) {
            Button(
                "Reset everything",
                role: .destructive
            ) {
                layout.resetAll()
            }
        }
        .onChange(of: effectiveMode) { _ in
            controller.releaseInputs()
        }
        .onChange(of: layout.editing) { enabled in
            controller.releaseInputs()
            if !enabled {
                layout.save()
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                controller.disconnect()
            }
        }
        .onDisappear {
            controller.disconnect()
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("TouchPadFC")
                .font(
                    .system(
                        size: 15,
                        weight: .heavy,
                        design: .rounded
                    )
                )

            Circle()
                .fill(controller.paired ? .green : .orange)
                .frame(width: 7, height: 7)

            Spacer(minLength: 1)

            ForEach(
                MatchMode.allCases,
                id: \.self
            ) { mode in
                Button(mode.title) {
                    savedMode = mode.rawValue
                    controller.releaseInputs()
                }
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 8)
                .frame(height: 29)
                .background(
                    effectiveMode == mode
                        ? Color.gray.opacity(0.65)
                        : surface,
                    in: Capsule()
                )
                .disabled(layout.editing)
            }

            Button(
                controller.autoModeEnabled
                    ? "AUTO ON"
                    : "AUTO OFF"
            ) {
                controller.releaseInputs()
                controller.autoModeEnabled.toggle()
            }
            .tint(
                controller.autoModeEnabled
                    ? .green
                    : .gray
            )

            Button(advanced ? "SIMPLE" : "MORE") {
                controller.releaseInputs()
                advanced.toggle()
            }

            Button(layout.editing ? "DONE" : "EDIT") {
                layout.editing.toggle()
            }
            .tint(layout.editing ? .green : .cyan)

            Button("PC") {
                controller.releaseInputs()
                showSettings = true
            }
            .tint(.cyan)
        }
        .font(.system(size: 10, weight: .bold))
        .buttonStyle(.bordered)
    }

    private func positioned<Content: View>(
        _ item: PadItem,
        in canvas: CGSize,
        adaptation: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        PositionedPadItem(
            item: item,
            canvas: canvas,
            adaptation: adaptation,
            content: content
        )
    }

    private func shoulder(
        _ item: PadItem,
        keys: [String],
        canvas: CGSize,
        adaptation: CGFloat
    ) -> some View {
        positioned(
            item,
            in: canvas,
            adaptation: adaptation
        ) {
            HoldButton(
                title: item.rawValue.uppercased(),
                source: item.rawValue,
                keys: keys,
                width: 62,
                height: 32
            )
        }
    }

    private var editBar: some View {
        HStack(spacing: 8) {
            Text(layout.selected?.title ?? "Drag a control")
                .font(.system(size: 11, weight: .bold))
                .frame(width: 120, alignment: .leading)
                .lineLimit(1)

            if let selected = layout.selected {
                Slider(
                    value: Binding(
                        get: {
                            layout.placement(selected).scale
                        },
                        set: {
                            layout.resize(selected, to: $0)
                        }
                    ),
                    in: layout.minScale...layout.maxScale
                )
                .tint(.cyan)

                Text(
                    "\(Int(layout.placement(selected).scale * 100))%"
                )
                .frame(width: 42)
                .font(
                    .system(
                        size: 10,
                        design: .monospaced
                    )
                )

                Button("RESET ITEM") {
                    layout.resetSelected()
                }
            } else {
                Text("Select any button to resize or drag")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Button("RESET ALL") {
                confirmReset = true
            }
            .tint(.orange)
        }
        .buttonStyle(.bordered)
        .font(
            .system(
                size: 10,
                weight: .bold
            )
        )
        .padding(.horizontal, 8)
    }
}

private struct PositionedPadItem<Content: View>: View {
    @EnvironmentObject private var layout: ControllerLayoutStore

    let item: PadItem
    let canvas: CGSize
    let adaptation: CGFloat

    @ViewBuilder let content: () -> Content

    @State private var origin: CGPoint?

    var body: some View {
        let scale = adaptation *
            CGFloat(layout.placement(item).scale)

        let center = layout.center(
            item,
            in: canvas,
            adaptation: adaptation
        )

        Group {
            if layout.editing {
                content()
                    .allowsHitTesting(false)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                Color.white.opacity(0.001)
                            )
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: 12
                                )
                                .stroke(
                                    layout.selected == item
                                        ? Color.yellow
                                        : .cyan,
                                    style: StrokeStyle(
                                        lineWidth: 2,
                                        dash: [4, 3]
                                    )
                                )
                            }
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        if origin == nil {
                                            origin = layout.center(
                                                item,
                                                in: canvas,
                                                adaptation: adaptation
                                            )
                                            layout.selected = item
                                        }

                                        guard let origin else {
                                            return
                                        }

                                        layout.move(
                                            item,
                                            to: CGPoint(
                                                x: origin.x +
                                                    value.translation.width * scale,
                                                y: origin.y +
                                                    value.translation.height * scale
                                            ),
                                            in: canvas,
                                            adaptation: adaptation
                                        )
                                    }
                                    .onEnded { _ in
                                        origin = nil
                                        layout.save()
                                    }
                            )
                    }
            } else {
                content()
            }
        }
        .frame(
            width: item.size.width,
            height: item.size.height
        )
        .scaleEffect(scale)
        .frame(
            width: item.size.width * scale,
            height: item.size.height * scale
        )
        .position(center)
    }
}

private struct HoldButton: View {
    let title: String
    let source: String
    let keys: [String]
    let width: CGFloat

    var height: CGFloat = 34

    @EnvironmentObject private var controller: ControllerModel
    @State private var touchActive = false

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: width, height: height)
            .background(
                controller.isHeld(source)
                    ? .cyan
                    : surface,
                in: RoundedRectangle(cornerRadius: 9)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !touchActive else {
                            return
                        }

                        touchActive = true
                        controller.setHold(
                            source: source,
                            keys: keys,
                            down: true
                        )
                    }
                    .onEnded { _ in
                        release()
                    }
            )
            .onChange(of: keys) { _ in
                release()
            }
            .onDisappear {
                release()
            }
    }

    private func release() {
        touchActive = false
        controller.setHold(
            source: source,
            keys: [],
            down: false
        )
    }
}

private struct TouchStick: View {
    @EnvironmentObject private var controller: ControllerModel

    let left: Bool
    let size: CGFloat

    var body: some View {
        let point = left
            ? controller.leftStick
            : controller.rightStick

        ZStack {
            Circle()
                .fill(Color.white.opacity(0.12))

            Circle()
                .stroke(
                    .white.opacity(0.45),
                    lineWidth: 2
                )

            Circle()
                .fill(Color.gray.opacity(0.93))
                .frame(
                    width: size * 0.51,
                    height: size * 0.51
                )
                .offset(
                    x: point.x * size * 0.29,
                    y: -point.y * size * 0.29
                )
        }
        .frame(
            width: size,
            height: size
        )
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { touch in
                    let dx =
                        (touch.location.x - size / 2)
                        / (size * 0.30)

                    let dy =
                        (size / 2 - touch.location.y)
                        / (size * 0.30)

                    let length = hypot(dx, dy)
                    let deadzone: CGFloat = 0.10

                    let value = length <= deadzone
                        ? 0
                        : min(
                            1,
                            (length - deadzone)
                            / (1 - deadzone)
                        )

                    if length == 0 {
                        controller.setStick(
                            left: left,
                            x: 0,
                            y: 0
                        )
                    } else {
                        controller.setStick(
                            left: left,
                            x: dx / length * value,
                            y: dy / length * value
                        )
                    }
                }
                .onEnded { _ in
                    controller.setStick(
                        left: left,
                        x: 0,
                        y: 0
                    )
                }
        )
    }
}

private struct ConnectionSheet: View {
    @EnvironmentObject private var controller: ControllerModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {
                    Text(
                        "1. Run: py -m receiver.server --mode xbox"
                    )

                    Text(
                        "2. Connect iPhone and Windows PC to the same private Wi-Fi."
                    )

                    Text(
                        "3. Enter the PC IPv4 address and PowerShell pairing PIN."
                    )

                    TextField(
                        "192.168.1.20",
                        text: $controller.host
                    )
                    .keyboardType(
                        .numbersAndPunctuation
                    )
                    .textInputAutocapitalization(
                        .never
                    )
                    .textFieldStyle(
                        .roundedBorder
                    )

                    TextField(
                        "Six-digit PIN",
                        text: $controller.pin
                    )
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)

                    Text(controller.message)
                        .foregroundStyle(
                            controller.paired
                                ? .green
                                : .secondary
                        )

                    HStack {
                        Button("Connect") {
                            controller.connect()
                        }
                        .buttonStyle(
                            .borderedProminent
                        )

                        Button("Disconnect") {
                            controller.disconnect()
                        }

                        Button("Play") {
                            isPresented = false
                        }
                        .buttonStyle(
                            .borderedProminent
                        )
                        .tint(.green)
                        .disabled(!controller.paired)
                    }

                    Toggle(
                        "Automatic attack / defend (experimental)",
                        isOn: $controller.autoModeEnabled
                    )

                    Text(
                        "Auto mode requires PC screen calibration: run the receiver with --roi x,y,w,h and use F8 while attacking, F9 while defending. Without a reliable visual indicator, manually choose Attack or Defend."
                    )
                    .foregroundStyle(.secondary)

                    Text(
                        "Test inputs with joy.cpl before opening FC 27. Choose Classic in game settings."
                    )
                    .foregroundStyle(.secondary)
                }
                .font(.system(size: 13))
                .padding(18)
            }
            .navigationTitle(
                "Connect to PC"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {
                ToolbarItem(
                    placement: .topBarTrailing
                ) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
