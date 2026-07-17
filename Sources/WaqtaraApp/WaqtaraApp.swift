import SwiftUI
import WaqtaraCore

@main
struct WaqtaraApp: App {
    @StateObject private var state = AppState()

    init() {
        // Hidup hanya di menu bar, tanpa dock icon (LSUIElement saat jadi .app bundle).
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    @State private var onboardingShown = false

    var body: some Scene {
        // Mode uji dari CLI: `Waqtara --test-azan` memutar azan 5 detik lalu keluar.
        let _ = Self.runTestAzanIfRequested(state: state)
        MenuBarExtra {
            PanelView().environmentObject(state)
        } label: {
            // Ikon berubah state saat azan berbunyi (PRD F2).
            HStack(spacing: 4) {
                Image(systemName: state.azanPlayer.isPlaying ? "speaker.wave.3.fill" : "moon.stars.fill")
                if state.azanPlayer.isPlaying {
                    Text(state.l.azanLabel).monospacedDigit()
                } else if !state.menuBarTitle.isEmpty {
                    Text(state.menuBarTitle).monospacedDigit()
                }
            }
            .task {
                if !onboardingShown {
                    onboardingShown = true
                    OnboardingWindowController.showIfNeeded(state: state)
                }
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView().environmentObject(state)
        }
    }

    private static var testStarted = false
    @MainActor
    static func runTestAzanIfRequested(state: AppState) {
        guard CommandLine.arguments.contains("--test-azan"), !testStarted else { return }
        testStarted = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            state.azanPlayer.play(for: .dzuhur, volume: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                NSLog("AzanPlayer: isPlaying=%@", state.azanPlayer.isPlaying ? "true" : "false")
                exit(state.azanPlayer.isPlaying ? 0 : 1)
            }
        }
    }
}
