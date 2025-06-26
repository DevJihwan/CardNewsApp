import SwiftUI

struct SummaryResultView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentCardIndex = 0
    @State private var showShareSheet = false
    @State private var showSaveConfirmation = false
    
    let summaryResult: SummaryResult
    
    init(summaryResult: SummaryResult) {
        self.summaryResult = summaryResult
        
        // 디버깅 로그 추가
        print("🔍 [SummaryResultView] 초기화 시작")
        print("📄 [SummaryResultView] 파일명: \(summaryResult.originalDocument.fileName)")
        print("🎯 [SummaryResultView] 카드 수: \(summaryResult.cards.count)장")
        print("⚙️ [SummaryResultView] 설정: \(summaryResult.config.cardCount.displayName), \(summaryResult.config.outputStyle.displayName)")
        
        // 각 카드 내용 확인
        for (index, card) in summaryResult.cards.enumerated() {
            print("📇 [SummaryResultView] 카드 \(index + 1): '\(card.title)' (내용 길이: \(card.content.count)자)")
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 상단 정보 바
                topInfoBar
                
                // 카드뷰가 비어있는지 확인
                if summaryResult.cards.isEmpty {
                    emptyStateView
                } else {
                    // 카드 뷰어
                    cardViewer
                    
                    // 하단 컨트롤
                    bottomControls
                }
            }
            .navigationTitle("카드뉴스")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("완료") {
                        print("🔍 [SummaryResultView] 완료 버튼 클릭 - 모든 모달 닫기")
                        // 모든 모달을 닫는 노티피케이션 발송
                        NotificationCenter.default.post(name: .dismissAllModals, object: nil)
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showShareSheet = true }) {
                            Label("공유하기", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: { saveToGallery() }) {
                            Label("갤러리에 저장", systemImage: "square.and.arrow.down")
                        }
                        
                        Button(action: { exportAsPDF() }) {
                            Label("PDF로 내보내기", systemImage: "doc.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityViewController(activityItems: generateShareContent())
            }
            .alert("저장 완료", isPresented: $showSaveConfirmation) {
                Button("확인") { }
            } message: {
                Text("카드뉴스가 갤러리에 저장되었습니다.")
            }
            .onAppear {
                print("🔍 [SummaryResultView] 화면 표시됨")
                print("📊 [SummaryResultView] 현재 카드 인덱스: \(currentCardIndex)")
                print("📋 [SummaryResultView] 총 카드 수: \(summaryResult.cards.count)")
            }
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("카드뉴스를 불러올 수 없습니다")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("저장된 데이터에 문제가 있을 수 있습니다.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("다시 시도") {
                print("🔍 [SummaryResultView] 다시 시도 버튼 클릭")
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Top Info Bar
    private var topInfoBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(summaryResult.originalDocument.fileName)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    Label("\(summaryResult.config.cardCount.displayName)", systemImage: "rectangle.3.group.fill")
                    Label(summaryResult.config.outputStyle.displayName, systemImage: "paintbrush.fill")
                    Label(summaryResult.config.language.displayName, systemImage: "globe")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if !summaryResult.cards.isEmpty {
                    Text("\(currentCardIndex + 1) / \(summaryResult.cards.count)")
                        .font(.headline)
                        .fontWeight(.bold)
                } else {
                    Text("0 / 0")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                
                Text(formatDate(summaryResult.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Card Viewer
    private var cardViewer: some View {
        TabView(selection: $currentCardIndex) {
            ForEach(Array(summaryResult.cards.enumerated()), id: \.offset) { index, card in
                CardView(card: card, config: summaryResult.config)
                    .tag(index)
                    .onAppear {
                        print("🔍 [SummaryResultView] 카드 \(index + 1) 표시됨: '\(card.title)'")
                    }
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: currentCardIndex) { oldValue, newValue in
            print("🔍 [SummaryResultView] 카드 변경: \(oldValue + 1) → \(newValue + 1)")
        }
    }
    
    // MARK: - Bottom Controls
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // 페이지 인디케이터
            HStack(spacing: 8) {
                ForEach(0..<summaryResult.cards.count, id: \.self) { index in
                    Circle()
                        .fill(currentCardIndex == index ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentCardIndex = index
                            }
                        }
                }
            }
            
            // 네비게이션 버튼
            HStack(spacing: 20) {
                Button(action: { previousCard() }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title)
                        .foregroundColor(currentCardIndex > 0 ? .blue : .gray)
                }
                .disabled(currentCardIndex <= 0)
                
                Spacer()
                
                // 현재 카드 정보
                if currentCardIndex < summaryResult.cards.count {
                    VStack {
                        Text("카드 \(currentCardIndex + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(summaryResult.cards[currentCardIndex].title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                } else {
                    VStack {
                        Text("오류")
                            .font(.caption)
                            .foregroundColor(.red)
                        
                        Text("카드 인덱스 오류")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
                
                Button(action: { nextCard() }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title)
                        .foregroundColor(currentCardIndex < summaryResult.cards.count - 1 ? .blue : .gray)
                }
                .disabled(currentCardIndex >= summaryResult.cards.count - 1)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helper Methods
    
    private func previousCard() {
        guard currentCardIndex > 0 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentCardIndex -= 1
        }
    }
    
    private func nextCard() {
        guard currentCardIndex < summaryResult.cards.count - 1 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentCardIndex += 1
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func saveToGallery() {
        // TODO: 카드를 이미지로 렌더링하여 갤러리에 저장
        print("🔍 [SummaryResultView] 갤러리 저장 기능 (구현 예정)")
        showSaveConfirmation = true
    }
    
    private func exportAsPDF() {
        // TODO: PDF 내보내기 기능
        print("🔍 [SummaryResultView] PDF 내보내기 기능 (구현 예정)")
    }
    
    private func generateShareContent() -> [Any] {
        let shareText = """
        📱 CardNews App으로 만든 카드뉴스
        
        📄 원본: \(summaryResult.originalDocument.fileName)
        🎨 스타일: \(summaryResult.config.outputStyle.displayName)
        📊 \(summaryResult.config.cardCount.displayName) 구성
        
        \(summaryResult.cards.enumerated().map { index, card in
            "[\(index + 1)] \(card.title)\n\(card.content)"
        }.joined(separator: "\n\n"))
        """
        
        return [shareText]
    }
}

// MARK: - Card View

struct CardView: View {
    let card: SummaryResult.CardContent
    let config: SummaryConfig
    
    init(card: SummaryResult.CardContent, config: SummaryConfig) {
        self.card = card
        self.config = config
        
        print("🔍 [CardView] 카드 \(card.cardNumber) 생성: '\(card.title)' (내용: \(card.content.prefix(50))...)")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 카드 헤더
            VStack(spacing: 12) {
                // 카드 번호
                HStack {
                    Spacer()
                    Text("\(card.cardNumber)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.blue))
                    Spacer()
                }
                
                // 카드 제목
                Text(card.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(hex: card.textColor ?? "#000000"))
            }
            .padding(.top, 32)
            .padding(.horizontal, 24)
            
            Spacer()
            
            // 카드 내용
            ScrollView {
                Text(card.content)
                    .font(.body)
                    .lineSpacing(8)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(hex: card.textColor ?? "#000000"))
                    .padding(.horizontal, 24)
            }
            .frame(maxHeight: 400)
            
            Spacer()
            
            // 이미지 플레이스홀더 (향후 AI 이미지 생성)
            if let imagePrompt = card.imagePrompt, !imagePrompt.isEmpty {
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 120)
                        .overlay(
                            VStack {
                                Image(systemName: "photo")
                                    .font(.title)
                                    .foregroundColor(.gray)
                                Text("이미지 생성 예정")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        )
                    
                    Text("이미지 프롬프트: \(imagePrompt)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            } else {
                Spacer()
                    .frame(height: 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: card.backgroundColor ?? "#FFFFFF"))
        .cornerRadius(16)
        .shadow(radius: 4)
        .padding()
        .onAppear {
            print("🔍 [CardView] 카드 \(card.cardNumber) 화면에 표시됨")
        }
    }
}

// MARK: - Activity View Controller

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview {
    let sampleCards = [
        SummaryResult.CardContent(
            cardNumber: 1,
            title: "첫 번째 카드",
            content: "이것은 첫 번째 카드의 내용입니다. 문서의 핵심 내용을 요약하여 보여줍니다.",
            imagePrompt: "현대적인 오피스 환경",
            backgroundColor: "#FFFFFF",
            textColor: "#000000"
        ),
        SummaryResult.CardContent(
            cardNumber: 2,
            title: "두 번째 카드",
            content: "두 번째 카드에서는 더 자세한 내용을 다룹니다. 독자가 쉽게 이해할 수 있도록 구성되었습니다.",
            imagePrompt: "데이터 차트와 그래프",
            backgroundColor: "#F0F8FF",
            textColor: "#000000"
        ),
        SummaryResult.CardContent(
            cardNumber: 3,
            title: "세 번째 카드",
            content: "마지막 카드에서는 결론과 요약을 제시합니다. 전체적인 내용을 정리하고 핵심 메시지를 전달합니다.",
            imagePrompt: "성공적인 결과를 나타내는 이미지",
            backgroundColor: "#F5F5DC",
            textColor: "#000000"
        )
    ]
    
    // ✅ 수정된 Preview - DocumentInfo 생성자에 맞춤
    let sampleDocumentInfo = DocumentInfo(
        fileName: "샘플문서.pdf",
        fileSize: 1024000,
        fileType: "PDF"
    )
    
    let sampleResult = SummaryResult(
        id: UUID().uuidString,
        config: SummaryConfig(
            cardCount: .four,
            outputStyle: .webtoon,
            language: .korean,
            tone: .friendly
        ),
        originalDocument: sampleDocumentInfo,
        cards: sampleCards,
        createdAt: Date(),
        tokensUsed: 1500
    )
    
    SummaryResultView(summaryResult: sampleResult)
}
