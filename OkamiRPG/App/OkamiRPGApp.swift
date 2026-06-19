import SwiftUI

@main
struct OkamiRPGApp: App {
    @State private var state = GameState()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .onAppear {
                    #if DEBUG
                    debugAutoStart(state)
                    #endif
                }
        }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                SaveManager.save(state)
            }
        }
    }
}

struct RootView: View {
    @Environment(GameState.self) var state

    var body: some View {
        switch state.screen {
        case .splash, .classSelect, .dante:
            SplashView()
        case .rest:
            RestScreenView()
        case .playing, .paused:
            GameContainerView()
        case .equipment:
            EquipmentView()
        case .shop:
            ShopAltarView(mode: .shop)
        case .altar:
            ShopAltarView(mode: .altar)
        case .death, .victory:
            GameOverView()
        }
    }
}

#if DEBUG
func debugAutoStart(_ state: GameState) {
    guard CommandLine.arguments.contains("--newgame"),
          state.screen == .splash else { return }
    state.startGame(cls: "warrior")
    enterFloor(state: state)
    generateFloor(state: state)
    computeVision(state: state)
    state.screen = .playing
}
#endif
