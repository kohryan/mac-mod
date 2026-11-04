import Foundation
import Combine

struct PrayerLocation: Codable {
    let city: String
    let region: String
    let latitude: Double
    let longitude: Double
    var timezone: String
    var timeZone: TimeZone { TimeZone(identifier: timezone) ?? .current }

    static func decode(_ data: Data) throws -> PrayerLocation {
        struct Response: Decodable {
            struct Zone: Decodable { let id: String }
            let success: Bool
            let city: String?
            let region: String?
            let latitude: Double?
            let longitude: Double?
            let timezone: Zone?
        }
        let value = try JSONDecoder().decode(Response.self, from: data)
        guard value.success, let city = value.city, !city.trimmingCharacters(in: .whitespaces).isEmpty,
              let latitude = value.latitude, (-90...90).contains(latitude),
              let longitude = value.longitude, (-180...180).contains(longitude),
              let zone = value.timezone?.id, TimeZone(identifier: zone) != nil else { throw URLError(.cannotParseResponse) }
        return PrayerLocation(city: city, region: value.region ?? "", latitude: latitude, longitude: longitude, timezone: zone)
    }
}

struct Prayer: Codable, Identifiable {
    let id: String
    let name: String
    let time: Date
}

struct PrayerDay: Codable {
    let date: Date
    let timezone: String
    let prayers: [Prayer]

    static func decode(_ data: Data) throws -> PrayerDay {
        struct Response: Decodable {
            struct Day: Decodable {
                struct Dates: Decodable { struct Gregorian: Decodable { let date: String }; let gregorian: Gregorian }
                struct Meta: Decodable { struct Method: Decodable { let id: Int }; let timezone: String; let method: Method }
                let timings: [String: String]
                let date: Dates
                let meta: Meta
            }
            let code: Int
            let data: Day
        }
        let value = try JSONDecoder().decode(Response.self, from: data)
        guard value.code == 200, value.data.meta.method.id == 20,
              let zone = TimeZone(identifier: value.data.meta.timezone) else { throw URLError(.cannotParseResponse) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = zone
        formatter.dateFormat = "dd-MM-yyyy HH:mm"
        formatter.isLenient = false
        let day = value.data.date.gregorian.date
        guard let date = formatter.date(from: "\(day) 00:00") else { throw URLError(.cannotParseResponse) }
        let names = [("Fajr", "Subuh"), ("Dhuhr", "Dzuhur"), ("Asr", "Ashar"), ("Maghrib", "Maghrib"), ("Isha", "Isya")]
        let prayers = try names.map { key, name -> Prayer in
            guard let raw = value.data.timings[key], raw.count >= 5,
                  let time = formatter.date(from: "\(day) \(raw.prefix(5))") else { throw URLError(.cannotParseResponse) }
            return Prayer(id: "\(day)-\(key)", name: name, time: time)
        }
        guard zip(prayers, prayers.dropFirst()).allSatisfy({ $0.time < $1.time }) else { throw URLError(.cannotParseResponse) }
        return PrayerDay(date: date, timezone: zone.identifier, prayers: prayers)
    }
}

struct PrayerSnapshot: Codable {
    let location: PrayerLocation
    let fetchedAt: Date
    let days: [PrayerDay]

    func day(at now: Date) -> PrayerDay? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = location.timeZone
        return days.first { calendar.isDate($0.date, inSameDayAs: now) }
    }

    func next(after now: Date) -> Prayer? {
        days.flatMap(\.prayers).filter { $0.time > now }.min { $0.time < $1.time }
    }

    func needsRefresh(at now: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = location.timeZone
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return true }
        return now.timeIntervalSince(fetchedAt) >= 6 * 3600 || day(at: now) == nil || day(at: tomorrow) == nil
    }
}

enum PrayerAPI {
    private static func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("MacMod/0.3", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    static func fetch(now: Date = Date()) async throws -> PrayerSnapshot {
        var location = try PrayerLocation.decode(await get(URL(string: "https://ipwho.is/?fields=success,city,region,latitude,longitude,timezone")!))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = location.timeZone
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = location.timeZone
        formatter.dateFormat = "dd-MM-yyyy"
        var days: [PrayerDay] = []
        for offset in 0...1 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: now) else { throw URLError(.cannotParseResponse) }
            var url = URLComponents(string: "https://api.aladhan.com/v1/timings/\(formatter.string(from: date))")!
            url.queryItems = [URLQueryItem(name: "latitude", value: String(location.latitude)), URLQueryItem(name: "longitude", value: String(location.longitude)), URLQueryItem(name: "method", value: "20"), URLQueryItem(name: "school", value: "0")]
            let day = try PrayerDay.decode(await get(url.url!))
            guard calendar.isDate(day.date, inSameDayAs: date), day.timezone == location.timezone else { throw URLError(.cannotParseResponse) }
            days.append(day)
        }
        location.timezone = days[0].timezone
        return PrayerSnapshot(location: location, fetchedAt: now, days: days)
    }
}

final class PrayerStore: ObservableObject {
    @Published var snapshot: PrayerSnapshot?
    @Published var loading = false
    @Published var error: String?
    @Published var expanded = false
    private var retryAfter = Date.distantPast
    private var timer: Timer?

    init() {
        if let data = UserDefaults.standard.data(forKey: "prayerSnapshot.v1") {
            snapshot = try? JSONDecoder().decode(PrayerSnapshot.self, from: data)
        }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func refresh(now: Date = Date(), force: Bool = false) {
        guard !loading, force || (now >= retryAfter && (snapshot?.needsRefresh(at: now) ?? true)) else { return }
        loading = true
        retryAfter = now.addingTimeInterval(15 * 60)
        Task { @MainActor in
            do {
                let value = try await PrayerAPI.fetch(now: now)
                snapshot = value
                error = nil
                if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: "prayerSnapshot.v1") }
            } catch {
                self.error = "Jadwal belum diperbarui. Coba lagi."
            }
            loading = false
        }
    }
}
