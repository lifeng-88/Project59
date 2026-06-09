import Foundation

enum FocusStreakCalculator {
    /// 根据上次专注日期更新连续天数（按自然日，每日首次完成番茄钟计一次）
    static func updatedStreak(
        currentStreak: Int,
        lastActivityDate: Date?,
        on date: Date = Date(),
        calendar: Calendar = .current
    ) -> (streak: Int, lastActivityDate: Date) {
        let today = calendar.startOfDay(for: date)

        guard let last = lastActivityDate else {
            return (1, today)
        }

        let lastDay = calendar.startOfDay(for: last)
        if lastDay == today {
            return (currentStreak, today)
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           lastDay == calendar.startOfDay(for: yesterday) {
            return (currentStreak + 1, today)
        }

        return (1, today)
    }
}
