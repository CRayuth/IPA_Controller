import SwiftUI
import UIKit

private let padBackground = Color(red: 0.025, green: 0.035, blue: 0.075)
private let padSurface = Color(red: 0.13, green: 0.18, blue: 0.22)

private enum MatchMode: String, CaseIterable {
    case attack, defend
    var label: String { self == .attack ? "ATTACK" : "DEFEND" }
}

struct ControllerView: View {
    @EnvironmentObject private var controller: ControllerModel
    @StateObject private var layout = ControllerLayoutStore()
    @AppStorage("touchpadfc.pes.advanced") private var advanced = false
    @AppStorage("touchpadfc.pes.manual") private var manualMode = "attack"
    @AppStorage("touchpadfc.moveJoystickMode") private var joystickMode = "fixed"
    @AppStorage("touchpadfc.globalButtonScale") private var globalScale = 1.0
    @AppStorage("touchpadfc.quickAction1") private var quickOne = "strafe"
    @AppStorage("touchpadfc.quickAction2") private var quickTwo = "shield"
    @State private var showSettings = true
    @State private var showResetConfirmation = false
    @State private var openLibrary: ActionCategory?

    private var mode: MatchMode {
        if controller.autoModeEnabled,
           controller.detectionConfidence >= 0.70,
           let detected = controller.detectedMode,
           let matchMode = MatchMode(rawValue: detected) { return matchMode }
        return MatchMode(rawValue: manualMode) ?? .attack
    }
    private var attacking: Bool { mode == .attack }

    var body: some View {
        VStack(spacing: 0) {
            header.frame(height: 43)
            GeometryReader { proxy in
                let canvas = proxy.size
                let adaptation = min(1.15, max(0.70,
                    min(canvas.width / 810, canvas.height / 290))) * CGFloat(globalScale)
                let moveAreaWidth = canvas.width * 0.30
                ZStack(alignment: .topLeading) {
                    padBackground
                    LinearGradient(colors: [.blue.opacity(0.17), .clear],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)

                    if joystickMode == "floating" && !layout.editing {
                        FloatingMoveZone(diameter: 132 * adaptation)
                            .frame(width: moveAreaWidth, height: canvas.height)
                            .position(x: moveAreaWidth / 2, y: canvas.height / 2)
                    } else {
                        positioned(.move, canvas, adaptation) {
                            MatchStick(left: true, diameter: 132)
                        }
                    }

                    positioned(.through, canvas, adaptation) {
                        GesturePadButton(slot: .through, attacking: attacking, diameter: 82)
                    }
                    positioned(.shoot, canvas, adaptation) {
                        GesturePadButton(slot: .shoot, attacking: attacking, diameter: 82)
                    }
                    positioned(.pass, canvas, adaptation) {
                        GesturePadButton(slot: .pass, attacking: attacking, diameter: 82)
                    }
                    positioned(.dash, canvas, adaptation) {
                        GesturePadButton(slot: .dash, attacking: attacking, diameter: 82)
                    }

                    positioned(.cancel, canvas, adaptation) {
                        Text("CANCEL ×2")
                            .font(.system(size: 10, weight: .heavy))
                            .frame(width: 90, height: 42)
                            .background(Color.orange.opacity(0.4),
                                        in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.8), lineWidth: 1))
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { controller.cancelKick() }
                    }

                    positioned(.skillsMenu, canvas, adaptation) {
                        menuButton("SKILLS", color: .green) { open(.skills) }
                    }
                    positioned(.tacticsMenu, canvas, adaptation) {
                        menuButton("TACTICS", color: .cyan) { open(.tactics) }
                    }
                    positioned(.actionsMenu, canvas, adaptation) {
                        menuButton("ACTIONS", color: .mint) { open(.passing) }
                    }

                    if !advanced || layout.editing {
                        if let action = FCActionCatalog.all.first(where: { $0.id == quickOne }) {
                            positioned(.quickOne, canvas, adaptation) {
                                QuickActionPad(action: action)
                            }
                        }
                        if let action = FCActionCatalog.all.first(where: { $0.id == quickTwo }) {
                            positioned(.quickTwo, canvas, adaptation) {
                                QuickActionPad(action: action)
                            }
                        }
                    }

                    if advanced || layout.editing {
                        positioned(.cross, canvas, adaptation) {
                            HoldPadButton(title: attacking ? "CROSS" : "SLIDE",
                                          source: "cross", keys: ["square"], width: 86)
                        }
                        positioned(.finesse, canvas, adaptation) {
                            HoldPadButton(title: attacking ? "CURVE" : "GK RUSH",
                                          source: "finesse",
                                          keys: attacking ? ["r1", "circle"] : ["triangle"], width: 86)
                        }
                        positioned(.chip, canvas, adaptation) {
                            HoldPadButton(title: attacking ? "CHIP" : "SPRINT JOCKEY",
                                          source: "chip",
                                          keys: attacking ? ["l1", "circle"] : ["l2", "r2"], width: 86)
                        }
                        positioned(.slide, canvas, adaptation) {
                            HoldPadButton(title: attacking ? "RUN" : "HARD TACKLE",
                                          source: "extra",
                                          keys: attacking ? ["l1"] : ["r1", "circle"], width: 86)
                        }
                        positioned(.skill, canvas, adaptation) {
                            MatchStick(left: false, diameter: 80)
                        }
                        ForEach([PadItem.l1, .l2, .r1, .r2]) { item in
                            positioned(item, canvas, adaptation) {
                                HoldPadButton(title: item.rawValue.uppercased(),
                                              source: item.rawValue, keys: [item.rawValue],
                                              width: 62, height: 32)
                            }
                        }
                        positioned(.options, canvas, adaptation) {
                            HoldPadButton(title: "OPTIONS", source: "options",
                                          keys: ["options"], width: 64, height: 30)
                        }
                    }
                }
                .frame(width: canvas.width, height: canvas.height)
                .clipped()
            }
            if layout.editing { editBar.frame(height: 52) }
            else {
                HStack(spacing: 4) {
                    Text(controller.autoModeEnabled ? "AUTO: EXPERIMENTAL — MANUAL FALLBACK" :
                         "TAP • HOLD • SWIPE  |  SKILLS • TACTICS • ACTIONS")
                    Spacer(minLength: 4)
                    Text("FC27 CLASSIC")
                }
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .frame(height: 20)
            }
        }
        .padding(.horizontal, 4)
        .foregroundStyle(.white)
        .background(padBackground.ignoresSafeArea())
        .environmentObject(layout)
        .sheet(isPresented: $showSettings) {
            PCSettingsSheet(isPresented: $showSettings).environmentObject(controller)
        }
        .sheet(item: $openLibrary) { category in
            ActionLibraryView(initialCategory: category).environmentObject(controller)
        }
        .confirmationDialog("Reset all control positions and sizes?",
                            isPresented: $showResetConfirmation) {
            Button("Reset layout", role: .destructive) { layout.resetAll() }
        }
        .onChange(of: mode) { _ in controller.releaseInputs() }
        .onChange(of: joystickMode) { _ in controller.setStick(left: true, x: 0, y: 0) }
        .onChange(of: layout.editing) { editing in
            controller.releaseInputs()
            if !editing { layout.save() }
        }
        .onDisappear { controller.releaseInputs() }
    }

    private func open(_ category: ActionCategory) {
        guard !layout.editing else { return }
        controller.releaseInputs()
        openLibrary = category
    }

    private var header: some View {
        HStack(spacing: 5) {
            Text("TouchPadFC").font(.system(size: 13, weight: .heavy, design: .rounded))
            Circle().fill(controller.paired ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            Spacer(minLength: 3)
            ForEach(MatchMode.allCases, id: \.self) { item in
                Button(item.label) {
                    manualMode = item.rawValue
                    controller.releaseInputs()
                }
                .tint(mode == item ? .green : .gray)
            }
            Button(controller.autoModeEnabled ? "AUTO ✓" : "AUTO") {
                controller.autoModeEnabled.toggle()
                controller.releaseInputs()
            }
            .tint(controller.autoModeEnabled ? .green : .gray)
            Button(advanced ? "SIMPLE" : "MORE") {
                advanced.toggle()
                controller.releaseInputs()
            }
            Button(layout.editing ? "DONE" : "EDIT") { layout.editing.toggle() }
                .tint(layout.editing ? .green : .cyan)
            Button("PC") { controller.releaseInputs(); showSettings = true }
                .tint(.cyan)
        }
        .buttonStyle(.bordered)
        .font(.system(size: 10, weight: .bold))
        .controlSize(.small)
    }

    private func menuButton(_ name: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name).font(.system(size: 10, weight: .heavy))
                .frame(width: 80, height: 37)
                .background(color.opacity(0.28), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.7), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func positioned<Content: View>(
        _ item: PadItem, _ canvas: CGSize, _ adaptation: CGFloat,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        PositionedControl(item: item, canvas: canvas, adaptation: adaptation, content: content)
    }

    private var editBar: some View {
        HStack(spacing: 6) {
            Text(layout.selected?.title ?? "Tap a control to resize")
                .font(.system(size: 10, weight: .bold))
                .frame(width: 125, alignment: .leading).lineLimit(1)
            if let selected = layout.selected {
                Slider(value: Binding(
                    get: { layout.placement(selected).scale },
                    set: { layout.resize(selected, to: $0) }
                ), in: layout.minScale...layout.maxScale)
                .tint(.cyan)
                Text("\(Int(layout.placement(selected).scale * 100))%")
                    .font(.system(size: 10, design: .monospaced)).frame(width: 40)
                Button("RESET") { layout.resetSelected() }
            } else { Spacer() }
            Button("RESET ALL") { showResetConfirmation = true }.tint(.orange)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.horizontal, 5)
    }
}

private struct PositionedControl<Content: View>: View {
    @EnvironmentObject private var layout: ControllerLayoutStore
    let item: PadItem
    let canvas: CGSize
    let adaptation: CGFloat
    @ViewBuilder let content: () -> Content
    @State private var dragStart: CGPoint?

    var body: some View {
        let scale = adaptation * CGFloat(layout.placement(item).scale)
        let point = layout.center(item, in: canvas, adaptation: adaptation)
        Group {
            if layout.editing {
                content().allowsHitTesting(false)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.01))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(layout.selected == item ? .yellow : .cyan,
                                            style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                            }
                            .contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 0)
                                .onChanged { gesture in
                                    if dragStart == nil {
                                        dragStart = layout.center(item, in: canvas, adaptation: adaptation)
                                        layout.selected = item
                                    }
                                    guard let origin = dragStart else { return }
                                    layout.move(item, to: CGPoint(x: origin.x + gesture.translation.width,
                                                                  y: origin.y + gesture.translation.height),
                                                in: canvas, adaptation: adaptation)
                                }
                                .onEnded { _ in dragStart = nil; layout.save() })
                    }
            } else { content() }
        }
        .frame(width: item.size.width, height: item.size.height)
        .scaleEffect(scale)
        .frame(width: item.size.width * scale, height: item.size.height * scale)
        .position(point)
    }
}

private struct HoldPadButton: View {
    let title: String
    let source: String
    let keys: [String]
    let width: CGFloat
    var height: CGFloat = 34
    @EnvironmentObject private var controller: ControllerModel
    @State private var active = false

    var body: some View {
        Text(title).font(.system(size: 10, weight: .bold))
            .lineLimit(1).minimumScaleFactor(0.65)
            .frame(width: width, height: height)
            .background(active ? Color.green.opacity(0.65) : padSurface,
                        in: RoundedRectangle(cornerRadius: 9))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !active else { return }
                    active = true
                    controller.setHold(source: source, keys: keys, down: true)
                }
                .onEnded { _ in release() })
            .onChange(of: keys) { _ in release() }
            .onDisappear { release() }
    }

    private func release() {
        active = false
        controller.setHold(source: source, keys: [], down: false)
    }
}

private struct MatchStick: View {
    @EnvironmentObject private var controller: ControllerModel
    let left: Bool
    let diameter: CGFloat

    var body: some View {
        let point = left ? controller.leftStick : controller.rightStick
        ZStack {
            Circle().fill(Color.white.opacity(0.13))
            Circle().stroke(Color.white.opacity(0.42), lineWidth: 2)
            Circle().fill(Color.gray.opacity(0.92))
                .frame(width: diameter * 0.5, height: diameter * 0.5)
                .offset(x: point.x * diameter * 0.28, y: -point.y * diameter * 0.28)
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { drag in
                let dx = (drag.location.x - diameter / 2) / (diameter * 0.30)
                let dy = (diameter / 2 - drag.location.y) / (diameter * 0.30)
                let distance = hypot(dx, dy)
                let magnitude: CGFloat = distance < 0.1 ? 0 : min(1, (distance - 0.1) / 0.9)
                controller.setStick(left: left,
                                    x: distance > 0 ? dx / distance * magnitude : 0,
                                    y: distance > 0 ? dy / distance * magnitude : 0)
            }
            .onEnded { _ in controller.setStick(left: left, x: 0, y: 0) })
        .onDisappear { controller.setStick(left: left, x: 0, y: 0) }
    }
}

private struct FloatingMoveZone: View {
    @EnvironmentObject private var controller: ControllerModel
    let diameter: CGFloat
    @State private var center: CGPoint?
    @State private var position = CGPoint.zero

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color.white.opacity(0.003))
                    .contentShape(Rectangle())
                if let center {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.11))
                        Circle().stroke(Color.white.opacity(0.5), lineWidth: 2)
                        Circle().fill(Color.gray.opacity(0.9))
                            .frame(width: diameter * 0.5, height: diameter * 0.5)
                            .offset(x: position.x, y: position.y)
                    }
                    .frame(width: diameter, height: diameter)
                    .position(center).allowsHitTesting(false)
                } else {
                    Text("MOVE HERE").font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                        .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.70)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    if center == nil { center = gesture.startLocation }
                    guard let center else { return }
                    let dx = gesture.location.x - center.x
                    let dy = gesture.location.y - center.y
                    let length = hypot(dx, dy)
                    let normalized = min(1, length / (diameter * 0.3))
                    let strength: CGFloat = normalized < 0.1 ? 0 : (normalized - 0.1) / 0.9
                    position = CGPoint(x: length > 0 ? dx / length * normalized * diameter * 0.3 : 0,
                                       y: length > 0 ? dy / length * normalized * diameter * 0.3 : 0)
                    controller.setStick(left: true,
                                        x: length > 0 ? dx / length * strength : 0,
                                        y: length > 0 ? -dy / length * strength : 0)
                }
                .onEnded { _ in reset() })
        }
        .onDisappear { reset() }
    }

    private func reset() {
        center = nil
        position = .zero
        controller.setStick(left: true, x: 0, y: 0)
    }
}

private struct PCSettingsSheet: View {
    @EnvironmentObject private var controller: ControllerModel
    @Binding var isPresented: Bool
    @AppStorage("touchpadfc.moveJoystickMode") private var joystickMode = "fixed"
    @AppStorage("touchpadfc.globalButtonScale") private var globalScale = 1.0
    @AppStorage("touchpadfc.instantPass") private var instantPass = false
    @AppStorage("touchpadfc.quickAction1") private var quickOne = "strafe"
    @AppStorage("touchpadfc.quickAction2") private var quickTwo = "shield"

    private var quickChoices: [GameAction] {
        let ids = ["strafe", "shield", "controlledSprint", "run", "support", "curveRun",
                   "drivenPass", "passGo", "passFollow", "highCross", "drivenCross",
                   "groundCross", "finesse", "chip", "lowDriven", "fakeShot",
                   "teammateContain", "jockey", "sprintJockey", "professionalFoul"]
        return FCActionCatalog.all.filter { ids.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Connect Windows PC") {
                    Text("Run: py -m receiver.server --mode xbox")
                    Text("Both devices need the same Wi-Fi or LAN.")
                    TextField("PC IPv4 address", text: $controller.host)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                    TextField("6-digit PIN", text: $controller.pin).keyboardType(.numberPad)
                    Text(controller.message).foregroundStyle(controller.paired ? .green : .secondary)
                    HStack {
                        Button("Connect") { controller.connect() }
                            .buttonStyle(.borderedProminent)
                        Button("Disconnect") { controller.disconnect() }
                        Button("Play") { isPresented = false }
                            .buttonStyle(.borderedProminent)
                            .tint(.green).disabled(!controller.paired)
                    }
                }
                Section("Movement Joystick") {
                    Picker("Type", selection: $joystickMode) {
                        Text("Fixed").tag("fixed")
                        Text("Floating").tag("floating")
                    }.pickerStyle(.segmented)
                    Text("Floating creates the joystick where you first touch the left movement area.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Button Size") {
                    HStack {
                        Text("All controls")
                        Slider(value: $globalScale, in: 0.8...1.25, step: 0.05)
                        Text("\(Int(globalScale * 100))%")
                    }
                    Text("Use EDIT on the match screen to drag or resize EACH control from 55% to 190%.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Quick Buttons (simple match screen)") {
                    Picker("Quick button 1", selection: $quickOne) {
                        ForEach(quickChoices) { action in
                            Text(action.title).tag(action.id)
                        }
                    }
                    Picker("Quick button 2", selection: $quickTwo) {
                        ForEach(quickChoices) { action in
                            Text(action.title).tag(action.id)
                        }
                    }
                    Text("Hold a continuous quick button while moving your joystick. Each button can also be dragged and resized in EDIT.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Gesture Settings") {
                    Toggle("Instant PASS (disable double-tap PASS)", isOn: $instantPass)
                    Text("Instant pass reduces short-pass delay. Swipe PASS ↓ still performs Pass & Follow.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Toggle("Automatic attack/defend (experimental)", isOn: $controller.autoModeEnabled)
                    Text("Auto detection requires receiver calibration and may misclassify possession.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Testing") {
                    Text("On Windows open joy.cpl to verify sticks, face buttons, L1/R1, L2/R2 and the D-pad before playing.")
                    Text("Use FC 27 Classic controls. Gameplay and timing are not yet device-verified.")
                }
            }
            .navigationTitle("PC & CONTROLS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button("Close") { isPresented = false }
            }}
        }
    }
}
