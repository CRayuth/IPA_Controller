
import SwiftUI

enum SetPieceScreen: String, CaseIterable, Identifiable {
    case match, penalty, penaltySave, freeKick, corner

    var id: String { rawValue }

    var title: String {
        switch self {
        case .match: return "MATCH"
        case .penalty: return "PENALTY — SHOOT"
        case .penaltySave: return "PENALTY — SAVE"
        case .freeKick: return "FREE KICK"
        case .corner: return "CORNER"
        }
    }
}

@main
struct TouchPadFCApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var controller = ControllerModel()
    @State private var screen: SetPieceScreen = .match

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "soccerball")
                    Text("GAME MODE")
                        .font(.system(size: 11, weight: .bold))

                    Picker("Game mode", selection: $screen) {
                        ForEach(SetPieceScreen.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.green)

                    Spacer(minLength: 4)

                    Circle()
                        .fill(controller.paired ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(controller.paired ? "PC CONNECTED" : "NOT CONNECTED")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Color(red: 0.08, green: 0.12, blue: 0.14))

                ZStack {
                    // Keep the match screen mounted so changing game mode
                    // doesn't run its onDisappear disconnect handler.
                    ControllerView()
                        .opacity(screen == .match ? 1 : 0)
                        .allowsHitTesting(screen == .match)

                    if screen != .match {
                        SetPiecePad(screen: screen)
                    }
                }
            }
            .background(Color(red: 0.025, green: 0.035, blue: 0.075))
            .environmentObject(controller)
            .preferredColorScheme(.dark)
            .onChange(of: screen) { _ in
                controller.releaseInputs()
            }
            .onChange(of: scenePhase) { phase in
                if phase != .active {
                    controller.disconnect()
                }
            }
        }
    }
}
