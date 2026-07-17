import SwiftUI
import CoreLocation
import ServiceManagement
import WaqtaraCore

/// Launch at login via SMAppService (PRD F6) — hanya bekerja dari .app bundle.
enum LaunchAtLogin {
    static func set(_ enabled: Bool) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("LaunchAtLogin: \(error.localizedDescription)")
        }
    }
}

/// Deteksi lokasi sekali-pakai via CoreLocation (PRD F5) — tanpa tracking berkelanjutan.
@MainActor
final class LocationDetector: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var status: String?
    @Published var detected: Location?

    // Diisi pemanggil sesuai bahasa aktif sebelum detect().
    var statusDetecting = "Mendeteksi lokasi…"
    var statusFailed = "Deteksi gagal — pilih kota manual di bawah."

    private let manager = CLLocationManager()

    func detect() {
        status = statusDetecting
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        CLGeocoder().reverseGeocodeLocation(loc) { placemarks, _ in
            let name = placemarks?.first?.locality ?? placemarks?.first?.administrativeArea ?? "Lokasi Saya"
            let tz = placemarks?.first?.timeZone?.identifier ?? TimeZone.current.identifier
            Task { @MainActor in
                self.detected = Location(name: name,
                                         latitude: loc.coordinate.latitude,
                                         longitude: loc.coordinate.longitude,
                                         altitude: loc.altitude,
                                         timeZoneIdentifier: tz)
                self.status = nil
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.status = self.statusFailed
        }
    }
}

/// Jendela onboarding 3 langkah (PRD §8.1). Ditampilkan saat pertama kali dibuka.
@MainActor
enum OnboardingWindowController {
    private static var window: NSWindow?

    static func showIfNeeded(state: AppState) {
        guard !state.settings.onboardingDone else { return }
        let view = OnboardingView(onFinish: {
            state.settings.onboardingDone = true
            window?.close()
            window = nil
        }).environmentObject(state)
        let w = NSWindow(contentViewController: NSHostingController(rootView: view))
        w.title = L(state.settings.language).welcomeTitle
        w.styleMask = [.titled, .closable]
        w.center()
        w.isReleasedWhenClosed = false
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}

struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @StateObject private var detector = LocationDetector()
    @State private var step = 1
    @State private var query = ""
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text(state.l.stepOf(step)).font(.caption).foregroundStyle(.secondary)
            switch step {
            case 1: locationStep
            case 2: notificationStep
            default: doneStep
            }
            HStack {
                if step > 1 { Button(state.l.back) { step -= 1 } }
                Spacer()
                if step < 3 { Button(state.l.next) { step += 1 }.keyboardShortcut(.defaultAction) }
                else { Button(state.l.finish) { onFinish() }.keyboardShortcut(.defaultAction) }
            }
        }
        .padding(20)
        .frame(width: 420, height: 430)
    }

    private var locationStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.l.yourLocation).font(.title2.bold())
            Button {
                detector.statusDetecting = state.l.detecting
                detector.statusFailed = state.l.detectFailed
                detector.detect()
            } label: { Label(state.l.detectLocation, systemImage: "location.fill") }
            if let status = detector.status { Text(status).font(.caption).foregroundStyle(.secondary) }
            TextField(state.l.orSearchCity, text: $query).textFieldStyle(.roundedBorder)
            List(state.cityDatabase?.search(query) ?? []) { city in
                HStack {
                    Text(city.name); Text(city.country).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if state.settings.location.name == city.name { Image(systemName: "checkmark") }
                }
                .contentShape(Rectangle())
                .onTapGesture { state.settings.location = city.location }
            }
            .frame(height: 150)
            // Preview jadwal hari ini sebagai konfirmasi visual.
            if let schedule = state.schedule {
                Text("\(state.settings.location.name) \(state.l.today): " +
                     [PrayerName.shubuh, .dzuhur, .ashar, .maghrib, .isya]
                        .map { "\(state.prayerName($0)) \(state.timeString(schedule.time(for: $0)))" }
                        .joined(separator: " · "))
                    .font(.caption)
            }
        }
        .onReceive(detector.$detected) { loc in
            if let loc { state.settings.location = loc }
        }
    }

    private var notificationStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(state.l.notifPermTitle).font(.title2.bold())
            Text(state.l.notifPermBody)
            if state.reminderEngine.authorized {
                Label(state.l.permGranted, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button(state.l.openNotifSettings) {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
                }
                Text(state.l.dndHint)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(state.l.doneTitle).font(.title2.bold())
            Text(state.l.doneBody)
            Button {
                state.azanPlayer.play(for: .dzuhur, volume: state.settings.azanVolume)
            } label: { Label(state.l.testAzanNow, systemImage: "speaker.wave.2.fill") }
            if state.azanPlayer.isPlaying {
                Button(state.l.stop) { state.azanPlayer.stop() }
            }
            Spacer()
        }
    }
}
