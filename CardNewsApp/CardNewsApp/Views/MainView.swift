import SwiftUI

struct MainView: View {
    @StateObject private var claudeService = ClaudeAPIService()
    @ObservedObject private var usageService = UsageTrackingService.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var showFileUpload = false
    @State private var selectedFileURL: URL?
    @State private var isAppInitialized = false
    @State private var recentSummaries: [SummaryResult] = []
    @State private var showSummaryDetail = false
    @State private var selectedSummary: SummaryResult?
    @State private var showAllSummaries = false
    @State private var showPaywall = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 🎨 Clean background with subtle warmth
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 40) {
                        // 📱 Header Section - Clear Value Proposition
                        headerSection
                        
                        // 🚀 Primary Action - Large & Clear
                        primaryActionButton
                        
                        // 📊 Status Card - Essential Information
                        usageStatusCard
                        
                        // 📄 Recent Work - Card-based Organization
                        recentWorkSection
                        
                        // 💡 Benefits Section - Time-saving Focus
                        benefitsSection
                        
                        // 🔧 Development Tools (if needed)
                        if ProcessInfo.processInfo.environment["DEBUG_MODE"] != nil {
                            testButtonsSection
                        }
                        
                        // Bottom spacing
                        Color.clear.frame(height: 60)
                    }
                    .padding(.horizontal, 24) // Generous margins for readability
                    .padding(.top, 20)
                }
            }
            .navigationTitle("CardNews")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    subscriptionButton
                }
            }
            .sheet(isPresented: $showFileUpload) {
                FileUploadView(preselectedFile: selectedFileURL)
                    .onAppear {
                        print("🔍 [MainView] FileUploadView 모달 표시")
                    }
            }
            .sheet(isPresented: $showSummaryDetail) {
                if let summary = selectedSummary {
                    SummaryResultView(summaryResult: summary)
                        .onAppear {
                            print("🔍 [MainView] SummaryResultView 모달 표시")
                        }
                } else {
                    Text("선택된 요약이 없습니다")
                        .foregroundColor(.red)
                }
            }
            .sheet(isPresented: $showAllSummaries) {
                SummaryHistoryView(summaries: recentSummaries)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(triggerReason: .freeUsageExhausted)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isAppInitialized = true
                    loadRecentSummaries()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .summaryCompleted)) { _ in
                loadRecentSummaries()
            }
            .onReceive(NotificationCenter.default.publisher(for: .dismissAllModals)) { _ in
                showFileUpload = false
                showSummaryDetail = false
                showAllSummaries = false
                showPaywall = false
            }
            .onReceive(NotificationCenter.default.publisher(for: .subscriptionStatusChanged)) { _ in
                // UI 자동 업데이트
            }
            .refreshable {
                loadRecentSummaries()
            }
        }
    }
    
    // MARK: - Header Section - Clear Value Proposition
    private var headerSection: some View {
        VStack(spacing: 20) {
            // App Icon - Professional & Clear
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.2, green: 0.4, blue: 0.8), Color(red: 0.1, green: 0.3, blue: 0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                Image(systemName: "doc.text.below.ecg")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // Title & Description - Clear Hierarchy
            VStack(spacing: 12) {
                Text("CardNews")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("문서를 보기 쉬운 카드뉴스로\n빠르게 변환해드립니다")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
    }
    
    // MARK: - Primary Action Button - 72px height for optimal touch
    private var primaryActionButton: some View {
        Button(action: {
            if !usageService.canCreateTextCardNews() {
                showPaywall = true
                return
            }
            openFileUpload()
        }) {
            HStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                // Text Content
                VStack(alignment: .leading, spacing: 6) {
                    Text("파일 업로드")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("PDF나 Word 파일을 선택하세요")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(minHeight: 80) // Large touch target
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.orange, Color.red.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .orange.opacity(0.4), radius: 12, x: 0, y: 6)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Usage Status Card - Clean & Professional
    private var usageStatusCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with Status - ZStack for top-right button positioning
            ZStack(alignment: .topTrailing) {
                // Main content
                HStack(spacing: 16) {
                    // Status Icon
                    ZStack {
                        Circle()
                            .fill(usageService.isSubscriptionActive ?
                                  Color.green : Color.blue)
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: usageService.isSubscriptionActive ?
                              "checkmark.seal.fill" : "gift.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    // Status Text
                    VStack(alignment: .leading, spacing: 6) {
                        Button(action: { showPaywall = true }) {
                            Text(getSubscriptionStatusText())
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if usageService.isSubscriptionActive {
                            Text("\(usageService.currentSubscriptionTier.displayName) 플랜")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text("월 20개 카드뉴스 이용 가능")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        } else {
                            HStack(spacing: 8) {
                                Text("무료 체험:")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Text("\(usageService.remainingFreeUsage)/2회 남음")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(usageService.remainingFreeUsage > 0 ?
                                                   .blue : .red)
                            }
                        }
                    }
                    
                    Spacer()
                }
                
                // Small Upgrade Button (top-right position)
                if !usageService.isSubscriptionActive {
                    Button("업그레이드") {
                        showPaywall = true
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.orange)
                            .shadow(color: .orange.opacity(0.3), radius: 2, x: 0, y: 1)
                    )
                }
            }
            
            // Progress Bar (for free users only)
            if !usageService.isSubscriptionActive {
                VStack(alignment: .leading, spacing: 12) {
                    let usedCount = 2 - usageService.remainingFreeUsage
                    let progress = Double(usedCount) / 2.0
                    
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(usageService.remainingFreeUsage > 0 ?
                                      Color.blue : Color.red)
                                .frame(width: geometry.size.width * progress, height: 8)
                                .animation(.easeInOut(duration: 0.3), value: progress)
                        }
                    }
                    .frame(height: 8)
                    
                    // Status Text
                    if usageService.remainingFreeUsage == 0 {
                        Text("무료 체험이 완료되었습니다. 계속 이용하려면 구독해주세요.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.red)
                    } else {
                        Text("텍스트 카드뉴스 \(usedCount)/2회 사용")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Recent Work Section - Card-based Organization
    private var recentWorkSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section Header
            HStack {
                Text("최근 작업")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !recentSummaries.isEmpty {
                    Button("전체 보기") {
                        showAllSummaries = true
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                }
            }
            
            // Content
            if recentSummaries.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(recentSummaries.prefix(3), id: \.id) { summary in
                        recentWorkCard(summary)
                    }
                }
            }
        }
    }
    
    // MARK: - Recent Work Card - 72px minimum height
    private func recentWorkCard(_ summary: SummaryResult) -> some View {
        Button(action: {
            selectedSummary = summary
            showSummaryDetail = true
        }) {
            HStack(spacing: 16) {
                // Document Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.blue)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    Text(summary.originalDocument.fileName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 16) {
                        Label("\(summary.cards.count)장", systemImage: "rectangle.3.group")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.blue)
                        
                        Text(formatDate(summary.createdAt))
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    
                    // Preview text
                    if let firstCard = summary.cards.first {
                        Text(firstCard.title)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
            }
            .padding(20)
            .frame(minHeight: 80) // Large touch target
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Empty State - Encouraging & Clear
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "tray")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.blue)
            }
            
            // Text
            VStack(spacing: 8) {
                Text("아직 생성된 카드뉴스가 없습니다")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("첫 번째 문서를 업로드해서\n시간을 절약해보세요!")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - Benefits Section - Time-saving Focus
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("시간 절약 효과")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20)
            ], spacing: 20) {
                benefitCard(
                    icon: "clock.fill",
                    title: "90% 시간 단축",
                    description: "문서 읽기 시간을\n대폭 단축합니다",
                    color: .green
                )
                
                benefitCard(
                    icon: "eye.fill",
                    title: "한눈에 파악",
                    description: "핵심 내용을\n카드로 정리",
                    color: .blue
                )
                
                benefitCard(
                    icon: "rectangle.3.group.fill",
                    title: "선택 가능",
                    description: "4장, 6장, 8장\n원하는 길이로",
                    color: .orange
                )
                
                benefitCard(
                    icon: "checkmark.seal.fill",
                    title: "정확한 요약",
                    description: "AI가 핵심만\n정확히 추출",
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Benefit Card - Fixed size for consistency
    private func benefitCard(icon: String, title: String, description: String, color: Color) -> some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(color)
            }
            
            // Text - Fixed height container for consistency
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: 60) // Fixed text area height
        }
        .padding(20)
        .frame(minHeight: 140, maxHeight: 140) // Fixed card height
        .frame(maxWidth: .infinity) // Full width utilization
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - Subscription Button
    private var subscriptionButton: some View {
        Button(action: { showPaywall = true }) {
            HStack(spacing: 8) {
                Image(systemName: usageService.isSubscriptionActive ?
                      "crown.fill" : "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                
                Text(usageService.isSubscriptionActive ?
                     usageService.currentSubscriptionTier.displayName :
                     "구독")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(usageService.isSubscriptionActive ? .orange : .blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(
                        (usageService.isSubscriptionActive ? Color.orange : Color.blue)
                            .opacity(0.15)
                    )
            )
        }
    }
    
    // MARK: - Test Buttons (Development only)
    private var testButtonsSection: some View {
        VStack(spacing: 16) {
            Text("개발 도구")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Button("구독 화면") { showPaywall = true }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.purple)
                    .cornerRadius(8)
                
                Button("사용량 리셋") { usageService.resetFreeUsage() }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .cornerRadius(8)
                
                Button(usageService.isSubscriptionActive ? "구독 해제" : "구독 활성화") {
                    usageService.updateSubscription(
                        isActive: !usageService.isSubscriptionActive,
                        tier: usageService.isSubscriptionActive ? .none : .basic
                    )
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(usageService.isSubscriptionActive ? Color.red : Color.green)
                .cornerRadius(8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    // MARK: - Helper Methods
    
    private func getSubscriptionStatusText() -> String {
        if usageService.isSubscriptionActive {
            switch usageService.currentSubscriptionTier {
            case .basic: return "Basic 구독중"
            case .pro: return "Pro 구독중"
            case .premium: return "Premium 구독중"
            default: return "구독중"
            }
        } else {
            return "무료 체험"
        }
    }
    
    private func openFileUpload() {
        guard isAppInitialized else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                openFileUpload()
            }
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showFileUpload = true
        }
    }
    
    private func loadRecentSummaries() {
        recentSummaries = claudeService.loadSavedSummaries()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "방금 전"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)분 전"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)시간 전"
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Summary History View - Optimized for Mature Users

struct SummaryHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSummary: SummaryResult?
    @State private var showSummaryDetail = false
    
    let summaries: [SummaryResult]
    
    var body: some View {
        NavigationView {
            VStack {
                if summaries.isEmpty {
                    // Empty State
                    Spacer()
                    
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "tray")
                                .font(.system(size: 48, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        
                        VStack(spacing: 12) {
                            Text("저장된 카드뉴스가 없습니다")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("첫 번째 문서를 업로드해서\n시간을 절약해보세요!")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                        }
                        
                        Button("메인으로 돌아가기") {
                            dismiss()
                        }
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                } else {
                    // Summary List
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(summaries, id: \.id) { summary in
                                summaryHistoryCard(summary)
                                    .onTapGesture {
                                        selectedSummary = summary
                                        showSummaryDetail = true
                                    }
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("전체 카드뉴스")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showSummaryDetail) {
            if let summary = selectedSummary {
                SummaryResultView(summaryResult: summary)
            }
        }
    }
    
    private func summaryHistoryCard(_ summary: SummaryResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.originalDocument.fileName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        Label("\(summary.cards.count)장", systemImage: "rectangle.3.group")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                        
                        Text(formatHistoryDate(summary.createdAt))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text("\(summary.tokensUsed) 토큰")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Preview
            if let firstCard = summary.cards.first {
                VStack(alignment: .leading, spacing: 6) {
                    Text(firstCard.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(firstCard.content)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }
        }
        .padding(20)
        .frame(minHeight: 80)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private func formatHistoryDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.timeStyle = .short
            return "오늘 \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            formatter.timeStyle = .short
            return "어제 \(formatter.string(from: date))"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let dismissAllModals = Notification.Name("dismissAllModals")
}

#Preview {
    MainView()
}
