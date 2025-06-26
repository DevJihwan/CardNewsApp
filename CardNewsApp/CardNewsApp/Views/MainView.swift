import SwiftUI

struct MainView: View {
    @StateObject private var claudeService = ClaudeAPIService()
    @State private var showFileUpload = false
    @State private var selectedFileURL: URL?
    @State private var isAppInitialized = false
    @State private var recentSummaries: [SummaryResult] = []
    @State private var showSummaryDetail = false
    @State private var selectedSummary: SummaryResult?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // 앱 로고 영역
                    VStack {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("CardNews App")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("문서를 카드뉴스로 변환하세요")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // 선택된 파일 정보 표시 (모달이 닫혔을 때)
                    if let fileURL = selectedFileURL, !showFileUpload {
                        selectedFileCard(fileURL)
                    }
                    
                    // 파일 업로드 버튼
                    Button(action: {
                        print("🔍 [MainView] 파일 업로드 버튼 클릭")
                        openFileUpload()
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 30))
                            Text("파일 업로드")
                                .font(.headline)
                            Text("PDF 파일")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(radius: 2)
                    }
                    
                    // 기능 안내 카드들
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        featureCard(
                            icon: "rectangle.3.group.fill",
                            title: "4/6/8컷",
                            description: "원하는 길이 선택"
                        )
                        
                        featureCard(
                            icon: "paintbrush.fill",
                            title: "3가지 스타일",
                            description: "웹툰/텍스트/이미지"
                        )
                        
                        featureCard(
                            icon: "heart.fill",
                            title: "첫 사용 무료",
                            description: "체험해보세요"
                        )
                        
                        featureCard(
                            icon: "iphone",
                            title: "모바일 최적화",
                            description: "언제 어디서나"
                        )
                    }
                    
                    // 최근 요약 목록
                    recentSummariesSection
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("CardNews")
            .sheet(isPresented: $showFileUpload) {
                FileUploadView(preselectedFile: selectedFileURL)
                    .onAppear {
                        print("🔍 [MainView] FileUploadView 모달 표시")
                    }
            }
            .sheet(isPresented: $showSummaryDetail) {
                if let summary = selectedSummary {
                    SummaryResultView(summaryResult: summary)
                }
            }
            .onAppear {
                // 🔧 앱 초기화 완료 후 일정 시간 대기
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isAppInitialized = true
                    loadRecentSummaries()
                    print("🔍 [MainView] 앱 초기화 완료")
                }
                
                // Notification 관찰자 등록
                NotificationCenter.default.addObserver(
                    forName: .summaryCompleted,
                    object: nil,
                    queue: .main
                ) { _ in
                    print("🔍 [MainView] 새로운 요약 완료 알림 수신")
                    loadRecentSummaries()
                }
            }
            .refreshable {
                loadRecentSummaries()
            }
        }
    }
    
    // MARK: - Recent Summaries Section
    
    private var recentSummariesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("최근 요약")
                    .font(.headline)
                Spacer()
                if !recentSummaries.isEmpty {
                    Button("전체 보기") {
                        // TODO: 히스토리 화면으로 이동
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if recentSummaries.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(recentSummaries.prefix(3), id: \.id) { summary in
                        summaryCard(summary)
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Image(systemName: "tray")
                .font(.system(size: 30))
                .foregroundColor(.gray)
            Text("아직 요약된 문서가 없습니다")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("첫 번째 문서를 업로드해보세요!")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func summaryCard(_ summary: SummaryResult) -> some View {
        Button(action: {
            selectedSummary = summary
            showSummaryDetail = true
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(summary.originalDocument.fileName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            Label("\(summary.cards.count)컷", systemImage: "rectangle.3.group")
                            Label(summary.config.outputStyle.displayName, systemImage: "paintbrush")
                            Label(summary.config.language.displayName, systemImage: "globe")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatDate(summary.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                // 첫 번째 카드 미리보기
                if let firstCard = summary.cards.first {
                    Text(firstCard.title)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .padding(.top, 4)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helper Methods
    
    // 🔧 안전한 파일 업로드 모달 열기
    private func openFileUpload() {
        // 앱이 완전히 초기화된 후에만 모달 열기
        guard isAppInitialized else {
            print("⚠️ [MainView] 앱 아직 초기화 중... 잠시 후 다시 시도")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                openFileUpload()
            }
            return
        }
        
        print("🔍 [MainView] 파일 업로드 모달 열기 시작")
        
        // 약간의 지연을 두어 안정성 향상
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showFileUpload = true
            print("🔍 [MainView] showFileUpload = true 설정 완료")
        }
    }
    
    private func loadRecentSummaries() {
        print("🔍 [MainView] 최근 요약 로드 시작")
        recentSummaries = claudeService.loadSavedSummaries()
        print("🔍 [MainView] 로드된 요약 수: \(recentSummaries.count)개")
        
        // 로드된 요약들의 카드 수 확인
        for summary in recentSummaries.prefix(3) {
            print("📊 [MainView] 요약 '\(summary.originalDocument.fileName)': \(summary.cards.count)장 (설정: \(summary.config.cardCount.displayName))")
        }
    }
    
    // 선택된 파일 카드 (메인 화면에 표시)
    private func selectedFileCard(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundColor(.blue)
                Text("선택된 파일")
                    .font(.headline)
                Spacer()
                Button("계속 처리") {
                    openFileUpload()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            Text(url.lastPathComponent)
                .font(.body)
                .lineLimit(2)
        }
        .padding()
        .background(Color(.systemBlue).opacity(0.1))
        .cornerRadius(8)
    }
    
    // 기능 안내 카드
    private func featureCard(icon: String, title: String, description: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
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
    
    deinit {
        // Notification 관찰자 제거
        NotificationCenter.default.removeObserver(self)
    }
}

#Preview {
    MainView()
}
