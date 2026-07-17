import SwiftUI
import AppKit

/// Pop-up di tengah layar yang digambar app sendiri (bukan notifikasi OS, yang selalu
/// di pojok kanan atas). Dipakai untuk momen azan & pengingat Jumat agar menembus fokus.
@MainActor
enum CenterAlert {
    private static var window: NSWindow?

    static func show(title: String,
                     message: String,
                     messageProvider: (@MainActor @Sendable (Date) -> String)? = nil,
                     systemImage: String,
                     accent: Color,
                     stopTitle: String? = nil,
                     onStop: (() -> Void)? = nil,
                     dismissTitle: String) {
        dismiss()
        let view = CenterAlertView(
            title: title, message: message, messageProvider: messageProvider,
            systemImage: systemImage, accent: accent,
            stopTitle: stopTitle,
            onStop: { onStop?(); dismiss() },
            onDismiss: { dismiss() },
            dismissTitle: dismissTitle)
        let hosting = NSHostingController(rootView: view)
        let w = NSWindow(contentViewController: hosting)
        w.styleMask = [.borderless]
        w.level = .floating
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = true
        w.isMovableByWindowBackground = true
        w.isReleasedWhenClosed = false
        w.center()
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    static func dismiss() {
        window?.close()
        window = nil
    }
}

private struct CenterAlertView: View {
    let title: String
    let message: String
    let messageProvider: (@MainActor @Sendable (Date) -> String)?
    let systemImage: String
    let accent: Color
    let stopTitle: String?
    let onStop: () -> Void
    let onDismiss: () -> Void
    let dismissTitle: String
    @State private var now = Date()

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(accent)
            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            // Membaca `now` di sini membangun dependensi agar body render ulang tiap
            // detik — sehingga pesan live (hitung mundur/maju) ikut diperbarui.
            Text(messageProvider?(now) ?? message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                if let stopTitle {
                    Button(stopTitle, action: onStop)
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)
                }
                Button(dismissTitle, action: onDismiss)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .padding(32)
        .frame(width: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(accent.opacity(0.35), lineWidth: 1))
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
    }
}
