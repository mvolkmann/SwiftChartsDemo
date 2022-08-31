import Foundation

extension Date {
    // MARK: - Static Methods

    static func from(dateComponents: DateComponents) -> Date? {
        Calendar.current.date(from: dateComponents)
    }

    static func from(year: Int, month: Int, day: Int) -> Date? {
        // swiftlint:disable identifier_name
        var dc = DateComponents()
        dc.year = year
        dc.month = month
        dc.day = day
        return Date.from(dateComponents: dc)
    }

    static func from(ms: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(ms / 1000))
    }

    static func mondayAt12AM() -> Date {
        Calendar(identifier: .iso8601)
            .date(from: Calendar(identifier: .iso8601).dateComponents(
                [.yearForWeekOfYear, .weekOfYear],
                from: Date()
            ))!
    }

    // MARK: - Computed Properties

    var dayAfter: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: self)!
    }

    var dayBefore: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: self)!
    }

    var dayOfMonth: String {
        formatted(.dateTime.day())
    }

    var dayOfWeek: String {
        formatted(.dateTime.weekday(.wide))
    }

    var dayOfWeekLetter: String {
        String(dayOfWeek.first!)
    }

    var endOfDay: Date {
        let from = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: self
        )
        let date = Calendar.current.date(from: from)!
        let seconds = 24 * 60 * 60 - 1 // seconds in a day minus 1
        return date.advanced(by: TimeInterval(seconds))
    }

    // Returns a String representation of the Date
    // showing only the hour and AM|PM.
    var h: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "ha"
        return dateFormatter.string(from: self)
    }

    var hour: Int {
        Calendar.current.component(.hour, from: self)
    }

    var isToday: Bool {
        let components: Set<Calendar.Component> = [.year, .month, .day]
        let calendar = Calendar.current
        let todayComponents = calendar.dateComponents(components, from: Date())
        let selfComponents = calendar.dateComponents(components, from: self)
        return selfComponents == todayComponents
    }

    // Returns a String representation of the Date in "M/d" format.
    var md: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d"
        return dateFormatter.string(from: self)
    }

    var milliseconds: Int {
        Int((timeIntervalSince1970 * 1000.0).rounded())
    }

    var month: String {
        formatted(.dateTime.month(.wide))
    }
    
    // Returns a String representation of the Date in "h:mm:ss a" format.
    var time: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm:ss a"
        return dateFormatter.string(from: self)
    }

    var tomorrow: Date {
        let begin = withoutTime
        return Calendar.current.date(byAdding: .day, value: 1, to: begin)!
    }

    var withoutTime: Date {
        let from = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: self
        )
        return Calendar.current.date(from: from)!
    }

    var yesterday: Date {
        let begin = withoutTime
        return Calendar.current.date(byAdding: .day, value: -1, to: begin)!
    }

    // Returns a String representation of the Date in "yyyy-mm-dd" format
    // with no time display.
    var ymd: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: self)
    }

    // Returns a String representation of the Date in "yyyy-mm-dd" format
    // including hours and AM|PM.
    var ymdh: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd h a"
        return dateFormatter.string(from: self)
    }

    // Returns a String representation of the Date in "yyyy-mm-dd" format
    // including hours, minutes, and AM|PM.
    var ymdhm: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd h:mm a"
        return dateFormatter.string(from: self)
    }

    // Returns a String representation of the Date in "yyyy-mm-dd" format
    // including hours, minutes, seconds, and AM|PM.
    var ymdhms: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd hh:mm:ss a"
        return dateFormatter.string(from: self)
    }

    // MARK: - Instance Methods

    func daysAfter(_ days: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(
            byAdding: .day,
            value: days,
            to: self
        )!
    }

    func daysBefore(_ days: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(
            byAdding: .day,
            value: -days,
            to: self
        )!
    }

    func daysBetween(date: Date) -> Int {
        let components = Calendar.current.dateComponents(
            [.day],
            from: self,
            to: date
        )
        return components.day ?? Int.max // should always have a value for day
    }

    func hoursAfter(_ hours: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(
            byAdding: .hour,
            value: hours,
            to: self
        )!
    }

    func hoursBefore(_ hours: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(
            byAdding: .hour,
            value: -hours,
            to: self
        )!
    }

    func hoursBetween(date: Date) -> Int {
        let components = Calendar.current.dateComponents(
            [.hour],
            from: self,
            to: date
        )
        return components.hour ?? Int.max // should always have a value for hour
    }

    func monthsBefore(_ months: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(
            byAdding: .month,
            value: -months,
            to: self
        )!
    }

    func secondsAfter(_ endDate: Date) -> Int {
        Int(endDate.timeIntervalSince1970 - timeIntervalSince1970)
    }

    func weeksBefore(_ weeks: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(
            byAdding: .day,
            value: -7 * weeks,
            to: self
        )!
    }
}
