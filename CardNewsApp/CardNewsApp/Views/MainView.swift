// MARK: - Summary History View

struct SummaryHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSummary: SummaryResult?
    @State private var showSummaryDetail = false
    
    let summaries: [SummaryResult]
    
    var body: some View {
        NavigationStack {
            if summaries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("저장된 요약이 없습니다")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("첫 번째 문서를 업로드해보세요!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("메인으로 돌아가기") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
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
            ToolbarItem(placement: .navigationBarLeading) {
                Button("← 뒤로") {
                    print("🔍 [SummaryHistoryView] 뒤로 버튼 클릭")
                    dismiss()
                }
                .foregroundColor(.blue)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("완료") {
                    print("🔍 [SummaryHistoryView] 완료 버튼 클릭")
                    dismiss()
                }
                .foregroundColor(.blue)
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