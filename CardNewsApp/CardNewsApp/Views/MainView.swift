import SwiftUI

struct MainView: View {
    @StateObject private var claudeService = ClaudeAPIService()
    @State private var showFileUpload = false
    @State private var selectedFileURL: URL?
    @State private var isAppInitialized = false
    @State private var recentSummaries: [SummaryResult] = []
    @State private var showSummaryDetail = false
    @State private var selectedSummary: SummaryResult?
    @State private var showAllSummaries = false
    
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
                        .onAppear {
                            print("🔍 [MainView] SummaryResultView 모달 표시")
                            print("📄 [MainView] 선택된 요약: \(summary.originalDocument.fileName)")
                            print("🎯 [MainView] 카드 수: \(summary.cards.count)장")
                        }
                } else {
                    Text("선택된 요약이 없습니다")
                        .foregroundColor(.red)
                        .onAppear {
                            print("❌ [MainView] selectedSummary가 nil입니다")
                        }
                }
            }
            .sheet(isPresented: $showAllSummaries) {
                SummaryHistoryView(summaries: recentSummaries)
                    .onAppear {
                        print("🔍 [MainView] SummaryHistoryView 모달 표시")
                    }
            }
            .onAppear {
                // 🔧 앱 초기화 완료 후 일정 시간 대기
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isAppInitialized = true
                    loadRecentSummaries()
                    print("🔍 [MainView] 앱 초기화 완료")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .summaryCompleted)) { _ in
                print("🔍 [MainView] 새로운 요약 완료 알림 수신")
                loadRecentSummaries()
            }
            .onReceive(NotificationCenter.default.publisher(for: .dismissAllModals)) { _ in
                print("🔍 [MainView] 모든 모달 닫기 알림 수신")
                showFileUpload = false
                showSummaryDetail = false
                showAllSummaries = false
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
                        print("🔍 [MainView] 전체 보기 버튼 클릭")
                        showAllSummaries = true
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
            print("🔍 [MainView] 요약 카드 선택됨")
            print("📄 [MainView] 파일명: \(summary.originalDocument.fileName)")
            print("🎯 [MainView] 카드 수: \(summary.cards.count)장")
            print("📝 [MainView] 카드 내용 확인:")
            
            // 각 카드의 내용을 상세히 로그
            for (index, card) in summary.cards.enumerated() {
                print("  📇 카드 \(index + 1): '\(card.title)' (내용: \(card.content.count)자)")
                print("     내용 미리보기: \(card.content.prefix(100))...")
            }
            
            selectedSummary = summary
            showSummaryDetail = true
            
            print("✅ [MainView] selectedSummary 설정 완료, showSummaryDetail = true")
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
                } else {
                    Text("카드 정보 없음")
                        .font(.caption)
                        .foregroundColor(.red)
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
}

// MARK: - Summary History View

struct SummaryHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSummary: SummaryResult?
    @State private var showSummaryDetail = false
    
    let summaries: [SummaryResult]
    
    var body: some View {
        NavigationView {
            VStack {
                if summaries.isEmpty {
                    // 빈 상태 - 중앙 정렬로 전체 화면 사용
                    Spacer()
                    
                    VStack(spacing: 24) {
                        Image(systemName: "tray")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        VStack(spacing: 8) {
                            Text("저장된 요약이 없습니다")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("첫 번째 문서를 업로드해서\n카드뉴스를 만들어보세요!")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button(action: {
                            print("🔍 [SummaryHistoryView] 메인으로 돌아가기 버튼 클릭")
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "house.fill")
                                Text("메인으로 돌아가기")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                    }
                    
                    Spacer()
                } else {
                    // 요약이 있는 경우 - 리스트 표시
                    List {
                        ForEach(summaries, id: \.id) { summary in
                            summaryHistoryRow(summary)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    print("🔍 [SummaryHistoryView] 요약 선택: \(summary.originalDocument.fileName)")
                                    selectedSummary = summary
                                    showSummaryDetail = true
                                }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("전체 요약")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        print("🔍 [SummaryHistoryView] 완료 버튼 클릭")
                        dismiss()
                    }
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
    
    private func summaryHistoryRow(_ summary: SummaryResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.originalDocument.fileName)
                        .font(.headline)
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        Label("\(summary.cards.count)컷", systemImage: "rectangle.3.group")
                        Label(summary.config.outputStyle.displayName, systemImage: "paintbrush")
                        Label(summary.config.language.displayName, systemImage: "globe")
                        Label(summary.config.tone.displayName, systemImage: "waveform")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatHistoryDate(summary.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(summary.tokensUsed) 토큰")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // 첫 번째 카드 미리보기
            if let firstCard = summary.cards.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text(firstCard.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(firstCard.content)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
    
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
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let dismissAllModals = Notification.Name("dismissAllModals")
}

#Preview {
    MainView()
}
