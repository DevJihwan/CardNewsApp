    // MARK: - Summary Storage
    
    private func saveSummaryResult(_ result: SummaryResult) {
        // ✅ 추가: 빈 카드 검증 후 저장
        guard !result.cards.isEmpty else {
            print("❌ [ClaudeAPIService] 빈 카드 요약 감지 - 저장 건너뜀")
            print("📄 [ClaudeAPIService] 파일명: \(result.originalDocument.fileName)")
            return
        }
        
        // 각 카드의 기본 데이터 검증
        let validCards = result.cards.filter { card in
            let isValid = !card.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                         !card.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            
            if !isValid {
                print("⚠️ [ClaudeAPIService] 빈 제목 또는 내용의 카드 감지: 카드 \(card.cardNumber)")
            }
            
            return isValid
        }
        
        guard !validCards.isEmpty else {
            print("❌ [ClaudeAPIService] 모든 카드가 유효하지 않음 - 저장 건너뜀")
            return
        }
        
        // 유효한 카드만으로 새 결과 생성
        let validatedResult = SummaryResult(
            id: result.id,
            config: result.config,
            originalDocument: result.originalDocument,
            cards: validCards,
            createdAt: result.createdAt,
            tokensUsed: result.tokensUsed
        )
        
        print("✅ [ClaudeAPIService] 유효한 카드 \(validCards.count)개로 요약 저장 진행")
        
        // UserDefaults를 사용한 간단한 저장 (추후 CoreData로 업그레이드)
        var summaries = loadSavedSummaries()
        summaries.insert(validatedResult, at: 0) // 최신 항목을 앞에 추가
        
        // 최대 10개까지만 저장
        if summaries.count > 10 {
            summaries = Array(summaries.prefix(10))
        }
        
        do {
            let data = try JSONEncoder().encode(summaries.map { EncodableSummaryResult(from: $0) })
            UserDefaults.standard.set(data, forKey: "saved_summaries")
            print("✅ [ClaudeAPIService] 요약 결과 저장 완료")
            
            // ✅ 추가: 요약 완료 알림 발송
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .summaryCompleted, object: validatedResult)
            }
            
        } catch {
            print("❌ [ClaudeAPIService] 요약 결과 저장 실패: \(error)")
        }
    }
    
    // 저장된 요약 로드
    func loadSavedSummaries() -> [SummaryResult] {
        guard let data = UserDefaults.standard.data(forKey: "saved_summaries") else {
            print("🔍 [ClaudeAPIService] 저장된 요약 데이터 없음")
            return []
        }
        
        do {
            let encodableSummaries = try JSONDecoder().decode([EncodableSummaryResult].self, from: data)
            let summaries = encodableSummaries.map { $0.toSummaryResult() }
            
            // ✅ 추가: 로드된 데이터 검증
            let validSummaries = summaries.filter { summary in
                let isValid = !summary.cards.isEmpty
                if !isValid {
                    print("⚠️ [ClaudeAPIService] 빈 카드 요약 발견 - 필터링: \(summary.originalDocument.fileName)")
                }
                return isValid
            }
            
            print("📊 [ClaudeAPIService] 저장된 요약 로드: 전체 \(summaries.count)개, 유효 \(validSummaries.count)개")
            
            // 유효하지 않은 데이터가 있으면 정리해서 다시 저장
            if validSummaries.count != summaries.count {
                print("🔧 [ClaudeAPIService] 손상된 데이터 정리 중...")
                cleanupInvalidSummaries(validSummaries)
            }
            
            return validSummaries
            
        } catch {
            print("❌ [ClaudeAPIService] 저장된 요약 로드 실패: \(error)")
            print("🔧 [ClaudeAPIService] 데이터 초기화를 권장합니다")
            return []
        }
    }
    
    // ✅ 추가: 손상된 데이터 정리 함수
    private func cleanupInvalidSummaries(_ validSummaries: [SummaryResult]) {
        do {
            let data = try JSONEncoder().encode(validSummaries.map { EncodableSummaryResult(from: $0) })
            UserDefaults.standard.set(data, forKey: "saved_summaries")
            print("✅ [ClaudeAPIService] 손상된 데이터 정리 완료")
        } catch {
            print("❌ [ClaudeAPIService] 데이터 정리 실패: \(error)")
        }
    }