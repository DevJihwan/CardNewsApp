import SwiftUI

struct SummaryConfigView: View {
    @StateObject private var claudeService = ClaudeAPIService()
    @StateObject private var usageService = UsageTrackingService()
    @Environment(\.dismiss) private var dismiss
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
            ScrollView {
                VStack(spacing: 24) {
                    // 사용량 상태 표시
                    usageStatusSection
                    
                    // 상단 문서 정보
                    documentInfoSection
                    
                    // 카드 수 선택
                    cardCountSection
                    
                    // 출력 스타일 선택
                    outputStyleSection
                    
                    // 언어 선택
                    languageSection
                    
                    // 톤 선택
                    toneSection
                    
                    // 생성 버튼
                    generateButton
                    
                    // 하단 여백
                    Color.clear.frame(height: 50)
                }
                .padding()
            }
            .navigationTitle("요약 설정")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                if usageService.isSubscriptionActive {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("💎 \(usageService.currentSubscriptionTier.displayName)") {
                            // TODO: 구독 관리 화면
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
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
                            // 요약 결과 화면이 닫힐 때 MainView 새로고침 알림
                            NotificationCenter.default.post(name: .summaryCompleted, object: nil)
                            dismiss() // SummaryConfigView도 닫기
                        }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(triggerReason: paywallTrigger)
                    .onDisappear {
                        // Paywall이 닫힐 때 UI 새로고침
                        refreshTrigger.toggle()
                    }
            }
            .onAppear {
                setupClaudeAPI()
            }
            .onReceive(NotificationCenter.default.publisher(for: .subscriptionStatusChanged)) { _ in
                print("💎 [SummaryConfigView] 구독 상태 변경 알림 수신")
                // UI 새로고침 트리거
                refreshTrigger.toggle()
            }
            .onChange(of: refreshTrigger) { _, _ in
                // refreshTrigger가 변경될 때마다 View가 다시 렌더링됨
            }
        }
    }
    
    // MARK: - Usage Status Section
    private var usageStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: usageService.isSubscriptionActive ? "crown.fill" : "gift.fill")
                    .foregroundColor(usageService.isSubscriptionActive ? .orange : .green)
                Text(usageService.isSubscriptionActive ? "프리미엄 구독" : "무료 체험")
                    .font(.headline)
                Spacer()
                
                if !usageService.isSubscriptionActive {
                    Button("업그레이드") {
                        paywallTrigger = .upgradePrompt
                        showPaywall = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if usageService.isSubscriptionActive {
                // 구독자 상태
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(usageService.currentSubscriptionTier.displayName) 플랜")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("무제한 이용 가능")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    let stats = usageService.getUsageStats()
                    Text("이번 달 사용량: 텍스트 \(stats.textCount)개, 이미지 \(stats.imageCount)개")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                // 무료 사용자 상태
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("남은 무료 횟수")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(usageService.remainingFreeUsage)/2회")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(usageService.remainingFreeUsage > 0 ? .green : .red)
                    }
                    
                    if usageService.remainingFreeUsage == 0 {
                        Text("무료 체험이 완료되었습니다. 계속 이용하려면 구독이 필요합니다.")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text("무료 체험 중입니다. 텍스트 카드뉴스만 생성 가능합니다.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(usageService.isSubscriptionActive ? Color.orange.opacity(0.1) : Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Document Info Section
    private var documentInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.blue)
                Text("문서 정보")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 8) {
                infoRow(icon: "doc.fill", title: "파일명", value: processedDocument.originalDocument.fileName)
                infoRow(icon: "textformat.123", title: "단어 수", value: "\(processedDocument.wordCount)개")
                infoRow(icon: "character.textbox", title: "문자 수", value: "\(processedDocument.characterCount)자")
                infoRow(icon: "clock", title: "처리 시간", value: formatDate(processedDocument.processedAt))
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Card Count Section
    private var cardCountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "rectangle.3.group.fill")
                    .foregroundColor(.blue)
                Text("카드 수")
                    .font(.headline)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(SummaryConfig.CardCount.allCases, id: \.self) { count in
                    Button(action: {
                        summaryConfig = SummaryConfig(
                            cardCount: count,
                            outputStyle: summaryConfig.outputStyle,
                            language: summaryConfig.language,
                            tone: summaryConfig.tone
                        )
                        print("🔍 [SummaryConfigView] 카드 수 선택: \(count.displayName)")
                    }) {
                        VStack(spacing: 8) {
                            Text("\(count.rawValue)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(count.displayName)
                                .font(.caption)
                        }
                        .frame(height: 60)
                        .frame(maxWidth: .infinity)
                        .background(summaryConfig.cardCount == count ? Color.blue : Color(.systemGray6))
                        .foregroundColor(summaryConfig.cardCount == count ? .white : .primary)
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Output Style Section
    private var outputStyleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "paintbrush.fill")
                    .foregroundColor(.blue)
                Text("출력 스타일")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                ForEach(SummaryConfig.OutputStyle.allCases, id: \.self) { style in
                    Button(action: {
                        // 이미지 스타일 선택 시 권한 확인
                        if style == .image && !usageService.canCreateImageCardNews() {
                            paywallTrigger = .imageGenerationRequested
                            showPaywall = true
                            return
                        }
                        
                        summaryConfig = SummaryConfig(
                            cardCount: summaryConfig.cardCount,
                            outputStyle: style,
                            language: summaryConfig.language,
                            tone: summaryConfig.tone
                        )
                        print("🔍 [SummaryConfigView] 출력 스타일 선택: \(style.displayName)")
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(style.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    if style == .image && !usageService.canCreateImageCardNews() {
                                        Text("프리미엄")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange)
                                            .cornerRadius(4)
                                    }
                                }
                                
                                Text(style.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            if summaryConfig.outputStyle == style {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(summaryConfig.outputStyle == style ? Color.blue.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(12)
                        .opacity((style == .image && !usageService.canCreateImageCardNews()) ? 0.6 : 1.0)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Language Section
    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.blue)
                Text("언어")
                    .font(.headline)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(SummaryConfig.SummaryLanguage.allCases, id: \.self) { language in
                    Button(action: {
                        summaryConfig = SummaryConfig(
                            cardCount: summaryConfig.cardCount,
                            outputStyle: summaryConfig.outputStyle,
                            language: language,
                            tone: summaryConfig.tone
                        )
                        print("🔍 [SummaryConfigView] 언어 선택: \(language.displayName)")
                    }) {
                        Text(language.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(height: 44)
                            .frame(maxWidth: .infinity)
                            .background(summaryConfig.language == language ? Color.blue : Color(.systemGray6))
                            .foregroundColor(summaryConfig.language == language ? .white : .primary)
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Tone Section
    private var toneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.blue)
                Text("톤")
                    .font(.headline)
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(SummaryConfig.SummaryTone.allCases, id: \.self) { tone in
                    Button(action: {
                        summaryConfig = SummaryConfig(
                            cardCount: summaryConfig.cardCount,
                            outputStyle: summaryConfig.outputStyle,
                            language: summaryConfig.language,
                            tone: tone
                        )
                        print("🔍 [SummaryConfigView] 톤 선택: \(tone.displayName)")
                    }) {
                        Text(tone.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(height: 44)
                            .frame(maxWidth: .infinity)
                            .background(summaryConfig.tone == tone ? Color.blue : Color(.systemGray6))
                            .foregroundColor(summaryConfig.tone == tone ? .white : .primary)
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Generate Button
    private var generateButton: some View {
        VStack(spacing: 16) {
            Button(action: {
                generateSummary()
            }) {
                HStack {
                    if isGeneratingSummary {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    Text(isGeneratingSummary ? "카드뉴스 생성 중..." : "카드뉴스 생성")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(getGenerateButtonColor())
                .cornerRadius(12)
            }
            .disabled(isGeneratingSummary || !canGenerate())
            
            // 생성 불가능한 경우 안내 메시지
            if !canGenerate() && !isGeneratingSummary {
                usageLimitMessage
            }
            
            // 생성 진행 중일 때 설명 텍스트
            if isGeneratingSummary {
                VStack(spacing: 8) {
                    Text("AI가 문서를 분석하여 \(summaryConfig.cardCount.displayName) 카드뉴스를 생성하고 있습니다")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("설정: \(summaryConfig.outputStyle.displayName), \(summaryConfig.language.displayName), \(summaryConfig.tone.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("잠시만 기다려주세요...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Usage Limit Message
    private var usageLimitMessage: some View {
        VStack(spacing: 8) {
            if summaryConfig.outputStyle == .image && !usageService.canCreateImageCardNews() {
                Text("이미지 카드뉴스는 프리미엄 구독자만 이용 가능합니다")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            } else if !usageService.canCreateTextCardNews() {
                Text("무료 사용량을 모두 소진하셨습니다")
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                
                Button("프리미엄 구독하기") {
                    paywallTrigger = .freeUsageExhausted
                    showPaywall = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Methods
    
    private func canGenerate() -> Bool {
        if summaryConfig.outputStyle == .image {
            return usageService.canCreateImageCardNews()
        } else {
            return usageService.canCreateTextCardNews()
        }
    }
    
    private func getGenerateButtonColor() -> Color {
        if isGeneratingSummary {
            return Color.gray
        } else if canGenerate() {
            return Color.blue
        } else {
            return Color.gray
        }
    }
    
    private func setupClaudeAPI() {
        // Info.plist에서 이미 API 키가 로드되었으므로 추가 설정 불필요
        print("🔍 [SummaryConfigView] API 설정 확인 - isConfigured: \(claudeService.isConfigured)")
        
        if claudeService.isConfigured {
            print("✅ [SummaryConfigView] Claude API 준비 완료")
        } else {
            print("⚠️ [SummaryConfigView] API 키가 설정되지 않았습니다")
        }
    }
    
    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
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
        
        // 사용량 제한 확인
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
                    // 사용량 기록
                    if summaryConfig.outputStyle == .image {
                        usageService.recordImageCardNewsUsage()
                    } else {
                        usageService.recordTextCardNewsUsage()
                    }
                    
                    generatedSummary = result
                    showSummaryResult = true
                    isGeneratingSummary = false
                    print("🎉 [SummaryConfigView] 카드뉴스 생성 완료! 카드 수: \(result.cards.count)장")
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
    // 수정된 Preview - DocumentInfo 생성자에 맞춤
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
