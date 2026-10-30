import SwiftUI
import UIKit

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
    @State private var showSetPieceExtras = false

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "soccerball")
                    Text("GAME MODE").font(.system(size: 10, weight: .bold))
                    Picker("Game mode", selection: $screen) {
                        ForEach(SetPieceScreen.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.green)
                    if screen != .match {
                        Button("EXTRAS") {
                            controller.releaseInputs()
                            showSetPieceExtras = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.mint)
                    }
                    Spacer(minLength: 3)
                    Circle().fill(controller.paired ? .green : .orange)
                        .frame(width: 7, height: 7)
                    Text(controller.paired ? "PC CONNECTED" : "NOT CONNECTED")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Color(red: 0.08, green: 0.12, blue: 0.14))

                ZStack {
                    // Keep the match controller mounted to preserve pairing.
                    ControllerView()
                        .opacity(screen == .match ? 1 : 0)
                        .allowsHitTesting(screen == .match)
                    if screen != .match { SetPiecePad(screen: screen) }
                }
            }
            .background(Color(red: 0.025, green: 0.035, blue: 0.075))
            .environmentObject(controller)
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showSetPieceExtras) {
                ActionLibraryView(initialCategory: .setPieces)
                    .environmentObject(controller)
            }
            .onChange(of: screen) { _ in controller.releaseInputs() }
            .onChange(of: scenePhase) { phase in
                if phase != .active { controller.disconnect() }
            }
        }
    }
}
