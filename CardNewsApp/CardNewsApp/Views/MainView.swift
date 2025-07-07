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
    @State private var fileSelectionSucceeded = false
    @State private var lastSelectedFileURL: URL? // ✅ NEW: 마지막에 선택된 파일 보관
    
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
                        
                        // 📊 Status Card - Enhanced with detailed usage info
                        enhancedUsageStatusCard
                        
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
                FileUploadView(preselectedFile: selectedFileURL ?? lastSelectedFileURL) // ✅ 마지막 선택 파일도 고려
                    .onAppear {
                        print("🔍 [MainView] FileUploadView 모달 표시")
                        fileSelectionSucceeded = false // 리셋
                    }
                    .onDisappear {
                        print("🔍 [MainView] FileUploadView 모달 사라짐 - fileSelectionSucceeded: \(fileSelectionSucceeded)")
                        
                        // ✅ IMPROVED: 파일 선택 성공 후 모달이 닫혔다면 즉시 다시 열기
                        if fileSelectionSucceeded {
                            print("🔧 [MainView] 파일 선택 성공 후 의도치 않은 모달 닫힘 감지 - 즉시 재열기")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showFileUpload = true
                            }
                        } else {
                            // 정상적인 닫힘이면 파일 정보 클리어
                            lastSelectedFileURL = nil
                            selectedFileURL = nil
                        }
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
                // 모든 모달 닫힘 시 파일 정보도 클리어
                lastSelectedFileURL = nil
                selectedFileURL = nil
                fileSelectionSucceeded = false
            }
            .onReceive(NotificationCenter.default.publisher(for: .subscriptionStatusChanged)) { _ in
                // UI 자동 업데이트
            }
            .onReceive(NotificationCenter.default.publisher(for: .fileUploadSuccess)) { notification in
                // ✅ IMPROVED: 파일 선택 성공 알림 수신 시 파일 정보 보관
                print("🎉 [MainView] 파일 선택 성공 알림 수신 - 모달 보호 활성화")
                fileSelectionSucceeded = true
                
                // ✅ NEW: 선택된 파일 정보 보관
                if let fileURL = notification.object as? URL {
                    lastSelectedFileURL = fileURL
                    print("🗃️ [MainView] 선택된 파일 정보 보관: \(fileURL.lastPathComponent)")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .fileUploadUserCancelled)) { _ in
                // 사용자 취소 알림 수신
                print("🔍 [MainView] 사용자 취소 알림 수신 - 모달 보호 비활성화")
                fileSelectionSucceeded = false
                lastSelectedFileURL = nil
                selectedFileURL = nil
            }
            .onReceive(NotificationCenter.default.publisher(for: .fileUploadFirstAttemptFailed)) { _ in
                // ✅ IMPROVED: 더 엄격한 조건으로 재시도
                print("🔧 [MainView] 첫 번째 파일 업로드 시도 실패 감지")
                
                // 파일 선택이 성공하지 않았을 때만 재시도
                if !fileSelectionSucceeded {
                    print("🔄 [MainView] 실제 실패 확인 - 자동 재시도")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showFileUpload = true
                    }
                } else {
                    print("✅ [MainView] 파일 선택 성공했으므로 재시도 생략")
                }
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
    
    // MARK: - Enhanced Usage Status Card - With detailed usage information
    private var enhancedUsageStatusCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with Status - ZStack for top-right button positioning
            ZStack(alignment: .topTrailing) {
                // Main content
                HStack(spacing: 16) {
                    // Status Icon
                    ZStack {
                        Circle()
                            .fill(usageService.isSubscriptionActive ?
                                  LinearGradient(
                                    colors: [Color.green, Color.green.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                  ) :
                                  LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                  ))
                            .frame(width: 56, height: 56)
                            .shadow(color: (usageService.isSubscriptionActive ? Color.green : Color.blue).opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: usageService.isSubscriptionActive ?
                              "crown.fill" : "gift.fill")
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
                        
                        Text(getSubscriptionStatusMessage())
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
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
            
            // Detailed Usage Information
            if usageService.isSubscriptionActive {
                // Subscription Usage Details
                let stats = usageService.getUsageStats()
                VStack(alignment: .leading, spacing: 16) {
                    if usageService.currentSubscriptionTier == .basic {
                        // Basic Plan: Show progress bar for 20 monthly limit
                        usageProgressBar(
                            title: "이달 사용량",
                            current: stats.textCount,
                            total: 20,
                            color: stats.textCount >= 18 ? .orange : (stats.textCount >= 15 ? .yellow : .green),
                            subtitle: "텍스트 카드뉴스"
                        )
                    } else {
                        // Pro/Premium: Show unlimited usage with current month stats
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("무제한 이용")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.primary)
                                    
                                    Text("이번 달 사용량")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "infinity")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.green)
                            }
                            
                            // Usage Stats
                            HStack(spacing: 24) {
                                usageStatItem(
                                    icon: "text.alignleft",
                                    title: "텍스트",
                                    value: "\(stats.textCount)개",
                                    color: .blue
                                )
                                
                                usageStatItem(
                                    icon: "photo",
                                    title: "이미지",
                                    value: "\(stats.imageCount)개",
                                    color: .purple
                                )
                                
                                usageStatItem(
                                    icon: "sum",
                                    title: "총합",
                                    value: "\(stats.totalCount)개",
                                    color: .green
                                )
                            }
                        }
                    }
                    
                    // Days until reset
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("\(usageService.daysUntilReset())일 후 사용량 리셋")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // Free User: Show progress bar for 2 free attempts
                let usedCount = 2 - usageService.remainingFreeUsage
                
                usageProgressBar(
                    title: "무료 체험",
                    current: usedCount,
                    total: 2,
                    color: usageService.remainingFreeUsage > 0 ? .blue : .red,
                    subtitle: "카드뉴스 생성"
                )
                
                // Status message for free users
                if usageService.remainingFreeUsage == 0 {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.red)
                        
                        Text("무료 체험이 완료되었습니다. 계속 이용하려면 구독해주세요.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.red)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    )
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
    
    // MARK: - Usage Progress Bar Component
    private func usageProgressBar(title: String, current: Int, total: Int, color: Color, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text("\(current)/\(total)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(color)
            }
            
            // Modern Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * min(1.0, Double(current) / Double(total)), height: 12)
                        .animation(.easeInOut(duration: 0.3), value: current)
                }
            }
            .frame(height: 12)
        }
    }
    
    // MARK: - Usage Stat Item Component
    private func usageStatItem(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(color)
            }
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
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
    
    private func getSubscriptionStatusMessage() -> String {
        if usageService.isSubscriptionActive {
            switch usageService.currentSubscriptionTier {
            case .basic:
                return "월 20개 텍스트 카드뉴스 이용 가능"
            case .pro, .premium:
                return "무제한 텍스트 및 이미지 카드뉴스"
            default:
                return ""
            }
        } else {
            return "\(usageService.remainingFreeUsage)/2회 무료 체험 남음"
        }
    }
    
    private func openFileUpload() {
        guard isAppInitialized else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                openFileUpload()
            }
            return
        }
        
        // 파일 선택 상태 리셋 (새로운 업로드 시작)
        fileSelectionSucceeded = false
        lastSelectedFileURL = nil
        
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
    static let fileUploadFirstAttemptFailed = Notification.Name("fileUploadFirstAttemptFailed")
    static let fileUploadSuccess = Notification.Name("fileUploadSuccess")
    static let fileUploadUserCancelled = Notification.Name("fileUploadUserCancelled")
}

#Preview {
    MainView()
}
