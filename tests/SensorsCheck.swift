import Foundation

@main struct Checks {
    static func main() {
        let before = CPUTicks(values: [100, 100, 700, 100])
        let after = CPUTicks(values: [150, 125, 725, 100])
        assert(abs(after.usage(since: before)! - 0.75) < 0.00001)
        assert(before.usage(since: before) == nil)
        var focus = FocusSession()
        let start = Date(timeIntervalSince1970: 100)
        focus.toggle(at: start)
        assert(focus.seconds(at: start.addingTimeInterval(30)) == 1470)
        focus.toggle(at: start.addingTimeInterval(30))
        assert(focus.isPaused)
        assert(focus.seconds(at: start.addingTimeInterval(90)) == 1470)
        focus.toggle(at: start.addingTimeInterval(90))
        assert(!focus.isPaused)
        assert(focus.tick(at: start.addingTimeInterval(1560)))
        assert(focus.complete && focus.seconds(at: start.addingTimeInterval(1560)) == 0)
        let reader = MetricsReader()
        assert(reader.cpu() != nil)
        if let memory = reader.memory() { assert(memory.used > 0 && memory.used <= memory.total) }
        if let battery = reader.battery() { assert((0...1).contains(battery.percent)) }
        let october = cockpitCalendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        let cells = calendarCells(for: october)
        assert(cells.count == 42 && cells.compactMap { $0 }.count == 31)
        assert(cells.prefix(4).allSatisfy { $0 == nil } && cells[4] == october)
        let february = cockpitCalendar.date(from: DateComponents(year: 2024, month: 2, day: 1))!
        assert(calendarCells(for: february).compactMap { $0 }.count == 29)
        let november = cockpitCalendar.date(byAdding: .month, value: 1, to: october)!
        assert(calendarCells(for: november).first! == november)
        print("CPU delta, focus controls, native sensors, calendar layout and leap year: PASS")
    }
}
