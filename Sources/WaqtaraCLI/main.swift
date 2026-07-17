import Foundation
import WaqtaraCore

// waqtara-cli — Milestone 1: cetak jadwal sholat hari ini (PRD §11).
// Usage: waqtara-cli [lat] [long] [tz] [nama-kota] [yyyy-MM-dd]
// Default: Jakarta, hari ini, metode Kemenag.

let args = CommandLine.arguments
let latitude = args.count > 1 ? Double(args[1]) ?? -6.2 : -6.2
let longitude = args.count > 2 ? Double(args[2]) ?? 106.85 : 106.85
let tz = args.count > 3 ? args[3] : "Asia/Jakarta"
let cityName = args.count > 4 ? args[4] : "Jakarta"

let location = Location(name: cityName, latitude: latitude, longitude: longitude, timeZoneIdentifier: tz)

var date = Date()
if args.count > 5 {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    df.timeZone = location.timeZone
    date = df.date(from: args[5]) ?? Date()
}

let calculator = PrayerTimeCalculator()

do {
    let schedule = try calculator.schedule(for: date, at: location)
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm"
    timeFormatter.timeZone = location.timeZone
    let dayFormatter = DateFormatter()
    dayFormatter.dateFormat = "EEEE, d MMMM yyyy"
    dayFormatter.locale = Locale(identifier: "id_ID")
    dayFormatter.timeZone = location.timeZone

    print("Waqtara — Jadwal Sholat \(location.name)")
    print(dayFormatter.string(from: date))
    print("Metode: Kemenag RI (Fajr 20°, Isya 18°) · Ikhtiyati standar Kemenag")
    print(String(repeating: "-", count: 40))
    for prayer in PrayerName.allCases {
        let label = prayer.displayName.padding(toLength: 10, withPad: " ", startingAt: 0)
        print("\(label) \(timeFormatter.string(from: schedule.time(for: prayer)))")
    }
} catch {
    print("Error: \(error.localizedDescription)")
    exit(1)
}
