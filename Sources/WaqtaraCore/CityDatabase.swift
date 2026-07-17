import Foundation

/// Database kota bawaan (padanan `placenames` Shollu) — PRD F5.
public struct City: Codable, Identifiable, Hashable, Sendable {
    public let name: String
    public let country: String
    public let lat: Double
    public let lon: Double
    public let alt: Double
    public let tz: String

    public var id: String { "\(name)-\(country)" }

    public var location: Location {
        Location(name: name, latitude: lat, longitude: lon, altitude: alt, timeZoneIdentifier: tz)
    }
}

public struct CityDatabase {
    public let cities: [City]

    public init() throws {
        guard let url = Bundle.module.url(forResource: "cities", withExtension: "json") else {
            throw WaqtaraError.calculationFailed
        }
        cities = try JSONDecoder().decode([City].self, from: Data(contentsOf: url))
    }

    /// Fuzzy search sederhana: prefix > substring, case/diacritic-insensitive.
    public func search(_ query: String) -> [City] {
        let q = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return cities }
        func norm(_ s: String) -> String {
            s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        }
        let prefix = cities.filter { norm($0.name).hasPrefix(q) }
        let contains = cities.filter { !norm($0.name).hasPrefix(q) && norm($0.name).contains(q) }
        return prefix + contains
    }
}

/// Tanggal Hijriyah dengan koreksi manual −2…+2 hari (padanan `HijriyahDiff` Shollu).
public enum HijriDate {
    public static func string(for date: Date, offsetDays: Int, timeZone: TimeZone, locale: Locale = Locale(identifier: "id_ID")) -> String {
        let adjusted = Calendar.current.date(byAdding: .day, value: offsetDays, to: date) ?? date
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.timeZone = timeZone
        let df = DateFormatter()
        df.calendar = cal
        df.locale = locale
        df.timeZone = timeZone
        df.dateFormat = "d MMMM yyyy"
        return df.string(from: adjusted)
    }
}
