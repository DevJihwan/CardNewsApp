import SwiftUI

struct SummaryConfigView: View {
    @StateObject private var claudeService = ClaudeAPIService()
    @ObservedObject private var usageService = UsageTrackingService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var summaryConfig = SummaryConfig(
        cardCount: .four,
        outputStyle: .text,
        language: .korean,
        tone: .friendly
    )
    @State private var isGeneratingSummary = false
    @State private var showSummaryResult = false
    @State private var generatedSummary: SummaryResult?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showPaywall = false
    @State private var paywallTrigger: PaywallTrigger = .freeUsageExhausted
    @State private var refreshTrigger = false // UI 강제 새로고침용
    
    let processedDocument: ProcessedDocument
    
    init(processedDocument: ProcessedDocument) {
        self.processedDocument = processedDocument
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 🎨 Modern Background with System Grouping
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // 📊 Usage Status - System-aligned Design
                        usageStatusSection
                        
                        // 📄 Document Info - Clean & System-styled
                        documentInfoSection
                        
                        // ⚙️ Configuration Sections - Modern Cards
                        configurationSections
                        
                        // 🚀 Generate Button - Eye-catching CTA
                        generateButton
                        
                        // Bottom spacing
                        Color.clear.frame(height: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("요약 설정")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                    .foregroundColor(.primary) // 동적 색상 적용
                }
                
                if usageService.isSubscriptionActive {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        subscriptionBadge
                    }
                }
            }
            .alert("오류", isPresented: $showError) {
                Button("확인") {
                    showError = false
                }
            } message: {
                Text(errorMessage ?? "알 수 없는 오류가 발생했습니다.")
            }
            .sheet(isPresented: $showSummaryResult) {
                if let summary = generatedSummary {
                    SummaryResultView(summaryResult: summary)
                        .onDisappear {
                            NotificationCenter.default.post(name: .summaryCompleted, object: nil)
                            dismiss()
                        }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(triggerReason: paywallTrigger)
                    .onDisappear {
                        refreshTrigger.toggle()
                    }
            }
            .onAppear {
                setupClaudeAPI()
            }
            .onReceive(NotificationCenter.default.publisher(for: .subscriptionStatusChanged)) { _ in
                print("💎 [SummaryConfigView] 구독 상태 변경 알림 수신")
                refreshTrigger.toggle()
            }
            .onChange(of: refreshTrigger) { _, _ in
                // refreshTrigger가 변경될 때마다 View가 다시 렌더링됨
            }
        }
    }
    
    // MARK: - Subscription Badge
    private var subscriptionBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 14, weight: .semibold))
            Text(usageService.currentSubscriptionTier.displayName)
                .font(.system(size: 14, weight: .bold))
        }
        .foregroundColor(.white) // 배지 디자인 유지
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(AppGradients.buttonAccent)
                .shadow(color: AppColors.accent.opacity(0.3), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Usage Status Section - System-aligned Design
    private var usageStatusSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with Status Icon & Upgrade Button
            HStack {
                // Status Icon
                ZStack {
                    Circle()
                        .fill(usageService.isSubscriptionActive ? AppGradients.buttonAccent : AppGradients.buttonSuccess)
                        .frame(width: 56, height: 56)
                        .shadow(color: (usageService.isSubscriptionActive ? AppColors.accent : AppColors.success).opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: usageService.isSubscriptionActive ? "crown.fill" : "gift.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                // Status Text
                VStack(alignment: .leading, spacing: 6) {
                    Button(action: { showPaywall = true }) {
                        Text(getSubscriptionStatusText())
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text(getSubscriptionStatusMessage())
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Upgrade Button (top-right position)
                if !usageService.isSubscriptionActive {
                    Button("업그레이드") {
                        paywallTrigger = .upgradePrompt
                        showPaywall = true
                    }
                    .premiumButton(gradient: AppGradients.buttonAccent)
                }
            }
            
            // Usage Information
            if usageService.isSubscriptionActive {
                let stats = usageService.getUsageStats()
                VStack(alignment: .leading, spacing: 12) {
                    if usageService.currentSubscriptionTier == .basic {
                        usageProgressBar(
                            title: "월 사용량",
                            current: stats.textCount,
                            total: 20,
                            color: AppColors.accent
                        )
                    } else {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("무제한 이용")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text("이번 달: 텍스트 \(stats.textCount)개, 이미지 \(stats.imageCount)개")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "infinity")
                                .font(.title2)
                                .foregroundColor(AppColors.success)
                        }
                    }
                }
            } else {
                usageProgressBar(
                    title: "무료 체험",
                    current: 2 - usageService.remainingFreeUsage,
                    total: 2,
                    color: usageService.remainingFreeUsage > 0 ? AppColors.success : AppColors.error
                )
                
                if usageService.remainingFreeUsage == 0 {
                    Text("무료 체험이 완료되었습니다. 계속 이용하려면 구독해주세요.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.top, 8)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Usage Progress Bar
    private func usageProgressBar(title: String, current: Int, total: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(current)/\(total)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (Double(current) / Double(total)), height: 12)
                        .animation(.easeInOut(duration: 0.3), value: current)
                }
            }
            .frame(height: 12)
        }
    }
    
    // MARK: - Document Info Section - Clean Design
    private var documentInfoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppColors.primaryStart.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("문서 정보")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("분석할 문서의 세부 정보입니다")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                documentInfoRow(
                    icon: "doc.fill",
                    title: "파일명",
                    value: processedDocument.originalDocument.fileName,
                    color: AppColors.primaryStart
                )
                
                Divider()
                    .opacity(0.5)
                
                HStack(spacing: 24) {
                    documentInfoRow(
                        icon: "textformat.123",
                        title: "단어 수",
                        value: "\(processedDocument.wordCount)개",
                        color: AppColors.success
                    )
                    
                    documentInfoRow(
                        icon: "character.textbox",
                        title: "문자 수",
                        value: "\(processedDocument.characterCount)자",
                        color: AppColors.accent
                    )
                }
                
                Divider()
                    .opacity(0.5)
                
                documentInfoRow(
                    icon: "clock.fill",
                    title: "처리 시간",
                    value: formatDate(processedDocument.processedAt),
                    color: AppColors.primaryEnd
                )
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
    }
    
    // MARK: - Document Info Row
    private func documentInfoRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Configuration Sections
    private var configurationSections: some View {
        VStack(spacing: 24) {
            cardCountSection
            outputStyleSection
            languageSection
            toneSection
        }
    }
    
    // MARK: - Card Count Section - Modern Selection
    private var cardCountSection: some View {
        configSection(
            title: "카드 수",
            subtitle: "생성할 카드뉴스의 장 수를 선택하세요",
            icon: "rectangle.3.group.fill",
            iconColor: AppColors.primaryStart
        ) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(SummaryConfig.CardCount.allCases, id: \.self) { count in
                    selectionCard(
                        title: "\(count.rawValue)",
                        subtitle: count.displayName,
                        isSelected: summaryConfig.cardCount == count
                    ) {
                        summaryConfig = SummaryConfig(
                            cardCount: count,
                            outputStyle: summaryConfig.outputStyle,
                            language: summaryConfig.language,
                            tone: summaryConfig.tone
                        )
                        print("🔍 [SummaryConfigView] 카드 수 선택: \(count.displayName)")
                    }
                }
            }
        }
    }
    
    // MARK: - Output Style Section
    private var outputStyleSection: some View {
        configSection(
            title: "출력 스타일",
            subtitle: "카드뉴스의 시각적 스타일을 선택하세요",
            icon: "paintbrush.fill",
            iconColor: AppColors.accent
        ) {
            VStack(spacing: 12) {
                ForEach(SummaryConfig.OutputStyle.allCases, id: \.self) { style in
                    let isEnabled = isStyleEnabled(style)
                    
                    styleOptionCard(
                        style: style,
                        isEnabled: isEnabled,
                        isSelected: summaryConfig.outputStyle == style && isEnabled
                    ) {
                        if !isEnabled {
                            if style == .image {
                                paywallTrigger = .imageGenerationRequested
                                showPaywall = true
                            }
                            return
                        }
                        
                        summaryConfig = SummaryConfig(
                            cardCount: summaryConfig.cardCount,
                            outputStyle: style,
                            language: summaryConfig.language,
                            tone: summaryConfig.tone
                        )
                        print("🔍 [SummaryConfigView] 출력 스타일 선택: \(style.displayName)")
                    }
                }
            }
        }
    }
    
    // MARK: - Language Section
    private var languageSection: some View {
        configSection(
            title: "언어",
            subtitle: "카드뉴스에 사용할 언어를 선택하세요",
            icon: "globe",
            iconColor: AppColors.success
        ) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(SummaryConfig.SummaryLanguage.allCases, id: \.self) { language in
                    selectionCard(
                        title: language.displayName,
                        subtitle: nil,
                        isSelected: summaryConfig.language == language
                    ) {
                        summaryConfig = SummaryConfig(
                            cardCount: summaryConfig.cardCount,
                            outputStyle: summaryConfig.outputStyle,
                            language: language,
                            tone: summaryConfig.tone
                        )
                        print("🔍 [SummaryConfigView] 언어 선택: \(language.displayName)")
                    }
                }
            }
        }
    }
    
    // MARK: - Tone Section
    private var toneSection: some View {
        configSection(
            title: "톤",
            subtitle: "카드뉴스의 어조와 분위기를 선택하세요",
            icon: "waveform",
            iconColor: AppColors.primaryEnd
        ) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(SummaryConfig.SummaryTone.allCases, id: \.self) { tone in
                    selectionCard(
                        title: tone.displayName,
                        subtitle: nil,
                        isSelected: summaryConfig.tone == tone
                    ) {
                        summaryConfig = SummaryConfig(
                            cardCount: summaryConfig.cardCount,
                            outputStyle: summaryConfig.outputStyle,
                            language: summaryConfig.language,
                            tone: tone
                        )
                        print("🔍 [SummaryConfigView] 톤 선택: \(tone.displayName)")
                    }
                }
            }
        }
    }
    
    // MARK: - Config Section Wrapper
    private func configSection<Content: View>(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            content()
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Selection Card
    private func selectionCard(
        title: String,
        subtitle: String?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isSelected ? .white : .primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                }
            }
            .frame(minHeight: 72)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppGradients.primary)
                            .shadow(
                                color: AppColors.primaryStart.opacity(0.3),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGroupedBackground))
                    }
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    
    // MARK: - Style Option Card
    private func styleOptionCard(
        style: SummaryConfig.OutputStyle,
        isEnabled: Bool,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Text(style.displayName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(isEnabled ? .primary : .secondary)
                        
                        if !isEnabled {
                            Text(getStyleRequirement(style))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(getStyleRequirementColor(style))
                                )
                        }
                        
                        Spacer()
                    }
                    
                    Text(style.description)
                        .font(.system(size: 15))
                        .foregroundColor(isEnabled ? .secondary : .secondary.opacity(0.6))
                        .multilineTextAlignment(.leading)
                }
                
                ZStack {
                    Circle()
                        .fill(isSelected && isEnabled ? AppColors.primaryStart : Color(.systemGray4))
                        .frame(width: 24, height: 24)
                    
                    if isSelected && isEnabled {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected && isEnabled ?
                        Color(AppColors.primaryStart.opacity(0.1)) :
                        Color(.systemGroupedBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected && isEnabled ?
                                AppColors.primaryStart.opacity(0.3) :
                                Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .opacity(isEnabled ? 1.0 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
    }
    
    // MARK: - Generate Button - Eye-catching CTA
    private var generateButton: some View {
        VStack(spacing: 20) {
            Button(action: generateSummary) {
                HStack(spacing: 16) {
                    if isGeneratingSummary {
                        ProgressView()
                            .scaleEffect(0.9)
                            .foregroundColor(.white)
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    VStack(spacing: 4) {
                        Text(isGeneratingSummary ? "AI가 카드뉴스를 생성하고 있습니다..." : "카드뉴스 생성하기")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        if !isGeneratingSummary {
                            Text("고품질 AI 요약으로 시간을 절약하세요")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    
                    Spacer()
                    
                    if !isGeneratingSummary {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(minHeight: 80)
                .background(
                    Group {
                        if canGenerate() {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(AppGradients.primary)
                                .shadow(
                                    color: AppColors.primaryStart.opacity(0.4),
                                    radius: 16,
                                    x: 0,
                                    y: 8
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemGray5))
                        }
                    }
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isGeneratingSummary || !canGenerate())
            .scaleEffect(isGeneratingSummary ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isGeneratingSummary)
            
            if !canGenerate() && !isGeneratingSummary {
                usageLimitMessage
            } else if isGeneratingSummary {
                generationProgressInfo
            }
        }
    }
    
    // MARK: - Usage Limit Message
    private var usageLimitMessage: some View {
        VStack(spacing: 16) {
            if summaryConfig.outputStyle == .image && !usageService.canCreateImageCardNews() {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppColors.warning)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("이미지 카드뉴스는 Pro 플랜 이상에서 이용 가능합니다")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("텍스트 카드뉴스로 먼저 체험해보세요")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.warning.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.warning.opacity(0.3), lineWidth: 1)
                        )
                )
                
                Button("Pro 플랜 살펴보기") {
                    paywallTrigger = .imageGenerationRequested
                    showPaywall = true
                }
                .premiumButton(gradient: AppGradients.buttonAccent)
                
            } else if !usageService.canCreateTextCardNews() {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(AppColors.error)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("무료 사용량을 모두 소진하셨습니다")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("계속 이용하려면 Basic 플랜을 구독해주세요")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.error.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.error.opacity(0.3), lineWidth: 1)
                        )
                )
                
                Button("Basic 플랜 구독하기") {
                    paywallTrigger = .freeUsageExhausted
                    showPaywall = true
                }
                .premiumButton(gradient: AppGradients.buttonSuccess)
            }
        }
    }
    
    // MARK: - Generation Progress Info
    private var generationProgressInfo: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ForEach(0..<3) { step in
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(step == 0 ? AppColors.primaryStart : Color(.systemGray4))
                                .frame(width: 8, height: 8)
                            
                            if step == 0 {
                                Circle()
                                    .stroke(AppColors.primaryStart, lineWidth: 2)
                                    .frame(width: 16, height: 16)
                                    .scaleEffect(1.0)
                                    .animation(.easeInOut(duration: 1.0).repeatForever(), value: isGeneratingSummary)
                            }
                        }
                        
                        if step < 2 {
                            Rectangle()
                                .fill(Color(.systemGray4))
                                .frame(width: 20, height: 2)
                        }
                    }
                }
            }
            
            VStack(spacing: 8) {
                Text("AI가 문서를 분석하여 \(summaryConfig.cardCount.displayName) 카드뉴스를 생성하고 있습니다")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("설정: \(summaryConfig.outputStyle.displayName) • \(summaryConfig.language.displayName) • \(summaryConfig.tone.displayName)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("평균 30-60초 소요됩니다")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
                )
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
            case .basic: return "월 20개 텍스트 카드뉴스 이용 가능"
            case .pro, .premium: return "무제한 텍스트 및 이미지 카드뉴스"
            default: return ""
            }
        } else {
            return "\(usageService.remainingFreeUsage)/2회 무료 체험 남음"
        }
    }
    
    private func isStyleEnabled(_ style: SummaryConfig.OutputStyle) -> Bool {
        switch style {
        case .text: return true
        case .webtoon: return false
        case .image: return false
        }
    }
    
    private func getStyleRequirement(_ style: SummaryConfig.OutputStyle) -> String {
        switch style {
        case .webtoon: return "준비 중"
        case .image: return "Pro 플랜"
        case .text: return ""
        }
    }
    
    private func getStyleRequirementColor(_ style: SummaryConfig.OutputStyle) -> Color {
        switch style {
        case .webtoon: return Color.gray
        case .image: return AppColors.warning
        case .text: return Color.clear
        }
    }
    
    private func canGenerate() -> Bool {
        if summaryConfig.outputStyle == .image {
            return usageService.canCreateImageCardNews()
        } else {
            return usageService.canCreateTextCardNews()
        }
    }
    
    private func setupClaudeAPI() {
        print("🔍 [SummaryConfigView] API 설정 확인 - isConfigured: \(claudeService.isConfigured)")
        if claudeService.isConfigured {
            print("✅ [SummaryConfigView] Claude API 준비 완료")
        } else {
            print("⚠️ [SummaryConfigView] API 키가 설정되지 않았습니다")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func generateSummary() {
        print("🔍 [SummaryConfigView] 카드뉴스 생성 시작")
        print("🔧 [SummaryConfigView] 설정: \(summaryConfig.cardCount.displayName), \(summaryConfig.outputStyle.displayName), \(summaryConfig.language.displayName), \(summaryConfig.tone.displayName)")
        
        if summaryConfig.outputStyle == .image && !usageService.canCreateImageCardNews() {
            print("❌ [SummaryConfigView] 이미지 카드뉴스 권한 없음")
            paywallTrigger = .imageGenerationRequested
            showPaywall = true
            return
        }
        
        if !usageService.canCreateTextCardNews() {
            print("❌ [SummaryConfigView] 텍스트 카드뉴스 권한 없음")
            paywallTrigger = .freeUsageExhausted
            showPaywall = true
            return
        }
        
        isGeneratingSummary = true
        
        Task {
            do {
                let result = try await claudeService.generateCardNewsSummary(
                    from: processedDocument,
                    config: summaryConfig
                )
                
                await MainActor.run {
                    if summaryConfig.outputStyle == .image {
                        usageService.recordImageCardNewsUsage()
                    } else {
                        usageService.recordTextCardNewsUsage()
                    }
                    
                    generatedSummary = result
                    showSummaryResult = true
                    isGeneratingSummary = false
                    print("🎉 [SummaryConfigView] 카드뉴스 생성 완료! 카드 수: \(result.cards.count)장")
                    print("📊 [SummaryConfigView] 사용량 기록 완료 - 남은 무료 횟수: \(usageService.remainingFreeUsage)회")
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isGeneratingSummary = false
                    print("❌ [SummaryConfigView] 생성 실패: \(error)")
                }
            }
        }
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let summaryCompleted = Notification.Name("summaryCompleted")
}

#Preview {
    let sampleDocumentInfo = DocumentInfo(
        fileName: "샘플문서.pdf",
        fileSize: 1024000,
        fileType: "PDF"
    )
    
    let sampleDocument = ProcessedDocument(
        originalDocument: sampleDocumentInfo,
        content: "이것은 샘플 문서의 내용입니다. 카드뉴스로 변환할 텍스트가 여기에 들어갑니다."
    )
    
    SummaryConfigView(processedDocument: sampleDocument)
}
