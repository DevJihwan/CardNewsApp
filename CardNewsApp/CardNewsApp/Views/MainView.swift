        NavigationStack {
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