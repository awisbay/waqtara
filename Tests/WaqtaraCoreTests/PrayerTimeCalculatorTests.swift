import XCTest
@testable import WaqtaraCore

/// Acceptance criteria F1: selisih ≤1 menit vs jadwal Kemenag (bimasislam, via api.myquran.com)
/// untuk 5 kota × 5 tanggal (fixture: Fixtures/kemenag-reference.json, diambil 17 Jul 2026).
final class PrayerTimeCalculatorTests: XCTestCase {

    static let testCities: [String: Location] = [
        "jakarta": Location(name: "Jakarta", latitude: -6.2, longitude: 106.85, altitude: 8, timeZoneIdentifier: "Asia/Jakarta"),
        "surabaya": Location(name: "Surabaya", latitude: -7.25, longitude: 112.75, altitude: 5, timeZoneIdentifier: "Asia/Jakarta"),
        "medan": Location(name: "Medan", latitude: 3.59, longitude: 98.67, altitude: 25, timeZoneIdentifier: "Asia/Jakarta"),
        "makassar": Location(name: "Makassar", latitude: -5.14, longitude: 119.42, altitude: 5, timeZoneIdentifier: "Asia/Makassar"),
        "tangerang-selatan": Location(name: "Tangerang Selatan", latitude: -6.29, longitude: 106.72, altitude: 25, timeZoneIdentifier: "Asia/Jakarta"),
    ]

    struct Reference: Decodable {
        let subuh, terbit, dzuhur, ashar, maghrib, isya: String
    }

    private func loadFixture() throws -> [String: [String: Reference]] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "kemenag-reference", withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode([String: [String: Reference]].self, from: Data(contentsOf: url))
    }

    private func minutesOfDay(_ date: Date, tz: TimeZone) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.hour, .minute], from: date)
        return c.hour! * 60 + c.minute!
    }

    private func minutes(_ hhmm: String) -> Int {
        let p = hhmm.split(separator: ":")
        return Int(p[0])! * 60 + Int(p[1])!
    }

    /// F1 utama: semua waktu sholat (tanpa terbit) selisih ≤1 menit dari Kemenag.
    func testAccuracyAgainstKemenag() throws {
        let fixture = try loadFixture()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let calc = PrayerTimeCalculator()  // default: Kemenag preset

        var failures: [String] = []
        for (cityKey, dates) in fixture {
            let location = try XCTUnwrap(Self.testCities[cityKey])
            df.timeZone = location.timeZone
            for (dateString, ref) in dates {
                let schedule = try calc.schedule(for: XCTUnwrap(df.date(from: dateString)), at: location)
                let pairs: [(PrayerName, String)] = [
                    (.shubuh, ref.subuh), (.terbit, ref.terbit), (.dzuhur, ref.dzuhur),
                    (.ashar, ref.ashar), (.maghrib, ref.maghrib), (.isya, ref.isya),
                ]
                for (prayer, expected) in pairs {
                    let got = minutesOfDay(schedule.time(for: prayer), tz: location.timeZone)
                    let diff = got - minutes(expected)
                    if abs(diff) > 1 {
                        failures.append("\(cityKey) \(dateString) \(prayer.rawValue): kemenag \(expected), waqtara diff \(diff) menit")
                    }
                }
            }
        }
        XCTAssertTrue(failures.isEmpty, "Selisih >1 menit:\n" + failures.joined(separator: "\n"))
    }

    func testOffsetsApplied() throws {
        var withOffsets = CalculationSettings()
        withOffsets.adjustments = .init(shubuh: 0, terbit: 0, dzuhur: 2, ashar: 0, maghrib: 2, isya: 0)
        withOffsets.rounding = .nearest
        var noOffsets = CalculationSettings()
        noOffsets.adjustments = .init(shubuh: 0, terbit: 0, dzuhur: 0, ashar: 0, maghrib: 0, isya: 0)
        noOffsets.rounding = .nearest
        let jakarta = Self.testCities["jakarta"]!
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = jakarta.timeZone
        let date = df.date(from: "2026-07-17")!

        let a = try PrayerTimeCalculator(settings: withOffsets).schedule(for: date, at: jakarta)
        let b = try PrayerTimeCalculator(settings: noOffsets).schedule(for: date, at: jakarta)
        XCTAssertEqual(a.time(for: .dzuhur).timeIntervalSince(b.time(for: .dzuhur)), 120)
        XCTAssertEqual(a.time(for: .maghrib).timeIntervalSince(b.time(for: .maghrib)), 120)
        XCTAssertEqual(a.time(for: .shubuh), b.time(for: .shubuh))
    }

    func testInvalidCoordinatesThrows() {
        let bad = Location(name: "X", latitude: 99, longitude: 200, timeZoneIdentifier: "Asia/Jakarta")
        XCTAssertThrowsError(try PrayerTimeCalculator().schedule(for: Date(), at: bad))
    }

    func testCustomAnglesMatchKemenagPreset() throws {
        var custom = CalculationSettings()
        custom.method = .custom
        custom.customFajrAngle = 20
        custom.customIshaAngle = 18
        let jakarta = Self.testCities["jakarta"]!
        let date = Date()
        let a = try PrayerTimeCalculator(settings: custom).schedule(for: date, at: jakarta)
        let b = try PrayerTimeCalculator().schedule(for: date, at: jakarta)
        XCTAssertEqual(a.times, b.times)
    }

    func testCityDatabaseSearch() throws {
        let db = try CityDatabase()
        XCTAssertGreaterThan(db.cities.count, 80)
        let results = db.search("jakar")
        XCTAssertEqual(results.first?.name, "Jakarta")
        XCTAssertFalse(db.search("SURABAYA").isEmpty)
    }

    func testFridayReminderOnlyOnFriday() throws {
        let tz = TimeZone(identifier: "Asia/Jakarta")!
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd HH:mm"; df.timeZone = tz

        // 2026-07-17 is a Friday; Dhuhr 12:00 → reminders at 10:00 and 11:00.
        let friday = df.date(from: "2026-07-17 12:00")!
        let times = FridayReminder.times(dhuhr: friday, hoursBefore: [2, 1], timeZone: tz)
        XCTAssertEqual(times.count, 2)
        XCTAssertEqual(cal.dateComponents([.hour], from: times[0]).hour, 10)
        XCTAssertEqual(cal.dateComponents([.hour], from: times[1]).hour, 11)

        // 2026-07-16 is a Thursday → no reminders.
        let thursday = df.date(from: "2026-07-16 12:00")!
        XCTAssertTrue(FridayReminder.times(dhuhr: thursday, hoursBefore: [2, 1], timeZone: tz).isEmpty)
    }

    /// Preset default per negara: Indonesia → Kemenag (dengan ikhtiyati & round up),
    /// negara lain → MWL tanpa ikhtiyati & round nearest. Madhab dipertahankan.
    func testRegionalPreset() {
        let id = CalculationSettings.regional(country: "ID", madhab: .shafi)
        XCTAssertEqual(id.method, .kemenag)
        XCTAssertEqual(id.rounding, .up)
        XCTAssertEqual(id.adjustments.dzuhur, 3)

        let world = CalculationSettings.regional(country: "BR", madhab: .hanafi)
        XCTAssertEqual(world.method, .muslimWorldLeague)
        XCTAssertEqual(world.rounding, .nearest)
        XCTAssertEqual(world.adjustments, PrayerAdjustmentsMinutes(shubuh: 0, terbit: 0, dzuhur: 0, ashar: 0, maghrib: 0, isya: 0))
        XCTAssertEqual(world.madhab, .hanafi)  // pilihan fikih tidak diubah oleh geografi
    }

    /// Kota dunia dengan preset MWL (metode yang dipakai jadwal internasional/Google).
    /// Nilai referensi = Google, 17 Juli 2026. Google memakai madhab Ashar Hanafi.
    func testWorldCitiesMatchInternational() throws {
        struct Case { let name: String; let loc: Location; let google: [PrayerName: String] }
        let cases = [
            Case(name: "Rio de Janeiro",
                 loc: Location(name: "Rio", latitude: -22.9064, longitude: -43.1822, timeZoneIdentifier: "America/Sao_Paulo"),
                 google: [.shubuh: "05:14", .terbit: "06:33", .dzuhur: "11:59", .ashar: "15:50", .maghrib: "17:25", .isya: "18:40"]),
            Case(name: "Auckland",
                 loc: Location(name: "Auckland", latitude: -36.8485, longitude: 174.7635, timeZoneIdentifier: "Pacific/Auckland"),
                 google: [.shubuh: "05:59", .terbit: "07:30", .dzuhur: "12:27", .ashar: "15:45", .maghrib: "17:24", .isya: "18:50"]),
            Case(name: "Johannesburg",
                 loc: Location(name: "Joburg", latitude: -26.2023, longitude: 28.0436, timeZoneIdentifier: "Africa/Johannesburg"),
                 google: [.shubuh: "05:33", .terbit: "06:54", .dzuhur: "12:14", .ashar: "15:58", .maghrib: "17:34", .isya: "18:51"]),
        ]
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        var settings = CalculationSettings.regional(country: "BR", madhab: .hanafi)
        _ = settings
        for c in cases {
            df.timeZone = c.loc.timeZone
            let date = try XCTUnwrap(df.date(from: "2026-07-17"))
            let calc = PrayerTimeCalculator(settings: CalculationSettings.regional(country: c.loc.name, madhab: .hanafi))
            let schedule = try calc.schedule(for: date, at: c.loc)
            for (prayer, expected) in c.google {
                let got = minutesOfDay(schedule.time(for: prayer), tz: c.loc.timeZone)
                let diff = abs(got - minutes(expected))
                XCTAssertLessThanOrEqual(diff, 2, "\(c.name) \(prayer.rawValue): google \(expected), diff \(diff) min")
            }
        }
    }
}
