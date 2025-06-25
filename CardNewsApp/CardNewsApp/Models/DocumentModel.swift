import Foundation

// 업로드된 원본 문서 정보
struct DocumentInfo {
    let fileName: String
    let fileSize: Int
    let fileType: String
    let uploadedAt: Date
    
    init(fileName: String, fileSize: Int, fileType: String) {
        self.fileName = fileName
        self.fileSize = fileSize
        self.fileType = fileType
        self.uploadedAt = Date()
    }
}

// 처리된 문서 내용
struct ProcessedDocument {
    let id: String
    let originalDocument: DocumentInfo
    let content: String
    let wordCount: Int
    let characterCount: Int
    let processedAt: Date
    
    init(originalDocument: DocumentInfo, content: String) {
        self.id = UUID().uuidString
        self.originalDocument = originalDocument
        self.content = content
        self.wordCount = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
        self.characterCount = content.count
        self.processedAt = Date()
    }
}

// 요약 설정
struct SummaryConfig {
    let cardCount: CardCount
    let outputStyle: OutputStyle
    let language: SummaryLanguage
    let tone: SummaryTone
    
    enum CardCount: Int, CaseIterable {
        case four = 4
        case six = 6
        case eight = 8
        
        var displayName: String {
            switch self {
            case .four: return "4컷"
            case .six: return "6컷"
            case .eight: return "8컷"
            }
        }
    }
    
    enum OutputStyle: String, CaseIterable {
        case webtoon = "webtoon"
        case text = "text"
        case image = "image"
        
        var displayName: String {
            switch self {
            case .webtoon: return "웹툰 스타일"
            case .text: return "텍스트 위주"
            case .image: return "이미지 위주"
            }
        }
        
        var description: String {
            switch self {
            case .webtoon: return "대화체와 감정 표현이 풍부한 웹툰 형태"
            case .text: return "핵심 내용을 간결하게 정리한 텍스트"
            case .image: return "시각적 요소와 키워드 중심의 구성"
            }
        }
    }
    
    enum SummaryLanguage: String, CaseIterable {
        case korean = "ko"
        case english = "en"
        case japanese = "ja"
        
        var displayName: String {
            switch self {
            case .korean: return "한국어"
            case .english: return "English"
            case .japanese: return "日本語"
            }
        }
    }
    
    enum SummaryTone: String, CaseIterable {
        case professional = "professional"
        case casual = "casual"
        case academic = "academic"
        case friendly = "friendly"
        
        var displayName: String {
            switch self {
            case .professional: return "전문적"
            case .casual: return "캐주얼"
            case .academic: return "학술적"
            case .friendly: return "친근한"
            }
        }
    }
}
