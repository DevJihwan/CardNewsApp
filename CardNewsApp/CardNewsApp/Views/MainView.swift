    private func formatHistoryDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let now = Date()
        let calendar = Calendar.current
        
        // 오늘인지 확인 (수동 구현)
        let nowComponents = calendar.dateComponents([.year, .month, .day], from: now)
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        
        if nowComponents.year == dateComponents.year &&
           nowComponents.month == dateComponents.month &&
           nowComponents.day == dateComponents.day {
            // 오늘
            formatter.timeStyle = .short
            return "오늘 \(formatter.string(from: date))"
        } 
        
        // 어제인지 확인
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now) {
            let yesterdayComponents = calendar.dateComponents([.year, .month, .day], from: yesterday)
            if yesterdayComponents.year == dateComponents.year &&
               yesterdayComponents.month == dateComponents.month &&
               yesterdayComponents.day == dateComponents.day {
                // 어제
                formatter.timeStyle = .short
                return "어제 \(formatter.string(from: date))"
            }
        }
        
        // 그 외의 날짜
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }