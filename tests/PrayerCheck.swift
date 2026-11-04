import Foundation

@main struct PrayerChecks {
    static func main() async throws {
        let locationData = Data(#"{"success":true,"city":"Jakarta","region":"Jakarta","latitude":-6.2,"longitude":106.8,"timezone":{"id":"Asia/Jakarta"}}"#.utf8)
        let location = try PrayerLocation.decode(locationData)
        let response = #"{"code":200,"data":{"timings":{"Fajr":"04:05","Dhuhr":"11:36","Asr":"14:55","Maghrib":"17:47","Isha":"18:59"},"date":{"gregorian":{"date":"05-11-2026"}},"meta":{"timezone":"Asia/Jakarta","method":{"id":20}}}}"#
        let today = try PrayerDay.decode(Data(response.utf8))
        let tomorrow = try PrayerDay.decode(Data(response.replacingOccurrences(of: "05-11-2026", with: "06-11-2026").utf8))
        assert(today.prayers.count == 5 && today.prayers.first?.name == "Subuh")
        assert(today.prayers[0].time.timeIntervalSince(today.date) == 4 * 3600 + 5 * 60)
        let noon = today.date.addingTimeInterval(12 * 3600)
        let snapshot = PrayerSnapshot(location: location, fetchedAt: noon, days: [today, tomorrow])
        assert(snapshot.next(after: noon)?.name == "Ashar")
        assert(snapshot.next(after: today.prayers.last!.time)?.id == tomorrow.prayers.first?.id)
        assert(snapshot.day(at: tomorrow.date.addingTimeInterval(60))?.date == tomorrow.date)
        assert(!snapshot.needsRefresh(at: noon))
        assert(snapshot.needsRefresh(at: noon.addingTimeInterval(6 * 3600)))
        assert(snapshot.needsRefresh(at: tomorrow.date))
        assert(snapshot.day(at: tomorrow.date.addingTimeInterval(2 * 86400)) == nil)
        assert(snapshot.next(after: tomorrow.date.addingTimeInterval(2 * 86400)) == nil)
        for invalid in [response.replacingOccurrences(of: "04:05", with: "NaN"), response.replacingOccurrences(of: "04:05", with: "25:99"), response.replacingOccurrences(of: "\"id\":20", with: "\"id\":2")] {
            do { _ = try PrayerDay.decode(Data(invalid.utf8)); fatalError("Invalid API data accepted") }
            catch { }
        }
        do { _ = try PrayerLocation.decode(Data(#"{"success":false}"#.utf8)); fatalError("Failed geolocation accepted") }
        catch { }
        do {
            _ = try PrayerLocation.decode(Data(String(decoding: locationData, as: UTF8.self).replacingOccurrences(of: "-6.2", with: "-100").utf8))
            fatalError("Invalid latitude accepted")
        } catch { }
        let restored = try JSONDecoder().decode(PrayerSnapshot.self, from: JSONEncoder().encode(snapshot))
        assert(restored.next(after: noon)?.time == snapshot.next(after: noon)?.time)
        print("Prayer parsing, timezone, midnight rollover, cache expiry, invalid responses: PASS")
        if CommandLine.arguments.contains("--live") {
            let live = try await PrayerAPI.fetch()
            assert(live.days.count == 2 && live.days.allSatisfy { $0.prayers.count == 5 })
            assert(live.day(at: Date()) != nil && live.next(after: Date()) != nil)
            print("Live IP geolocation + AlAdhan method 20 (today/tomorrow): PASS")
        }
    }
}
