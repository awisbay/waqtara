import Foundation
import SwiftUI
import Combine
import WaqtaraCore

/// Mode tampilan ikon menu bar (PRD F2).
enum MenuBarDisplayMode: String, CaseIterable, Codable {
    case iconOnly, countdown, nextTime

    var label: String {
        switch self {
        case .iconOnly: return "Ikon saja"
        case .countdown: return "Ikon + countdown"
        case .nextTime: return "Ikon + jam sholat berikutnya"
        }
    }
}

/// Setting aplikasi, tersimpan di UserDefaults (padanan registry Shollu3).
struct AppSettings: Codable, Equatable {
    var location: Location = Location(name: "Jakarta", latitude: -6.2, longitude: 106.85, altitude: 8, timeZoneIdentifier: "Asia/Jakarta")
    var calculation: CalculationSettings = .init()
    var displayMode: MenuBarDisplayMode = .countdown
    var hijriOffsetDays: Int = 0          // −2…+2 (HijriyahDiff)
    var use24Hour: Bool = true
    var onboardingDone: Bool = false
    var reminders: ReminderSettings = .init()
    var azanEnabled: Bool = true      // mode senyap global: false = notifikasi saja
    var azanVolume: Double = 0.8
    var launchAtLogin: Bool = true
    var language: AppLanguage = .english

    init() {}

    // Decoder toleran: field baru boleh absen dari setting lama di UserDefaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        location = try c.decodeIfPresent(Location.self, forKey: .location) ?? d.location
        calculation = try c.decodeIfPresent(CalculationSettings.self, forKey: .calculation) ?? d.calculation
        displayMode = try c.decodeIfPresent(MenuBarDisplayMode.self, forKey: .displayMode) ?? d.displayMode
        hijriOffsetDays = try c.decodeIfPresent(Int.self, forKey: .hijriOffsetDays) ?? d.hijriOffsetDays
        use24Hour = try c.decodeIfPresent(Bool.self, forKey: .use24Hour) ?? d.use24Hour
        onboardingDone = try c.decodeIfPresent(Bool.self, forKey: .onboardingDone) ?? d.onboardingDone
        reminders = try c.decodeIfPresent(ReminderSettings.self, forKey: .reminders) ?? d.reminders
        azanEnabled = try c.decodeIfPresent(Bool.self, forKey: .azanEnabled) ?? d.azanEnabled
        azanVolume = try c.decodeIfPresent(Double.self, forKey: .azanVolume) ?? d.azanVolume
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? d.launchAtLogin
        language = try c.decodeIfPresent(AppLanguage.self, forKey: .language) ?? d.language
    }

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "settings"),
              let s = try? JSONDecoder().decode(AppSettings.self, from: data) else { return AppSettings() }
        return s
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "settings")
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            settings.save()
            if settings.location != oldValue.location || settings.calculation != oldValue.calculation
                || settings.reminders != oldValue.reminders || settings.language != oldValue.language {
                recalculate()
            }
        }
    }
    @Published private(set) var schedule: DailySchedule?

    /// Kamus string sesuai bahasa aktif.
    var l: L { L(settings.language) }

    func prayerName(_ p: PrayerName) -> String { p.name(in: settings.language) }

    @Published private(set) var now = Date()

    let cityDatabase: CityDatabase?
    let reminderEngine = ReminderEngine()
    let azanPlayer = AzanPlayer()

    private var tickTimer: Timer?
    private var azanTimer: Timer?
    private var fridayTimers: [Timer] = []
    private var wakeObserver: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?
    private var playerSink: AnyCancellable?

    init() {
        settings = AppSettings.load()
        cityDatabase = try? CityDatabase()
        reminderEngine.setup()
        reminderEngine.onStopAzan = { [weak self] in self?.azanPlayer.stop() }
        // Daftarkan login item sesuai setting (default on) — bukan hanya saat toggle diubah.
        LaunchAtLogin.set(settings.launchAtLogin)
        // Teruskan perubahan state player (ikon menu bar, tombol Stop di panel).
        playerSink = azanPlayer.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        recalculate()

        // Timer ringan 30 detik hanya untuk teks countdown menu bar (PRD §5 catatan 1).
        tickTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        tickTimer.map { RunLoop.main.add($0, forMode: .common) }

        // Rekalkulasi saat wake dari sleep (PRD §5 catatan 2).
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleWake() }
        }

        // Mac sleep saat azan berbunyi → audio berhenti, tidak dilanjutkan saat wake
        // (edge case PRD §8.3).
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.azanPlayer.stop() }
        }
    }

    /// Setelah wake: waktu sholat yang lewat selama sleep → notifikasi ringkas
    /// tanpa azan (edge case PRD §8.3), lalu jadwalkan ulang sisanya.
    private func handleWake() {
        let sleptSince = lastSeen
        recalculate()
        guard let schedule else { return }
        for prayer in PrayerName.allCases where prayer != .terbit && settings.reminders.isEnabled(prayer) {
            let t = schedule.time(for: prayer)
            if t > sleptSince && t <= Date() {
                reminderEngine.notifyMissed(prayer: prayer, time: t, timeString: timeString(t), l: l)
            }
        }
    }

    /// Timestamp aktivitas terakhir, diperbarui tiap tick — penanda kapan Mac mulai sleep.
    private var lastSeen: Date {
        get { UserDefaults.standard.object(forKey: "lastSeen") as? Date ?? Date() }
        set { UserDefaults.standard.set(newValue, forKey: "lastSeen") }
    }

    private func tick() {
        let previousDay = Calendar.current.startOfDay(for: now)
        now = Date()
        lastSeen = now
        // Pergantian hari saat app berjalan → refresh jadwal (edge case PRD §8.3).
        if Calendar.current.startOfDay(for: now) != previousDay {
            recalculate()
        }
    }

    /// Pilih lokasi baru dan sekaligus terapkan preset metode kalkulasi menurut negaranya
    /// (Indonesia → Kemenag, lainnya → MWL), mempertahankan madhab pilihan pengguna.
    func selectLocation(_ location: Location, country: String) {
        settings.calculation = .regional(country: country, madhab: settings.calculation.madhab)
        settings.location = location
    }

    func recalculate() {
        now = Date()
        lastSeen = now
        let calc = PrayerTimeCalculator(settings: settings.calculation)
        schedule = try? calc.schedule(for: now, at: settings.location)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)
            .flatMap { try? calc.schedule(for: $0, at: settings.location) }
        if let schedule {
            reminderEngine.reschedule(schedule: schedule, tomorrowSchedule: tomorrow,
                                      reminders: settings.reminders,
                                      locationName: settings.location.name, l: l)
        }
        armPrayerTimer()
        armFridayTimers()
    }

    /// Timer presisi satu-tembakan pada waktu sholat berikutnya: memutar azan (jika aktif)
    /// dan menampilkan pop-up tengah layar (jika aktif). Selalu re-arm lewat recalculate.
    /// (UNNotification menangani banner OS; audio & pop-up diputar oleh app sendiri.)
    private func armPrayerTimer() {
        azanTimer?.invalidate()
        guard let next = nextPrayer, next.time.timeIntervalSinceNow > 0 else { return }
        let prayer = next.name
        let scheduledTime = next.time
        azanTimer = Timer(fire: next.time, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                // Jangan bertindak jika telat (mis. timer tertahan karena sleep) — cegah azan telat.
                let onTime = abs(Date().timeIntervalSince(scheduledTime)) < 60
                if onTime, self.settings.reminders.isEnabled(prayer) {
                    if self.settings.azanEnabled {
                        self.azanPlayer.play(for: prayer, volume: self.settings.azanVolume)
                    }
                    if self.settings.reminders.centerAlertEnabled {
                        self.showAzanCenterAlert(prayer: prayer)
                    }
                }
                self.recalculate()  // re-arm untuk waktu berikutnya
            }
        }
        RunLoop.main.add(azanTimer!, forMode: .common)
    }

    private func showAzanCenterAlert(prayer: PrayerName) {
        let name = prayerName(prayer)
        CenterAlert.show(
            title: l.azanTitle(name),
            message: l.azanBody(name, settings.location.name),
            systemImage: "moon.stars.fill",
            accent: .orange,
            stopTitle: azanPlayer.isPlaying ? l.stopAzan : nil,
            onStop: { [weak self] in self?.azanPlayer.stop() },
            dismissTitle: l.dismiss)
    }

    /// Pop-up tengah layar untuk pengingat Jumat (2 jam & 1 jam sebelum Dzuhur).
    private func armFridayTimers() {
        fridayTimers.forEach { $0.invalidate() }
        fridayTimers = []
        guard settings.reminders.fridayEnabled, settings.reminders.centerAlertEnabled,
              let schedule else { return }
        let dhuhr = schedule.time(for: .dzuhur)
        let times = FridayReminder.times(dhuhr: dhuhr, hoursBefore: settings.reminders.fridayHoursBefore,
                                         timeZone: settings.location.timeZone)
        for (h, t) in zip(settings.reminders.fridayHoursBefore, times) {
            guard t.timeIntervalSinceNow > 0 else { continue }
            let hours = h
            let timer = Timer(fire: t, interval: 0, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    CenterAlert.show(title: self.l.fridayTitle,
                                     message: self.l.fridayBody(hours),
                                     systemImage: "figure.walk",
                                     accent: .green,
                                     dismissTitle: self.l.dismiss)
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            fridayTimers.append(timer)
        }
    }

    // MARK: - Derivasi tampilan

    /// Waktu sholat berikutnya (skip Terbit — bukan waktu sholat, PRD F1).
    var nextPrayer: (name: PrayerName, time: Date)? {
        guard let schedule else { return nil }
        let upcoming = PrayerName.allCases
            .filter { $0 != .terbit }
            .compactMap { p in schedule.times[p].map { (p, $0) } }
            .filter { $0.1 > now }
            .min { $0.1 < $1.1 }
        if let upcoming { return upcoming }
        // Semua waktu hari ini lewat → Shubuh besok.
        let calcTomorrow = PrayerTimeCalculator(settings: settings.calculation)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        guard let s = try? calcTomorrow.schedule(for: tomorrow, at: settings.location) else { return nil }
        return (.shubuh, s.time(for: .shubuh))
    }

    /// Waktu sholat yang sedang berlangsung (untuk highlight panel).
    var currentPrayer: PrayerName? {
        guard let schedule else { return nil }
        return PrayerName.allCases
            .filter { $0 != .terbit }
            .compactMap { p in schedule.times[p].map { (p, $0) } }
            .filter { $0.1 <= now }
            .max { $0.1 < $1.1 }?.0
    }

    var menuBarTitle: String {
        guard let next = nextPrayer else { return "" }
        switch settings.displayMode {
        case .iconOnly:
            return ""
        case .countdown:
            let remaining = max(0, Int(next.time.timeIntervalSince(now)))
            let h = remaining / 3600, m = (remaining % 3600) / 60
            return String(format: "%@ −%02d:%02d", prayerName(next.name), h, m)
        case .nextTime:
            return "\(prayerName(next.name)) \(timeString(next.time))"
        }
    }

    func timeString(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = settings.use24Hour ? "HH:mm" : "h:mm a"
        df.timeZone = settings.location.timeZone
        return df.string(from: date)
    }

    var gregorianDateString: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: settings.language.localeIdentifier)
        df.timeZone = settings.location.timeZone
        df.dateFormat = "EEEE, d MMMM yyyy"
        return df.string(from: now)
    }

    var hijriDateString: String {
        HijriDate.string(for: now, offsetDays: settings.hijriOffsetDays, timeZone: settings.location.timeZone,
                         locale: Locale(identifier: settings.language.localeIdentifier))
    }
}
