import Foundation

// 업로드된 원본 문서 정보
struct DocumentInfo {
    let id: UUID
    let fileName: String
    let fileType: String
    let fileSize: Int64
    let filePath: URL
    let uploadedAt: Date
    
    init(fileName: String, fileType: String, fileSize: Int64, filePath: URL) {
        self.id = UUID()
        self.fileName = fileName
        self.fileType = fileType
        self.fileSize = fileSize
        self.filePath = filePath
        self.uploadedAt = Date()
    }
}

// 처리된 문서 내용
struct ProcessedDocument {
    let id: UUID
    let originalDocument: DocumentInfo
    let content: String
    let wordCount: Int
    let characterCount: Int
    let processedAt: Date
    let preview: String
    
    init(originalDocument: DocumentInfo, content: String) {
        self.id = UUID()
        self.originalDocument = originalDocument
        self.content = content
        self.wordCount = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
        self.characterCount = content.count
        self.processedAt = Date()
        
        // 미리보기 텍스트 생성 (처음 200자)
        if content.count > 200 {
            self.preview = String(content.prefix(200)) + "..."
        } else {
            self.preview = content
        }
    }
}

// 요약 설정
struct SummaryConfig {
    let cardCount: CardCount
    let outputStyle: OutputStyle
    let language: SupportedLanguage
    
    enum CardCount: Int, CaseIterable {
        case four = 4
        case six = 6
        case eight = 8
        
        var displayName: String {
            return "\(self.rawValue)컷"
        }
        
        var description: String {
            switch self {
            case .four:
                return "핵심 내용 요약"
            case .six:
                return "표준 길이 요약"
            case .eight:
                return "상세 길이 요약"
            }
        }
    }
    
    enum OutputStyle: String, CaseIterable {
        case webtoon = "webtoon"
        case text = "text"
        case infographic = "infographic"
        
        var displayName: String {
            switch self {
            case .webtoon:
                return "웹툰 형식"
            case .text:
                return "텍스트 형식"
            case .infographic:
                return "인포그래픽 형식"
            }
        }
        
        var description: String {
            switch self {
            case .webtoon:
                return "말풍선과 캐릭터를 활용한 스토리텔링"
            case .text:
                return "깔끔한 텍스트 기반 카드"
            case .infographic:
                return "시각적 요소가 포함된 정보 그래픽"
            }
        }
        
        var icon: String {
            switch self {
            case .webtoon:
                return "person.2.badge.gearshape"
            case .text:
                return "text.alignleft"
            case .infographic:
                return "chart.bar.fill"
            }
        }
    }
    
    enum SupportedLanguage: String, CaseIterable {
        case korean = "ko"
        case english = "en"
        
        var displayName: String {
            switch self {
            case .korean:
                return "한국어"
            case .english:
                return "English"
            }
        }
    }
}

// 생성된 카드뉴스
struct CardNews {
    let id: UUID
    let originalDocument: DocumentInfo
    let config: SummaryConfig
    let cards: [Card]
    let createdAt: Date
    
    init(originalDocument: DocumentInfo, config: SummaryConfig, cards: [Card]) {
        self.id = UUID()
        self.originalDocument = originalDocument
        self.config = config
        self.cards = cards
        self.createdAt = Date()
    }
}

// 개별 카드
struct Card {
    let id: UUID
    let sequence: Int
    let title: String
    let content: String
    let imageData: Data? // 이미지나 인포그래픽용
    
    init(sequence: Int, title: String, content: String, imageData: Data? = nil) {
        self.id = UUID()
        self.sequence = sequence
        self.title = title
        self.content = content
        self.imageData = imageData
    }
}
