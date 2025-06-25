import SwiftUI

struct SummaryConfigView: View {
    @StateObject private var claudeService = ClaudeAPIService()
    @Environment(\.dismiss) private var dismiss
    @State private var summaryConfig = SummaryConfig(
        cardCount: .four,
        outputStyle: .webtoon,
        language: .korean,
        tone: .friendly
    )
    @State private var showAPIKeyAlert = false
    @State private var tempAPIKey = ""
    @State private var isGeneratingSummary = false
    @State private var showSummaryResult = false
    @State private var generatedSummary: SummaryResult?
    @State private var errorMessage: String?
    @State private var showError = false
    
    let processedDocument: ProcessedDocument
    
    init(processedDocument: ProcessedDocument) {
        self.processedDocument = processedDocument
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 상단 문서 정보
                    documentInfoSection
                    
                    // API 키 설정 섹션
                    apiKeySection
                    
                    // 카드 수 선택
                    cardCountSection
                    
                    // 출력 스타일 선택
                    outputStyleSection
                    
                    // 언어 선택
                    languageSection
                    
                    // 톤 선택
                    toneSection
                    
                    // 예상 토큰 사용량
                    tokenEstimationSection
                    
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
            }
            .alert("API 키 입력", isPresented: $showAPIKeyAlert) {
                TextField("Claude API 키를 입력하세요", text: $tempAPIKey)
                    .textFieldStyle(.roundedBorder)
                Button("저장") {
                    claudeService.setAPIKey(tempAPIKey)
                    tempAPIKey = ""
                }
                Button("취소", role: .cancel) {
                    tempAPIKey = ""
                }
            } message: {
                Text("Claude API를 사용하려면 API 키가 필요합니다.\nAnthropic 웹사이트에서 발급받으실 수 있습니다.")
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
                }
            }
            .onAppear {
                tempAPIKey = claudeService.apiKey
            }
        }
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
    
    // MARK: - API Key Section
    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(claudeService.isConfigured ? .green : .orange)
                Text("API 설정")
                    .font(.headline)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(claudeService.isConfigured ? "API 키 설정됨" : "API 키 필요")
                        .font(.subheadline)
                        .foregroundColor(claudeService.isConfigured ? .green : .orange)
                    
                    Text(claudeService.isConfigured ? "Claude API 사용 준비 완료" : "요약 생성을 위해 API 키를 설정하세요")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(claudeService.isConfigured ? "변경" : "설정") {
                    tempAPIKey = claudeService.apiKey
                    showAPIKeyAlert = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
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
                        summaryConfig = SummaryConfig(
                            cardCount: summaryConfig.cardCount,
                            outputStyle: style,
                            language: summaryConfig.language,
                            tone: summaryConfig.tone
                        )
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(style.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
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
    
    // MARK: - Token Estimation Section
    private var tokenEstimationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundColor(.orange)
                Text("예상 사용량")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 8) {
                infoRow(icon: "arrow.up.circle", title: "입력 토큰", value: "약 \(estimatedInputTokens)개")
                infoRow(icon: "arrow.down.circle", title: "출력 토큰", value: "약 \(estimatedOutputTokens)개")
                infoRow(icon: "dollarsign.circle", title: "예상 비용", value: "약 $\(String(format: "%.4f", estimatedCost))")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Generate Button
    private var generateButton: some View {
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
                Text(isGeneratingSummary ? "생성 중..." : "카드뉴스 생성")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(canGenerateSummary ? Color.blue : Color.gray)
            .cornerRadius(12)
        }
        .disabled(!canGenerateSummary || isGeneratingSummary)
    }
    
    // MARK: - Helper Methods
    
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
    
    private var estimatedInputTokens: Int {
        return claudeService.estimateTokens(for: processedDocument.content) + 500 // 프롬프트 오버헤드
    }
    
    private var estimatedOutputTokens: Int {
        return summaryConfig.cardCount.rawValue * 200 // 카드당 약 200토큰
    }
    
    private var estimatedCost: Double {
        let inputCost = Double(estimatedInputTokens) * 0.000003 // Claude 3.5 Sonnet 입력 비용
        let outputCost = Double(estimatedOutputTokens) * 0.000015 // Claude 3.5 Sonnet 출력 비용
        return inputCost + outputCost
    }
    
    private var canGenerateSummary: Bool {
        return claudeService.isConfigured && !isGeneratingSummary
    }
    
    private func generateSummary() {
        guard canGenerateSummary else { return }
        
        print("🔍 [SummaryConfigView] 카드뉴스 생성 시작")
        isGeneratingSummary = true
        
        Task {
            do {
                let result = try await claudeService.generateCardNewsSummary(
                    from: processedDocument,
                    config: summaryConfig
                )
                
                await MainActor.run {
                    generatedSummary = result
                    showSummaryResult = true
                    isGeneratingSummary = false
                    print("🎉 [SummaryConfigView] 카드뉴스 생성 완료!")
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

#Preview {
    // ✅ 수정된 Preview - DocumentInfo 생성자에 맞춤
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
