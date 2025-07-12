import Foundation

// MARK: - Enhanced Document Picker Errors - 다국어 지원

enum DocumentPickerError: LocalizedError, CustomStringConvertible {
    case userCancelled
    case noFileSelected
    case unsupportedFileType
    case viewServiceError
    case fileAccessDenied
    case fileCorrupted
    case securityScopedResourceFailed
    
    var errorDescription: String? {
        let isKorean = Locale.current.language.languageCode?.identifier == "ko"
        
        switch self {
        case .userCancelled:
            return isKorean ? "파일 선택이 취소되었습니다" : "File selection was cancelled"
        case .noFileSelected:
            return isKorean ? "파일이 선택되지 않았습니다" : "No file was selected"
        case .unsupportedFileType:
            return isKorean ? "지원하지 않는 파일 형식입니다. PDF 또는 Word(.docx) 파일만 업로드 가능합니다." : "Unsupported file format. Only PDF and Word (.docx) files are supported."
        case .viewServiceError:
            return isKorean ? "파일 선택 중 시스템 오류가 발생했습니다" : "A system error occurred during file selection"
        case .fileAccessDenied:
            return isKorean ? "파일에 접근할 수 없습니다. 권한을 확인해주세요" : "Cannot access the file. Please check permissions"
        case .fileCorrupted:
            return isKorean ? "파일이 손상되었거나 읽을 수 없습니다" : "The file is corrupted or cannot be read"
        case .securityScopedResourceFailed:
            return isKorean ? "파일 보안 접근 권한을 얻을 수 없습니다" : "Cannot obtain security access to the file"
        }
    }
    
    var description: String {
        return errorDescription ?? (Locale.current.language.languageCode?.identifier == "ko" ? "알 수 없는 오류" : "Unknown error")
    }
}