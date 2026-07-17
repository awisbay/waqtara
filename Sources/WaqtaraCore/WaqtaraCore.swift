import Foundation
import Adhan

/// Metode kalkulasi yang didukung Waqtara (PRD F1).
public enum WaqtaraMethod: String, CaseIterable, Codable, Sendable {
    case kemenag        // Fajr 20°, Isya 18° — default Indonesia
    case muslimWorldLeague
    case karachi
    case northAmerica   // ISNA
    case ummAlQura
    case egyptian
    case custom
}

/// Pembulatan menit.
public enum RoundingMode: String, Codable, Sendable {
    case nearest, up, down
}

public enum PrayerName: String, CaseIterable, Codable, Sendable {
    case shubuh, terbit, dzuhur, ashar, maghrib, isya
    public var displayName: String {
        switch self {
        case .shubuh: return "Shubuh"
        case .terbit: return "Terbit"
        case .dzuhur: return "Dzuhur"
        case .ashar: return "Ashar"
        case .maghrib: return "Maghrib"
        case .isya: return "Isya"
        }
    }
}

/// Koreksi menit per waktu sholat (ikhtiyati).
/// Default dikalibrasi terhadap jadwal Kemenag (bimasislam) 5 kota x 5 tanggal 2026,
/// dikombinasikan dengan pembulatan ke atas: Shubuh +2, Terbit -4, Dzuhur +3,
/// Ashar +2, Maghrib +3, Isya +2.
public struct PrayerAdjustmentsMinutes: Codable, Equatable, Sendable {
    public var shubuh: Int
    public var terbit: Int
    public var dzuhur: Int
    public var ashar: Int
    public var maghrib: Int
    public var isya: Int

    public init(shubuh: Int = 2, terbit: Int = -4, dzuhur: Int = 3, ashar: Int = 2, maghrib: Int = 3, isya: Int = 2) {
        self.shubuh = shubuh
        self.terbit = terbit
        self.dzuhur = dzuhur
        self.ashar = ashar
        self.maghrib = maghrib
        self.isya = isya
    }
}

/// Pengingat sholat Jumat (PRD F3): waktu-waktu N jam sebelum Dzuhur,
/// hanya jika Dzuhur jatuh pada hari Jumat.
public enum FridayReminder {
    public static func times(dhuhr: Date, hoursBefore: [Int], timeZone: TimeZone) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        guard cal.component(.weekday, from: dhuhr) == 6 else { return [] }  // 6 = Jumat
        return hoursBefore.map { dhuhr.addingTimeInterval(-Double($0) * 3600) }
    }
}

public struct Location: Codable, Equatable, Sendable {
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var altitude: Double
    public var timeZoneIdentifier: String

    public init(name: String, latitude: Double, longitude: Double, altitude: Double = 0, timeZoneIdentifier: String) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    public var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .current }
}

public struct CalculationSettings: Codable, Equatable, Sendable {
    public var method: WaqtaraMethod
    /// Sudut kustom, hanya dipakai saat method == .custom
    public var customFajrAngle: Double
    public var customIshaAngle: Double
    public var madhab: AsrMadhab
    public var adjustments: PrayerAdjustmentsMinutes
    public var rounding: RoundingMode

    public enum AsrMadhab: String, Codable, Sendable { case shafi, hanafi }

    public init(method: WaqtaraMethod = .kemenag,
                customFajrAngle: Double = 20,
                customIshaAngle: Double = 18,
                madhab: AsrMadhab = .shafi,
                adjustments: PrayerAdjustmentsMinutes = .init(),
                rounding: RoundingMode = .up) {
        self.method = method
        self.customFajrAngle = customFajrAngle
        self.customIshaAngle = customIshaAngle
        self.madhab = madhab
        self.adjustments = adjustments
        self.rounding = rounding
    }

    /// Preset default menurut negara lokasi, mempertahankan pilihan madhab pengguna.
    /// - Indonesia: metode Kemenag + ikhtiyati kalibrasi Kemenag + pembulatan ke atas.
    /// - Negara lain: Muslim World League tanpa ikhtiyati + pembulatan normal — cocok
    ///   dengan jadwal internasional umum (mis. Google) dalam ~1 menit.
    /// Madhab Ashar tidak diubah karena itu pilihan fikih, bukan geografi.
    public static func regional(country: String, madhab: AsrMadhab) -> CalculationSettings {
        if country.uppercased() == "ID" {
            return CalculationSettings(method: .kemenag, madhab: madhab)
        }
        return CalculationSettings(
            method: .muslimWorldLeague,
            madhab: madhab,
            adjustments: PrayerAdjustmentsMinutes(shubuh: 0, terbit: 0, dzuhur: 0, ashar: 0, maghrib: 0, isya: 0),
            rounding: .nearest)
    }
}

/// Jadwal 6 waktu untuk satu hari.
public struct DailySchedule: Equatable, Sendable {
    public let date: DateComponents
    public let location: Location
    public let times: [PrayerName: Date]

    public func time(for prayer: PrayerName) -> Date { times[prayer]! }
}

public enum WaqtaraError: Error, LocalizedError {
    case invalidCoordinates
    case calculationFailed

    public var errorDescription: String? {
        switch self {
        case .invalidCoordinates: return "Invalid value for Latitude or Longitude"
        case .calculationFailed: return "Prayer time calculation failed"
        }
    }
}

public struct PrayerTimeCalculator {
    public let settings: CalculationSettings

    public init(settings: CalculationSettings = .init()) {
        self.settings = settings
    }

    private var calculationParameters: CalculationParameters {
        var params: CalculationParameters
        switch settings.method {
        case .kemenag:
            params = CalculationMethod.other.params
            params.fajrAngle = 20
            params.ishaAngle = 18
        case .custom:
            params = CalculationMethod.other.params
            params.fajrAngle = settings.customFajrAngle
            params.ishaAngle = settings.customIshaAngle
        case .muslimWorldLeague: params = CalculationMethod.muslimWorldLeague.params
        case .karachi: params = CalculationMethod.karachi.params
        case .northAmerica: params = CalculationMethod.northAmerica.params
        case .ummAlQura: params = CalculationMethod.ummAlQura.params
        case .egyptian: params = CalculationMethod.egyptian.params
        }
        params.madhab = settings.madhab == .hanafi ? .hanafi : .shafi
        return params
    }

    public func schedule(for date: Date, at location: Location) throws -> DailySchedule {
        guard (-90...90).contains(location.latitude), (-180...180).contains(location.longitude) else {
            throw WaqtaraError.invalidCoordinates
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = location.timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let coordinates = Coordinates(latitude: location.latitude, longitude: location.longitude)
        guard let raw = PrayerTimes(coordinates: coordinates, date: components, calculationParameters: calculationParameters) else {
            throw WaqtaraError.calculationFailed
        }
        let adj = settings.adjustments
        let times: [PrayerName: Date] = [
            .shubuh: rounded(raw.fajr.addingTimeInterval(Double(adj.shubuh) * 60)),
            .terbit: rounded(raw.sunrise.addingTimeInterval(Double(adj.terbit) * 60)),
            .dzuhur: rounded(raw.dhuhr.addingTimeInterval(Double(adj.dzuhur) * 60)),
            .ashar: rounded(raw.asr.addingTimeInterval(Double(adj.ashar) * 60)),
            .maghrib: rounded(raw.maghrib.addingTimeInterval(Double(adj.maghrib) * 60)),
            .isya: rounded(raw.isha.addingTimeInterval(Double(adj.isya) * 60)),
        ]
        return DailySchedule(date: components, location: location, times: times)
    }

    private func rounded(_ date: Date) -> Date {
        let t = date.timeIntervalSinceReferenceDate
        let minute = 60.0
        switch settings.rounding {
        case .nearest: return Date(timeIntervalSinceReferenceDate: (t / minute).rounded() * minute)
        case .up: return Date(timeIntervalSinceReferenceDate: (t / minute).rounded(.up) * minute)
        case .down: return Date(timeIntervalSinceReferenceDate: (t / minute).rounded(.down) * minute)
        }
    }
}
