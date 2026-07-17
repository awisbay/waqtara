import Foundation
import WaqtaraCore

/// Bahasa UI (PRD P1 — English).
enum AppLanguage: String, Codable, CaseIterable {
    case indonesian, english

    var label: String {
        switch self {
        case .indonesian: return "Bahasa Indonesia"
        case .english: return "English"
        }
    }

    var localeIdentifier: String {
        self == .indonesian ? "id_ID" : "en_US"
    }
}

extension PrayerName {
    func name(in language: AppLanguage) -> String {
        guard language == .english else { return displayName }
        switch self {
        case .shubuh: return "Fajr"
        case .terbit: return "Sunrise"
        case .dzuhur: return "Dhuhr"
        case .ashar: return "Asr"
        case .maghrib: return "Maghrib"
        case .isya: return "Isha"
        }
    }
}

/// Kamus string UI & notifikasi. Ambil via `L(language)`.
struct L {
    let lang: AppLanguage
    init(_ lang: AppLanguage) { self.lang = lang }

    private func t(_ id: String, _ en: String) -> String {
        lang == .indonesian ? id : en
    }

    // Panel
    var scheduleUnavailable: String { t("Jadwal tidak tersedia — periksa pengaturan lokasi.", "Schedule unavailable — check location settings.") }
    var settings: String { t("Settings…", "Settings…") }
    var quit: String { t("Quit", "Quit") }
    var stopAzan: String { t("Stop Azan", "Stop Adhan") }
    var azanLabel: String { t("Azan", "Adhan") }

    // Tabs
    var tabLocation: String { t("Lokasi", "Location") }
    var tabCalculation: String { t("Kalkulasi", "Calculation") }
    var tabReminder: String { t("Reminder", "Reminders") }
    var tabGeneral: String { t("Umum", "General") }

    // Location tab
    var activeLocation: String { t("Lokasi aktif", "Active location") }
    var searchCity: String { t("Cari kota…", "Search city…") }
    var coordinates: String { t("Koordinat", "Coordinates") }

    // Calculation tab
    var method: String { t("Metode", "Method") }
    var methodKemenag: String { t("Kemenag RI (Fajr 20°, Isya 18°)", "Kemenag Indonesia (Fajr 20°, Isha 18°)") }
    var fajrAngle: String { t("Sudut Fajr (°)", "Fajr angle (°)") }
    var ishaAngle: String { t("Sudut Isya (°)", "Isha angle (°)") }
    var asrMadhab: String { t("Madhab Ashar", "Asr madhab") }
    var minuteCorrections: String { t("Koreksi menit (ikhtiyati)", "Minute corrections (precaution)") }
    var minutes: String { t("menit", "min") }
    var rounding: String { t("Pembulatan", "Rounding") }
    var roundingNearest: String { t("Normal", "Nearest") }
    var roundingUp: String { t("Selalu ke atas", "Always up") }
    var roundingDown: String { t("Selalu ke bawah", "Always down") }

    // Reminder tab
    var phase1: String { t("Fase 1 — Pra-azan", "Phase 1 — Before adhan") }
    var preAzanToggle: String { t("Notifikasi persiapan", "Preparation notification") }
    func minutesBefore(_ n: Int) -> String { t("\(n) menit sebelum azan", "\(n) minutes before adhan") }
    var phase3: String { t("Fase 3 — Pasca-azan", "Phase 3 — After adhan") }
    var postAzanToggle: String { t("Notifikasi susulan", "Follow-up notification") }
    func minutesAfter(_ n: Int) -> String { t("\(n) menit sesudah azan", "\(n) minutes after adhan") }
    var perPrayerSection: String { t("Reminder per waktu sholat", "Reminders per prayer") }
    var testNotification: String { t("Uji Notifikasi", "Test Notification") }
    var fridaySection: String { t("Sholat Jumat", "Friday Prayer") }
    var fridayToggle: String { t("Pengingat Jumat (2 jam & 1 jam sebelum Dzuhur)", "Friday reminder (2h & 1h before Dhuhr)") }
    var centerAlertToggle: String { t("Pop-up di tengah layar saat waktu sholat", "Center-screen pop-up at prayer time") }
    var testCenterAlert: String { t("Uji Pop-up", "Test Pop-up") }
    var notifPermissionWarning: String {
        t("⚠️ Izin notifikasi belum diberikan — buka System Settings → Notifications → Waqtara.",
          "⚠️ Notification permission not granted — open System Settings → Notifications → Waqtara.")
    }

    // General tab
    var menuBarDisplay: String { t("Tampilan menu bar", "Menu bar display") }
    func displayModeLabel(_ mode: MenuBarDisplayMode) -> String {
        switch mode {
        case .iconOnly: return t("Ikon saja", "Icon only")
        case .countdown: return t("Ikon + countdown", "Icon + countdown")
        case .nextTime: return t("Ikon + jam sholat berikutnya", "Icon + next prayer time")
        }
    }
    var use24h: String { t("Format 24 jam", "24-hour format") }
    var launchAtLogin: String { t("Buka otomatis saat login", "Launch at login") }
    var language: String { t("Bahasa", "Language") }
    var azanSection: String { t("Azan", "Adhan") }
    var azanToggle: String { t("Putar suara azan (matikan = notifikasi saja)", "Play adhan sound (off = notification only)") }
    var testAzan: String { t("Uji Azan", "Test Adhan") }
    func hijriCorrection(_ d: Int) -> String {
        let v = "\(d >= 0 ? "+" : "")\(d)"
        return t("Koreksi Hijriyah: \(v) hari", "Hijri correction: \(v) days")
    }
    var about: String {
        t("Waqtara — terinspirasi Shollu oleh Ebta Setiawan.\nAudio azan: Internet Archive (public domain/CC0).",
          "Waqtara — inspired by Shollu by Ebta Setiawan.\nAdhan audio: Internet Archive (public domain/CC0).")
    }

    // Notifikasi (fase 1–3, terlewat, uji)
    func preTitle(_ prayer: String) -> String { t("Persiapan \(prayer)", "Prepare for \(prayer)") }
    func preBody(_ n: Int, _ prayer: String) -> String { t("\(n) menit lagi waktu \(prayer)", "\(n) minutes until \(prayer)") }
    func azanTitle(_ prayer: String) -> String { t("Waktu \(prayer)", "\(prayer) time") }
    func azanBody(_ prayer: String, _ city: String) -> String {
        t("Telah masuk waktu \(prayer) untuk wilayah \(city)", "It is now time for \(prayer) in \(city)")
    }
    func postTitle(_ prayer: String) -> String { t("Pengingat \(prayer)", "\(prayer) reminder") }
    func postBody(_ prayer: String, _ n: Int) -> String {
        t("Waktu \(prayer) telah lewat \(n) menit", "\(prayer) time was \(n) minutes ago")
    }
    func missedBody(_ prayer: String, _ time: String) -> String {
        t("Waktu \(prayer) telah masuk pukul \(time)", "\(prayer) time began at \(time)")
    }
    var fridayTitle: String { t("Persiapan Sholat Jumat", "Friday Prayer") }
    func fridayBody(_ hours: Int) -> String {
        t("Sekitar \(hours) jam lagi menuju sholat Jumat — persiapkan diri.",
          "Jumu'ah is in about \(hours) hour\(hours == 1 ? "" : "s") — prepare yourself.")
    }
    var dismiss: String { t("Tutup", "Dismiss") }
    var testNotifTitle: String { t("Uji Notifikasi Waqtara", "Waqtara Test Notification") }
    func testNotifBody(_ city: String) -> String {
        t("Telah masuk waktu Ashar untuk wilayah \(city) (simulasi)", "It is now time for Asr in \(city) (simulation)")
    }

    // Onboarding
    func stepOf(_ n: Int) -> String { t("Langkah \(n) dari 3", "Step \(n) of 3") }
    var yourLocation: String { t("Lokasi Anda", "Your Location") }
    var detectLocation: String { t("Deteksi Lokasi Saya", "Detect My Location") }
    var detecting: String { t("Mendeteksi lokasi…", "Detecting location…") }
    var detectFailed: String { t("Deteksi gagal — pilih kota manual di bawah.", "Detection failed — pick a city below.") }
    var orSearchCity: String { t("…atau cari kota", "…or search for a city") }
    var today: String { t("hari ini", "today") }
    var notifPermTitle: String { t("Izin Notifikasi", "Notification Permission") }
    var notifPermBody: String {
        t("Waqtara memakai notifikasi untuk mengingatkan Anda sebelum, saat, dan sesudah masuk waktu sholat. Tanpa izin ini, hanya countdown di menu bar yang terlihat.",
          "Waqtara uses notifications to remind you before, at, and after each prayer time. Without permission, only the menu bar countdown is visible.")
    }
    var permGranted: String { t("Izin sudah diberikan", "Permission granted") }
    var openNotifSettings: String { t("Buka System Settings → Notifications", "Open System Settings → Notifications") }
    var dndHint: String {
        t("Aktifkan juga \"Allow notifications\" saat mode Fokus/DND agar reminder tetap tembus.",
          "Also enable \"Allow notifications\" for Focus/DND modes so reminders get through.")
    }
    var doneTitle: String { t("Selesai! 🎉", "Done! 🎉") }
    var doneBody: String {
        t("Waqtara sekarang hidup di menu bar ↗ (pojok kanan atas). Klik ikonnya untuk melihat jadwal hari ini.",
          "Waqtara now lives in your menu bar ↗ (top right). Click its icon to see today's schedule.")
    }
    var testAzanNow: String { t("Uji Azan Sekarang", "Test Adhan Now") }
    var stop: String { t("Stop", "Stop") }
    var back: String { t("Kembali", "Back") }
    var next: String { t("Lanjut", "Next") }
    var finish: String { t("Selesai", "Finish") }
    var welcomeTitle: String { t("Selamat Datang di Waqtara", "Welcome to Waqtara") }
}
