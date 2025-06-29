import Foundation

// Claude API 서비스 - AI 요약 및 카드뉴스 생성 담당
@MainActor
class ClaudeAPIService: ObservableObject {
    
    // MARK: - Properties
    
    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    // 개발자 설정 API 키 (배포 시에는 더 안전한 방법 사용)
    private var apiKey: String = ""
    @Published var isConfigured: Bool = false
    
    // MARK: - Initialization
    
    init() {
        setupJSONCoders()
        loadDeveloperAPIKey()
    }
    
    private func setupJSONCoders() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        encoder.dateEncodingStrategy = .formatted(dateFormatter)
    }
    
    // MARK: - API Key Management (Developer-focused)
    
    private func loadDeveloperAPIKey() {
        // 1순위: 환경변수에서 로드 (배포 시 권장)
        if let envAPIKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envAPIKey.isEmpty {
            apiKey = envAPIKey
            isConfigured = true
            print("🔍 [ClaudeAPIService] 환경변수에서 API 키 로드 완료")
            return
        }
        
        // 2순위: Info.plist에서 로드 (개발 시 사용)
        if let plistAPIKey = Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String, !plistAPIKey.isEmpty {
            apiKey = plistAPIKey
            isConfigured = true
            print("🔍 [ClaudeAPIService] Info.plist에서 API 키 로드 완료")
            return
        }
        
        // 3순위: UserDefaults에서 로드 (개발자가 런타임에 설정)
        let savedKey = UserDefaults.standard.string(forKey: "claude_api_key") ?? ""
        if !savedKey.isEmpty {
            apiKey = savedKey
            isConfigured = true
            print("🔍 [ClaudeAPIService] UserDefaults에서 API 키 로드 완료")
            return
        }
        
        print("⚠️ [ClaudeAPIService] API 키가 설정되지 않았습니다. 개발자가 설정해주세요.")
        isConfigured = false
    }
    
    // 개발자용 API 키 설정 함수 (내부적으로만 사용)
    func setAPIKey(_ key: String) {
        apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        isConfigured = !apiKey.isEmpty
        
        // UserDefaults에 저장 (개발 편의성을 위해)
        UserDefaults.standard.set(apiKey, forKey: "claude_api_key")
        
        print("🔍 [ClaudeAPIService] API 키 설정: \(isConfigured ? "완료" : "제거")")
    }
    
    // MARK: - Main Summary Generation
    
    func generateCardNewsSummary(
        from document: ProcessedDocument,
        config: SummaryConfig
    ) async throws -> SummaryResult {
        
        guard isConfigured else {
            throw ClaudeAPIError.invalidAPIKey
        }
        
        print("🔍 [ClaudeAPIService] 카드뉴스 요약 생성 시작")
        print("📄 문서: \(document.originalDocument.fileName)")
        print("⚙️ 설정: \(config.cardCount.displayName), \(config.outputStyle.displayName)")
        
        // 1. 프롬프트 생성
        let prompt = generateSummaryPrompt(document: document, config: config)
        
        // 2. Claude API 호출
        let response = try await callClaudeAPI(prompt: prompt, config: config)
        
        // 3. 응답 파싱 및 카드 생성
        let cards = try parseCardsFromResponse(response.content.first?.text ?? "", config: config)
        
        // 4. 카드 수 검증 및 수정
        let validatedCards = validateAndFixCardCount(cards: cards, expectedCount: config.cardCount.rawValue)
        
        // 5. 결과 생성
        let result = SummaryResult(
            id: UUID().uuidString,
            config: config,
            originalDocument: document.originalDocument,
            cards: validatedCards,
            createdAt: Date(),
            tokensUsed: response.usage.inputTokens + response.usage.outputTokens
        )
        
        print("🎉 [ClaudeAPIService] 카드뉴스 생성 완료: \(validatedCards.count)장 (목표: \(config.cardCount.rawValue)장)")
        
        // 6. 결과 저장
        saveSummaryResult(result)
        
        return result
    }
    
    // MARK: - Prompt Generation
    
    private func generateSummaryPrompt(document: ProcessedDocument, config: SummaryConfig) -> String {
        let systemPrompt = generateSystemPrompt(config: config)
        let contentPrompt = generateContentPrompt(document: document, config: config)
        
        return """
        \(systemPrompt)
        
        \(contentPrompt)
        """
    }
    
    private func generateSystemPrompt(config: SummaryConfig) -> String {
        let languageInstruction = generateLanguageInstruction(config.language)
        let styleInstruction = generateStyleInstruction(config.outputStyle)
        let toneInstruction = generateToneInstruction(config.tone)
        
        return """
        당신은 전문적인 카드뉴스 제작 전문가입니다. 복잡한 문서를 정확히 \(config.cardCount.rawValue)장의 카드뉴스로 요약하는 것이 당신의 임무입니다.
        
        ## 🚨 핵심 규칙 (반드시 준수):
        1. **카드 수**: 정확히 \(config.cardCount.rawValue)장의 카드로 구성해주세요 (더도 적도 말고 정확히 \(config.cardCount.rawValue)장)
        2. **카드 번호**: 1번부터 \(config.cardCount.rawValue)번까지 순서대로 번호를 매겨주세요
        3. **독립성**: 각 카드는 독립적으로 이해 가능해야 합니다
        4. **연결성**: 전체적인 스토리 흐름이 자연스러워야 합니다
        5. **완성도**: 핵심 내용을 놓치지 않으면서도 쉽게 이해할 수 있게 만들어주세요
        
        ## 언어 설정:
        \(languageInstruction)
        
        ## 스타일 설정:
        \(styleInstruction)
        
        ## 톤 설정:
        \(toneInstruction)
        
        ## 🎯 출력 형식 (반드시 준수):
        반드시 다음 JSON 형식으로 정확히 \(config.cardCount.rawValue)개의 카드를 포함하여 응답해주세요:
        
        ```json
        {
          "cards": [
            {
              "cardNumber": 1,
              "title": "카드 제목",
              "content": "카드 내용",
              "imagePrompt": "이미지 생성을 위한 프롬프트 (선택사항)",
              "backgroundColor": "#FFFFFF",
              "textColor": "#000000"
            },
            {
              "cardNumber": 2,
              "title": "카드 제목",
              "content": "카드 내용",
              "imagePrompt": "이미지 생성을 위한 프롬프트 (선택사항)",
              "backgroundColor": "#FFFFFF",
              "textColor": "#000000"
            }
            // ... 정확히 \(config.cardCount.rawValue)개까지
          ]
        }
        ```
        
        ⚠️ 중요: cards 배열에는 정확히 \(config.cardCount.rawValue)개의 카드 객체가 포함되어야 합니다.
        """
    }
    
    private func generateLanguageInstruction(_ language: SummaryConfig.SummaryLanguage) -> String {
        switch language {
        case .korean:
            return "모든 내용을 자연스러운 한국어로 작성해주세요. 한국 문화와 정서에 맞는 표현을 사용하세요."
        case .english:
            return "Write all content in natural English. Use expressions that fit English-speaking culture."
        case .japanese:
            return "すべての内容を自然な日本語で書いてください。日本の文化や情緒に合った表現を使用してください。"
        }
    }
    
    private func generateStyleInstruction(_ style: SummaryConfig.OutputStyle) -> String {
        switch style {
        case .webtoon:
            return """
            웹툰 스타일로 작성해주세요:
            - 대화체와 감정 표현을 활용하세요
            - 캐릭터나 상황을 의인화해서 표현하세요
            - 재미있고 친근한 톤을 유지하세요
            - 말풍선이나 효과음 같은 요소를 텍스트로 표현하세요
            """
        case .text:
            return """
            텍스트 위주 스타일로 작성해주세요:
            - 핵심 내용을 간결하고 명확하게 정리하세요
            - 불필요한 장식적 표현은 피하세요
            - 정보 전달에 집중하세요
            - 논리적인 구조로 내용을 배치하세요
            """
        case .image:
            return """
            이미지 위주 스타일로 작성해주세요:
            - 시각적으로 표현하기 좋은 키워드를 강조하세요
            - 각 카드마다 상징적인 이미지 프롬프트를 제공하세요
            - 텍스트는 간결하게, 이미지로 보완할 수 있게 구성하세요
            - 인포그래픽 스타일을 염두에 두고 작성하세요
            """
        }
    }
    
    private func generateToneInstruction(_ tone: SummaryConfig.SummaryTone) -> String {
        switch tone {
        case .professional:
            return "전문적이고 신뢰할 수 있는 톤을 유지하세요. 정확한 정보 전달을 우선시하세요."
        case .casual:
            return "편안하고 친근한 톤을 사용하세요. 일상 대화하듯 자연스럽게 표현하세요."
        case .academic:
            return "학술적이고 객관적인 톤을 유지하세요. 근거와 논리를 중시하여 설명하세요."
        case .friendly:
            return "따뜻하고 친구 같은 톤을 사용하세요. 독자와의 친밀감을 형성하며 설명하세요."
        }
    }
    
    private func generateContentPrompt(document: ProcessedDocument, config: SummaryConfig) -> String {
        let contentPreview = document.content.prefix(3000) // 토큰 제한 고려
        
        return """
        ## 요약할 문서:
        
        **파일명:** \(document.originalDocument.fileName)
        **단어 수:** \(document.wordCount)개
        **문자 수:** \(document.characterCount)자
        
        **내용:**
        \(contentPreview)
        
        위 문서를 정확히 \(config.cardCount.rawValue)장의 카드뉴스로 요약해주세요.
        각 카드가 전체 스토리의 일부가 되도록 논리적으로 구성하고, 
        독자가 쉽게 이해하고 기억할 수 있도록 만들어주세요.
        
        🎯 목표: 정확히 \(config.cardCount.rawValue)장의 카드 생성
        """
    }
    
    // MARK: - Claude API Call
    
    private func callClaudeAPI(prompt: String, config: SummaryConfig) async throws -> ClaudeResponse {
        
        let url = URL(string: "\(ClaudeAPIConfig.baseURL)/messages")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(ClaudeAPIConfig.version, forHTTPHeaderField: "anthropic-version")
        
        let claudeRequest = ClaudeRequest(
            model: ClaudeAPIConfig.model,
            maxTokens: ClaudeAPIConfig.defaultMaxTokens,
            messages: [
                ClaudeMessage(role: "user", content: prompt)
            ],
            system: nil
        )
        
        do {
            request.httpBody = try encoder.encode(claudeRequest)
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClaudeAPIError.networkError(URLError(.badServerResponse))
            }
            
            print("🔍 [ClaudeAPIService] HTTP 응답 코드: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                do {
                    let claudeResponse = try decoder.decode(ClaudeResponse.self, from: data)
                    print("🎉 [ClaudeAPIService] API 호출 성공 - 토큰 사용: \(claudeResponse.usage.inputTokens + claudeResponse.usage.outputTokens)")
                    return claudeResponse
                } catch {
                    print("❌ [ClaudeAPIService] 응답 파싱 실패: \(error)")
                    throw ClaudeAPIError.decodingError(error)
                }
            } else {
                // 에러 응답 처리
                if let errorResponse = try? decoder.decode(ClaudeErrorResponse.self, from: data) {
                    print("❌ [ClaudeAPIService] API 에러: \(errorResponse.error.message)")
                    throw mapAPIError(errorResponse.error, statusCode: httpResponse.statusCode)
                } else {
                    throw ClaudeAPIError.serverError(httpResponse.statusCode)
                }
            }
            
        } catch let error as ClaudeAPIError {
            throw error
        } catch {
            print("❌ [ClaudeAPIService] 네트워크 오류: \(error)")
            throw ClaudeAPIError.networkError(error)
        }
    }
    
    // MARK: - Response Parsing
    
    private func parseCardsFromResponse(_ responseText: String, config: SummaryConfig) throws -> [SummaryResult.CardContent] {
        print("🔍 [ClaudeAPIService] 응답 파싱 시작")
        print("📝 [ClaudeAPIService] 응답 내용: \(responseText.prefix(500))...")
        
        // 여러 방법으로 JSON 추출 시도
        var jsonText: String = ""
        
        // 방법 1: ```json ``` 블록 찾기
        if let startRange = responseText.range(of: "```json"),
           let endRange = responseText.range(of: "```", range: startRange.upperBound..<responseText.endIndex) {
            
            let fullRange = startRange.upperBound..<endRange.lowerBound
            jsonText = String(responseText[fullRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            print("🔍 [ClaudeAPIService] 방법 1: JSON 블록 발견")
            
        } 
        // 방법 2: { } 객체 찾기
        else if let startBrace = responseText.firstIndex(of: "{"),
                let lastBrace = responseText.lastIndex(of: "}") {
            
            jsonText = String(responseText[startBrace...lastBrace])
            print("🔍 [ClaudeAPIService] 방법 2: JSON 객체 발견")
            
        }
        // 방법 3: 직접 JSON으로 파싱 시도
        else {
            jsonText = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
            print("🔍 [ClaudeAPIService] 방법 3: 전체 응답을 JSON으로 시도")
        }
        
        print("🔍 [ClaudeAPIService] 추출된 JSON: \(jsonText.prefix(200))...")
        
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw ClaudeAPIError.decodingError(NSError(domain: "JSONParsingError", code: 2, userInfo: [NSLocalizedDescriptionKey: "JSON 데이터 변환 실패"]))
        }
        
        do {
            let parsedResponse = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            guard let cardsArray = parsedResponse?["cards"] as? [[String: Any]] else {
                throw ClaudeAPIError.decodingError(NSError(domain: "JSONParsingError", code: 3, userInfo: [NSLocalizedDescriptionKey: "cards 배열을 찾을 수 없습니다."]))
            }
            
            let cards = cardsArray.compactMap { cardDict -> SummaryResult.CardContent? in
                guard let cardNumber = cardDict["cardNumber"] as? Int,
                      let title = cardDict["title"] as? String,
                      let content = cardDict["content"] as? String else {
                    return nil
                }
                
                return SummaryResult.CardContent(
                    cardNumber: cardNumber,
                    title: title,
                    content: content,
                    imagePrompt: cardDict["imagePrompt"] as? String,
                    backgroundColor: cardDict["backgroundColor"] as? String ?? "#FFFFFF",
                    textColor: cardDict["textColor"] as? String ?? "#000000"
                )
            }
            
            print("🎉 [ClaudeAPIService] \(cards.count)장의 카드 파싱 완료 (목표: \(config.cardCount.rawValue)장)")
            return cards
            
        } catch {
            print("❌ [ClaudeAPIService] JSON 파싱 실패: \(error)")
            print("📝 [ClaudeAPIService] 파싱 시도한 JSON: \(jsonText)")
            throw ClaudeAPIError.decodingError(error)
        }
    }
    
    // MARK: - Card Count Validation
    
    private func validateAndFixCardCount(cards: [SummaryResult.CardContent], expectedCount: Int) -> [SummaryResult.CardContent] {
        print("🔍 [ClaudeAPIService] 카드 수 검증: \(cards.count)개 (목표: \(expectedCount)개)")
        
        if cards.count == expectedCount {
            print("✅ [ClaudeAPIService] 카드 수 정확함")
            return cards
        }
        
        // 카드가 부족한 경우
        if cards.count < expectedCount {
            print("⚠️ [ClaudeAPIService] 카드 부족 - 추가 생성")
            var fixedCards = cards
            
            for i in cards.count..<expectedCount {
                let additionalCard = SummaryResult.CardContent(
                    cardNumber: i + 1,
                    title: "추가 요약 \(i + 1)",
                    content: "이 카드는 자동으로 생성된 추가 요약입니다.",
                    imagePrompt: nil,
                    backgroundColor: "#FFFFFF",
                    textColor: "#000000"
                )
                fixedCards.append(additionalCard)
            }
            
            return fixedCards
        }
        
        // 카드가 초과된 경우
        if cards.count > expectedCount {
            print("⚠️ [ClaudeAPIService] 카드 초과 - 잘라내기")
            return Array(cards.prefix(expectedCount))
        }
        
        return cards
    }
    
    // MARK: - Summary Storage
    
    private func saveSummaryResult(_ result: SummaryResult) {
        // UserDefaults를 사용한 간단한 저장 (추후 CoreData로 업그레이드)
        var summaries = loadSavedSummaries()
        summaries.insert(result, at: 0) // 최신 항목을 앞에 추가
        
        // 최대 10개까지만 저장
        if summaries.count > 10 {
            summaries = Array(summaries.prefix(10))
        }
        
        do {
            let data = try JSONEncoder().encode(summaries.map { EncodableSummaryResult(from: $0) })
            UserDefaults.standard.set(data, forKey: "saved_summaries")
            print("✅ [ClaudeAPIService] 요약 결과 저장 완료")
        } catch {
            print("❌ [ClaudeAPIService] 요약 결과 저장 실패: \(error)")
        }
    }
    
    // 저장된 요약 로드
    func loadSavedSummaries() -> [SummaryResult] {
        guard let data = UserDefaults.standard.data(forKey: "saved_summaries") else {
            return []
        }
        
        do {
            let encodableSummaries = try JSONDecoder().decode([EncodableSummaryResult].self, from: data)
            return encodableSummaries.map { $0.toSummaryResult() }
        } catch {
            print("❌ [ClaudeAPIService] 저장된 요약 로드 실패: \(error)")
            return []
        }
    }
    
    // MARK: - Error Mapping
    
    private func mapAPIError(_ error: ClaudeError, statusCode: Int) -> ClaudeAPIError {
        switch statusCode {
        case 401:
            return .invalidAPIKey
        case 400:
            return .invalidRequest
        case 429:
            return .rateLimitExceeded
        case 402:
            return .insufficientCredits
        default:
            return .serverError(statusCode)
        }
    }
    
    // MARK: - Utility Methods
    
    func validateConfiguration() -> Bool {
        return isConfigured && !apiKey.isEmpty
    }
    
    func estimateTokens(for text: String) -> Int {
        // 대략적인 토큰 계산 (1토큰 ≈ 4글자)
        return text.count / 4
    }
}

// MARK: - Encodable Helper for Storage

private struct EncodableSummaryResult: Codable {
    let id: String
    let cardCount: Int
    let outputStyle: String
    let language: String
    let tone: String
    let fileName: String
    let fileSize: Int
    let fileType: String
    let uploadedAt: Date
    let cards: [EncodableCardContent]
    let createdAt: Date
    let tokensUsed: Int
    
    init(from result: SummaryResult) {
        self.id = result.id
        self.cardCount = result.config.cardCount.rawValue
        self.outputStyle = result.config.outputStyle.rawValue
        self.language = result.config.language.rawValue
        self.tone = result.config.tone.rawValue
        self.fileName = result.originalDocument.fileName
        self.fileSize = result.originalDocument.fileSize
        self.fileType = result.originalDocument.fileType
        self.uploadedAt = result.originalDocument.uploadedAt
        self.cards = result.cards.map { EncodableCardContent(from: $0) }
        self.createdAt = result.createdAt
        self.tokensUsed = result.tokensUsed
    }
    
    func toSummaryResult() -> SummaryResult {
        let documentInfo = DocumentInfo(
            fileName: fileName,
            fileSize: fileSize,
            fileType: fileType
        )
        
        let config = SummaryConfig(
            cardCount: SummaryConfig.CardCount(rawValue: cardCount) ?? .four,
            outputStyle: SummaryConfig.OutputStyle(rawValue: outputStyle) ?? .text,
            language: SummaryConfig.SummaryLanguage(rawValue: language) ?? .korean,
            tone: SummaryConfig.SummaryTone(rawValue: tone) ?? .friendly
        )
        
        return SummaryResult(
            id: id,
            config: config,
            originalDocument: documentInfo,
            cards: cards.map { $0.toCardContent() },
            createdAt: createdAt,
            tokensUsed: tokensUsed
        )
    }
}

private struct EncodableCardContent: Codable {
    let cardNumber: Int
    let title: String
    let content: String
    let imagePrompt: String?
    let backgroundColor: String?
    let textColor: String?
    
    init(from card: SummaryResult.CardContent) {
        self.cardNumber = card.cardNumber
        self.title = card.title
        self.content = card.content
        self.imagePrompt = card.imagePrompt
        self.backgroundColor = card.backgroundColor
        self.textColor = card.textColor
    }
    
    func toCardContent() -> SummaryResult.CardContent {
        return SummaryResult.CardContent(
            cardNumber: cardNumber,
            title: title,
            content: content,
            imagePrompt: imagePrompt,
            backgroundColor: backgroundColor,
            textColor: textColor
        )
    }
}
