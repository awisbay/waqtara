import Foundation
import UserNotifications
import WaqtaraCore

/// Pengaturan mesin reminder 3 fase (PRD F3).
struct ReminderSettings: Codable, Equatable {
    var preAzanEnabled = true
    var preAzanMinutes = 10      // 5–30
    var postAzanEnabled = true
    var postAzanMinutes = 15     // 10–60
    /// Toggle per waktu sholat (default semua aktif).
    var enabledPrayers: [String: Bool] = [:]

    /// Pesan tambahan opsional per waktu sholat untuk fase pra/pasca-azan (mis. "Baca 5
    /// ayat Quran", "Olahraga 1 menit"). Bila diisi, jadi baris kedua di notifikasi & pop-up.
    var preAzanMessages: [String: String] = [:]
    var postAzanMessages: [String: String] = [:]

    /// Pengingat sholat Jumat (PRD F3, `MJumat`): notifikasi 2 jam & 1 jam sebelum
    /// Dzuhur pada hari Jumat untuk persiapan Jumatan.
    var fridayEnabled = true
    var fridayHoursBefore: [Int] = [2, 1]

    /// Pop-up di tengah layar saat waktu sholat tiba (dan pengingat Jumat) — menembus
    /// mode fokus, karena notifikasi OS macOS selalu di pojok kanan atas.
    var centerAlertEnabled = true

    init() {}

    // Decoder toleran: field baru boleh absen dari setting lama di UserDefaults, agar
    // penambahan fitur tidak me-reset setelan pengguna.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ReminderSettings()
        preAzanEnabled = try c.decodeIfPresent(Bool.self, forKey: .preAzanEnabled) ?? d.preAzanEnabled
        preAzanMinutes = try c.decodeIfPresent(Int.self, forKey: .preAzanMinutes) ?? d.preAzanMinutes
        postAzanEnabled = try c.decodeIfPresent(Bool.self, forKey: .postAzanEnabled) ?? d.postAzanEnabled
        postAzanMinutes = try c.decodeIfPresent(Int.self, forKey: .postAzanMinutes) ?? d.postAzanMinutes
        enabledPrayers = try c.decodeIfPresent([String: Bool].self, forKey: .enabledPrayers) ?? d.enabledPrayers
        preAzanMessages = try c.decodeIfPresent([String: String].self, forKey: .preAzanMessages) ?? d.preAzanMessages
        postAzanMessages = try c.decodeIfPresent([String: String].self, forKey: .postAzanMessages) ?? d.postAzanMessages
        fridayEnabled = try c.decodeIfPresent(Bool.self, forKey: .fridayEnabled) ?? d.fridayEnabled
        fridayHoursBefore = try c.decodeIfPresent([Int].self, forKey: .fridayHoursBefore) ?? d.fridayHoursBefore
        centerAlertEnabled = try c.decodeIfPresent(Bool.self, forKey: .centerAlertEnabled) ?? d.centerAlertEnabled
    }

    func isEnabled(_ prayer: PrayerName) -> Bool {
        enabledPrayers[prayer.rawValue] ?? true
    }

    private func appended(_ base: String, _ extra: String) -> String {
        let trimmed = extra.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? base : base + "\n" + trimmed
    }
    func preBody(base: String, prayer: PrayerName) -> String {
        appended(base, preAzanMessages[prayer.rawValue] ?? "")
    }
    func postBody(base: String, prayer: PrayerName) -> String {
        appended(base, postAzanMessages[prayer.rawValue] ?? "")
    }
}

/// Menjadwalkan UNNotificationRequest untuk 3 fase reminder tiap waktu sholat.
/// Meniru Message1 / onAdzanTiba / Message2 Shollu, tapi berbasis penjadwalan OS
/// (bukan polling per detik) sesuai catatan arsitektur PRD §5.
@MainActor
final class ReminderEngine: NSObject {
    nonisolated static let categoryID = "waqtara.azan"
    nonisolated static let stopActionID = "waqtara.azan.stop"

    private let center = UNUserNotificationCenter.current()
    private(set) var authorized = false
    /// Dipanggil saat user menekan [Stop Azan] (dipakai Milestone 4).
    var onStopAzan: (() -> Void)?

    func setup() {
        center.delegate = self
        let stop = UNNotificationAction(identifier: Self.stopActionID, title: "Stop Azan", options: [])
        let category = UNNotificationCategory(identifier: Self.categoryID, actions: [stop], intentIdentifiers: [])
        center.setNotificationCategories([category])
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            Task { @MainActor in self.authorized = granted }
        }
    }

    /// Jadwalkan ulang semua notifikasi: hari ini (yang belum lewat) + Shubuh besok.
    /// Dipanggil saat: launch, ganti setting, wake dari sleep, tengah malam.
    func reschedule(schedule: DailySchedule, tomorrowSchedule: DailySchedule?, reminders: ReminderSettings, locationName: String, use24Hour: Bool, l: L) {
        center.removeAllPendingNotificationRequests()
        // Perbarui judul tombol [Stop Azan] sesuai bahasa aktif.
        let stop = UNNotificationAction(identifier: Self.stopActionID, title: l.stopAzan, options: [])
        center.setNotificationCategories([UNNotificationCategory(identifier: Self.categoryID, actions: [stop], intentIdentifiers: [])])
        let now = Date()

        // Jam absolut untuk teks notifikasi OS — banner tidak bisa dihitung ulang live,
        // jadi tampilkan pukul berapa (bukan "N menit lagi" yang cepat basi).
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = use24Hour ? "HH:mm" : "h:mm a"
        timeFmt.timeZone = schedule.location.timeZone

        var entries: [(PrayerName, Date)] = PrayerName.allCases
            .filter { $0 != .terbit && reminders.isEnabled($0) }
            .map { ($0, schedule.time(for: $0)) }
        if let tomorrow = tomorrowSchedule, reminders.isEnabled(.shubuh) {
            entries.append((.shubuh, tomorrow.time(for: .shubuh)))
        }

        for (prayer, time) in entries {
            let dayTag = ISO8601DateFormatter.dayTag(for: time)
            let name = prayer.name(in: l.lang)

            if reminders.preAzanEnabled {
                let preTime = time.addingTimeInterval(-Double(reminders.preAzanMinutes) * 60)
                if preTime > now {
                    add(id: "pre-\(prayer.rawValue)-\(dayTag)",
                        title: l.preTitle(name),
                        body: reminders.preBody(base: l.preAt(name, timeFmt.string(from: time)), prayer: prayer),
                        at: preTime, azan: false)
                }
            }
            if time > now {
                add(id: "azan-\(prayer.rawValue)-\(dayTag)",
                    title: l.azanTitle(name),
                    body: l.azanBody(name, locationName),
                    at: time, azan: true)
            }
            if reminders.postAzanEnabled {
                let postTime = time.addingTimeInterval(Double(reminders.postAzanMinutes) * 60)
                if postTime > now && time > now {
                    add(id: "post-\(prayer.rawValue)-\(dayTag)",
                        title: l.postTitle(name),
                        body: reminders.postBody(base: l.postAt(name, timeFmt.string(from: time)), prayer: prayer),
                        at: postTime, azan: false)
                }
            }
        }

        // Pengingat Jumat: N jam sebelum Dzuhur pada hari Jumat.
        if reminders.fridayEnabled {
            let dhuhr = schedule.time(for: .dzuhur)
            let dayTag = ISO8601DateFormatter.dayTag(for: dhuhr)
            let times = FridayReminder.times(dhuhr: dhuhr, hoursBefore: reminders.fridayHoursBefore,
                                             timeZone: schedule.location.timeZone)
            for (h, t) in zip(reminders.fridayHoursBefore, times) where t > now {
                add(id: "friday-\(h)-\(dayTag)",
                    title: l.fridayTitle,
                    body: l.fridayAt(timeFmt.string(from: dhuhr)),
                    at: t, azan: false)
            }
        }
    }

    /// Notifikasi ringkas untuk waktu sholat yang terlewat saat Mac sleep
    /// (edge case PRD §8.3) — tanpa azan penuh.
    func notifyMissed(prayer: PrayerName, time: Date, timeString: String, l: L) {
        let name = prayer.name(in: l.lang)
        let content = UNMutableNotificationContent()
        content.title = l.azanTitle(name)
        content.body = l.missedBody(name, timeString)
        content.sound = .default
        let request = UNNotificationRequest(identifier: "missed-\(prayer.rawValue)-\(time.timeIntervalSince1970)",
                                            content: content, trigger: nil)
        center.add(request)
    }

    /// Tombol "Uji Notifikasi & Azan" (PRD F6) — simulasi fase 2 seketika.
    func sendTestNotification(locationName: String, l: L) {
        let content = UNMutableNotificationContent()
        content.title = l.testNotifTitle
        content.body = l.testNotifBody(locationName)
        content.sound = .default
        content.categoryIdentifier = Self.categoryID
        center.add(UNNotificationRequest(identifier: "test-\(Date().timeIntervalSince1970)", content: content, trigger: nil))
    }

    private func add(id: String, title: String, body: String, at date: Date, azan: Bool) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if azan { content.categoryIdentifier = Self.categoryID }
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}

extension ReminderEngine: UNUserNotificationCenterDelegate {
    // Tampilkan banner meski app "foreground" (menu bar app selalu foreground-less,
    // tapi delegate ini memastikan notifikasi tak ditelan saat panel terbuka).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == Self.stopActionID {
            Task { @MainActor in self.onStopAzan?() }
        }
        completionHandler()
    }
}

private extension ISO8601DateFormatter {
    static func dayTag(for date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: date)
    }
}
