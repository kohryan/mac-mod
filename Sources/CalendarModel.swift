import Foundation

var cockpitCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
    calendar.firstWeekday = 1
    return calendar
}

func calendarCells(for month: Date, calendar: Calendar = cockpitCalendar) -> [Date?] {
    guard let start = calendar.dateInterval(of: .month, for: month)?.start,
          let days = calendar.range(of: .day, in: .month, for: month) else { return [] }
    let padding = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
    return (0..<42).map { cell in
        let day = cell - padding
        return day >= 0 && day < days.count ? calendar.date(byAdding: .day, value: day, to: start) : nil
    }
}
