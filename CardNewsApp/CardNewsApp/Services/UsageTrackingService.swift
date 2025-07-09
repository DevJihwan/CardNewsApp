import Foundation

/// 사용량 추적 및 구독 제한 관리 서비스 (Singleton)
class UsageTrackingService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = UsageTrackingService()
    
    // MARK: - Published Properties
    @Published var remainingFreeUsage: Int = 0
    @Published var isSubscriptionActive: Bool = false
    @Published var currentSubscriptionTier: SubscriptionTier = .none
    @Published var monthlyUsage: UsageStats = UsageStats()
    
    // MARK: - Constants
    private let freeUsageLimit = 2
    private let userDefaults = UserDefaults.standard
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let freeUsageCount = "freeUsageCount"
        static let firstUseDate = "firstUseDate"
        static let subscriptionStatus = "subscriptionStatus"
        static let subscriptionTier = "subscriptionTier"
        static let monthlyTextUsage = "monthlyTextUsage"
        static let monthlyImageUsage = "monthlyImageUsage"
        static let monthlyWebtoonUsage = "monthlyWebtoonUsage"
        static let lastResetDate = "lastResetDate"
    }
    
    // MARK: - Initialization
    private init() {
        loadUsageData()
        checkMonthlyReset()
        print("🔍 [UsageTrackingService] Singleton 초기화 완료")
        print("📊 [UsageTrackingService] 남은 무료 사용: \(remainingFreeUsage)회")
        print("💎 [UsageTrackingService] 구독 상태: \(isSubscriptionActive ? "활성" : "비활성")")
    }
    
    // MARK: - Public Methods
    
    /// 무료 카드뉴스 생성 가능 여부 확인
    func canCreateFreeCardNews() -> Bool {
        if isSubscriptionActive {
            return true // 구독자는 제한 없음
        }
        return remainingFreeUsage > 0
    }
    
    /// 텍스트 카드뉴스 생성 가능 여부 확인
    func canCreateTextCardNews() -> Bool {
        if !isSubscriptionActive {
            return canCreateFreeCardNews()
        }
        
        switch currentSubscriptionTier {
        case .none:
            return canCreateFreeCardNews()
        case .basic:
            return monthlyUsage.textCount < 20
        case .webtoon:
            return false // 웹툰 전용 플랜은 텍스트 카드뉴스 생성 불가
        case .pro:
            return monthlyUsage.textCount < 20
        case .premium:
            return true // 무제한
        }
    }
    
    /// 웹툰 카드뉴스 생성 가능 여부 확인
    func canCreateWebtoonCardNews() -> Bool {
        if !isSubscriptionActive {
            return false // 무료 사용자는 웹툰 생성 불가
        }
        
        switch currentSubscriptionTier {
        case .none, .basic:
            return false
        case .webtoon:
            return monthlyUsage.webtoonCount < 10
        case .pro:
            return monthlyUsage.webtoonCount < 20
        case .premium:
            return true // 무제한
        }
    }
    
    /// 이미지 카드뉴스 생성 가능 여부 확인
    func canCreateImageCardNews() -> Bool {
        if !isSubscriptionActive {
            return false // 무료 사용자는 이미지 생성 불가
        }
        
        switch currentSubscriptionTier {
        case .none, .basic, .webtoon, .pro:
            return false // Premium만 이미지 생성 가능
        case .premium:
            return true // 무제한 (Fair Use Policy 적용)
        }
    }
    
    /// 텍스트 카드뉴스 사용량 기록
    func recordTextCardNewsUsage() {
        print("📊 [UsageTrackingService] 텍스트 카드뉴스 사용량 기록")
        
        if !isSubscriptionActive {
            // 무료 사용자
            let currentUsage = userDefaults.integer(forKey: Keys.freeUsageCount)
            let newUsage = currentUsage + 1
            userDefaults.set(newUsage, forKey: Keys.freeUsageCount)
            
            // 첫 사용 날짜 기록
            if currentUsage == 0 {
                userDefaults.set(Date(), forKey: Keys.firstUseDate)
            }
            
            remainingFreeUsage = max(0, freeUsageLimit - newUsage)
            print("🆓 [UsageTrackingService] 무료 사용량: \(newUsage)/\(freeUsageLimit), 남은 횟수: \(remainingFreeUsage)")
        } else {
            // 구독자의 경우만 월간 사용량 기록
            monthlyUsage.textCount += 1
            saveMonthlyUsage()
            print("📈 [UsageTrackingService] 월간 텍스트 사용량: \(monthlyUsage.textCount)")
        }
        
        // UI 업데이트 알림
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    /// 웹툰 카드뉴스 사용량 기록
    func recordWebtoonCardNewsUsage() {
        print("📊 [UsageTrackingService] 웹툰 카드뉴스 사용량 기록")
        
        // 웹툰은 구독자만 가능하므로 월간 사용량만 기록
        monthlyUsage.webtoonCount += 1
        saveMonthlyUsage()
        
        print("📈 [UsageTrackingService] 월간 웹툰 사용량: \(monthlyUsage.webtoonCount)")
        
        // UI 업데이트 알림
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    /// 이미지 카드뉴스 사용량 기록
    func recordImageCardNewsUsage() {
        print("📊 [UsageTrackingService] 이미지 카드뉴스 사용량 기록")
        
        // 이미지는 구독자만 가능하므로 월간 사용량만 기록
        monthlyUsage.imageCount += 1
        saveMonthlyUsage()
        
        print("📈 [UsageTrackingService] 월간 이미지 사용량: \(monthlyUsage.imageCount)")
        
        // UI 업데이트 알림
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    /// 구독 상태 업데이트
    func updateSubscription(isActive: Bool, tier: SubscriptionTier) {
        print("💎 [UsageTrackingService] 구독 상태 업데이트: \(isActive ? "활성" : "비활성"), 티어: \(tier)")
        
        let wasInactive = !isSubscriptionActive
        
        isSubscriptionActive = isActive
        currentSubscriptionTier = tier
        
        userDefaults.set(isActive, forKey: Keys.subscriptionStatus)
        userDefaults.set(tier.rawValue, forKey: Keys.subscriptionTier)
        
        // 구독이 새로 활성화된 경우 월간 사용량 리셋
        if isActive && wasInactive {
            print("🔄 [UsageTrackingService] 구독 활성화로 인한 월간 사용량 리셋")
            resetMonthlyUsage()
        }
        
        objectWillChange.send()
    }
    
    /// 사용량 통계 조회
    func getUsageStats() -> UsageStats {
        return monthlyUsage
    }
    
    /// 다음 리셋까지 남은 일수
    func daysUntilReset() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) ?? now
        let startOfNextMonth = calendar.dateInterval(of: .month, for: nextMonth)?.start ?? now
        let daysRemaining = calendar.dateComponents([.day], from: now, to: startOfNextMonth).day ?? 0
        return max(0, daysRemaining)
    }
    
    /// 무료 사용량 리셋 (테스트용)
    func resetFreeUsage() {
        print("🔄 [UsageTrackingService] 무료 사용량 리셋")
        userDefaults.removeObject(forKey: Keys.freeUsageCount)
        userDefaults.removeObject(forKey: Keys.firstUseDate)
        remainingFreeUsage = freeUsageLimit
        objectWillChange.send()
    }
    
    /// 월간 사용량 리셋
    private func resetMonthlyUsage() {
        print("🔄 [UsageTrackingService] 월간 사용량 리셋")
        monthlyUsage = UsageStats()
        saveMonthlyUsage()
        userDefaults.set(Date(), forKey: Keys.lastResetDate)
        objectWillChange.send()
    }
    
    // MARK: - Private Methods
    
    private func loadUsageData() {
        print("📥 [UsageTrackingService] 사용량 데이터 로드")
        
        // 무료 사용량 로드
        let freeUsage = userDefaults.integer(forKey: Keys.freeUsageCount)
        remainingFreeUsage = max(0, freeUsageLimit - freeUsage)
        
        // 구독 상태 로드
        isSubscriptionActive = userDefaults.bool(forKey: Keys.subscriptionStatus)
        let tierRawValue = userDefaults.string(forKey: Keys.subscriptionTier) ?? SubscriptionTier.none.rawValue
        currentSubscriptionTier = SubscriptionTier(rawValue: tierRawValue) ?? .none
        
        // 월간 사용량 로드
        monthlyUsage.textCount = userDefaults.integer(forKey: Keys.monthlyTextUsage)
        monthlyUsage.imageCount = userDefaults.integer(forKey: Keys.monthlyImageUsage)
        monthlyUsage.webtoonCount = userDefaults.integer(forKey: Keys.monthlyWebtoonUsage)
    }
    
    private func saveMonthlyUsage() {
        userDefaults.set(monthlyUsage.textCount, forKey: Keys.monthlyTextUsage)
        userDefaults.set(monthlyUsage.imageCount, forKey: Keys.monthlyImageUsage)
        userDefaults.set(monthlyUsage.webtoonCount, forKey: Keys.monthlyWebtoonUsage)
    }
    
    private func checkMonthlyReset() {
        let lastResetDate = userDefaults.object(forKey: Keys.lastResetDate) as? Date ?? Date.distantPast
        let calendar = Calendar.current
        let now = Date()
        
        // 월이 바뀌었는지 확인
        if !calendar.isDate(lastResetDate, equalTo: now, toGranularity: .month) {
            print("🔄 [UsageTrackingService] 월간 사용량 리셋")
            monthlyUsage = UsageStats()
            saveMonthlyUsage()
            userDefaults.set(now, forKey: Keys.lastResetDate)
        }
    }
}

// MARK: - Supporting Types

/// 구독 티어
enum SubscriptionTier: String, CaseIterable {
    case none = "none"
    case basic = "basic"
    case webtoon = "webtoon"
    case pro = "pro"
    case premium = "premium"
    
    var displayName: String {
        switch self {
        case .none: return "무료"
        case .basic: return "Basic"
        case .webtoon: return "웹툰"
        case .pro: return "Pro"
        case .premium: return "Premium"
        }
    }
    
    var monthlyPrice: String {
        switch self {
        case .none: return "무료"
        case .basic: return "$4.99"
        case .webtoon: return "$7.99"
        case .pro: return "$12.99"
        case .premium: return "$19.99"
        }
    }
    
    var textLimit: String {
        switch self {
        case .none: return "2개 (무료 체험)"
        case .basic: return "20개/월"
        case .webtoon: return "없음"
        case .pro: return "20개/월"
        case .premium: return "무제한"
        }
    }
    
    var webtoonLimit: String {
        switch self {
        case .none, .basic: return "없음"
        case .webtoon: return "10개/월"
        case .pro: return "20개/월"
        case .premium: return "무제한"
        }
    }
    
    var imageLimit: String {
        switch self {
        case .none, .basic, .webtoon, .pro: return "없음"
        case .premium: return "무제한*"
        }
    }
    
    var features: [String] {
        switch self {
        case .none:
            return [
                "2회 무료 체험",
                "텍스트 카드뉴스만",
                "기본 스타일 제공"
            ]
        case .basic:
            return [
                "월 20개 텍스트 카드뉴스",
                "모든 스타일 지원",
                "무제한 히스토리",
                "우선 처리"
            ]
        case .webtoon:
            return [
                "월 10개 웹툰 카드뉴스",
                "웹툰 전용 스타일",
                "고급 AI 웹툰 생성",
                "무제한 히스토리",
                "우선 처리"
            ]
        case .pro:
            return [
                "월 20개 텍스트 카드뉴스",
                "월 20개 웹툰 카드뉴스",
                "모든 스타일 지원",
                "고급 AI 생성",
                "PDF 내보내기",
                "우선 지원"
            ]
        case .premium:
            return [
                "모든 Pro 기능",
                "무제한 텍스트 카드뉴스",
                "무제한 웹툰 카드뉴스",
                "무제한 이미지 카드뉴스*",
                "프리미엄 AI 모델",
                "고해상도 이미지",
                "24/7 전담 지원",
                "베타 기능 우선 액세스"
            ]
        }
    }
}

/// 사용량 통계
struct UsageStats {
    var textCount: Int = 0
    var webtoonCount: Int = 0
    var imageCount: Int = 0
    
    var totalCount: Int {
        return textCount + webtoonCount + imageCount
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let usageLimitReached = Notification.Name("usageLimitReached")
    static let subscriptionStatusChanged = Notification.Name("subscriptionStatusChanged")
}
