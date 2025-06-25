import Foundation

// MARK: - Claude API Request Models

struct ClaudeRequest: Codable {
    let model: String
    let maxTokens: Int
    let messages: [ClaudeMessage]
    let system: String?
    
    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
        case system
    }
}

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

// MARK: - Claude API Response Models

struct ClaudeResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ClaudeContent]
    let model: String
    let stopReason: String?
    let stopSequence: String?
    let usage: ClaudeUsage
    
    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
        case usage
    }
}

struct ClaudeContent: Codable {
    let type: String
    let text: String
}

struct ClaudeUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

// MARK: - Claude API Error Models

struct ClaudeErrorResponse: Codable {
    let type: String
    let error: ClaudeError
}

struct ClaudeError: Codable {
    let type: String
    let message: String
}

// MARK: - Summary Result Models

struct SummaryResult {
    let id: String
    let config: SummaryConfig
    let originalDocument: DocumentInfo
    let cards: [CardContent]
    let createdAt: Date
    let tokensUsed: Int
    
    struct CardContent {
        let cardNumber: Int
        let title: String
        let content: String
        let imagePrompt: String? // AI 이미지 생성용 프롬프트
        let backgroundColor: String?
        let textColor: String?
    }
}

// MARK: - API Configuration

struct ClaudeAPIConfig {
    static let baseURL = "https://api.anthropic.com/v1"
    static let model = "claude-3-5-sonnet-20241022"
    static let version = "2023-06-01"
    
    // 토큰 제한
    static let maxInputTokens = 180000  // Claude 3.5 Sonnet 입력 제한
    static let maxOutputTokens = 8192   // 출력 제한
    
    // 요약 설정
    static let defaultMaxTokens = 4000  // 카드뉴스 요약용
}

// MARK: - API Error Types

enum ClaudeAPIError: LocalizedError {
    case invalidAPIKey
    case invalidRequest
    case rateLimitExceeded
    case insufficientCredits
    case serverError(Int)
    case networkError(Error)
    case decodingError(Error)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "API 키가 유효하지 않습니다. 설정을 확인해주세요."
        case .invalidRequest:
            return "잘못된 요청입니다. 요청 형식을 확인해주세요."
        case .rateLimitExceeded:
            return "API 호출 한도를 초과했습니다. 잠시 후 다시 시도해주세요."
        case .insufficientCredits:
            return "API 크레딧이 부족합니다. 계정을 확인해주세요."
        case .serverError(let code):
            return "서버 오류가 발생했습니다. (코드: \(code))"
        case .networkError(let error):
            return "네트워크 오류: \(error.localizedDescription)"
        case .decodingError(let error):
            return "응답 처리 오류: \(error.localizedDescription)"
        case .unknown(let message):
            return "알 수 없는 오류: \(message)"
        }
    }
}
