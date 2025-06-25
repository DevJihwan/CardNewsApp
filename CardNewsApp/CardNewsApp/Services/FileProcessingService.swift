import Foundation
import PDFKit
import ZIPFoundation

// 파일 처리 에러 타입
enum FileProcessingError: LocalizedError {
    case unsupportedFileType
    case fileReadError
    case pdfProcessingError
    case wordProcessingError
    case emptyContent
    case corruptedFile
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "지원하지 않는 파일 형식입니다."
        case .fileReadError:
            return "파일을 읽을 수 없습니다."
        case .pdfProcessingError:
            return "PDF 파일 처리 중 오류가 발생했습니다."
        case .wordProcessingError:
            return "Word 파일 처리 중 오류가 발생했습니다."
        case .emptyContent:
            return "문서에 텍스트 내용이 없습니다."
        case .corruptedFile:
            return "손상된 파일입니다."
        }
    }
}

// 파일 처리 서비스 클래스
class FileProcessingService: ObservableObject {
    
    // 지원하는 파일 형식
    private let supportedExtensions = ["pdf", "docx", "doc"]
    
    // 메인 처리 함수
    func processDocument(from url: URL) async throws -> ProcessedDocument {
        let fileName = url.lastPathComponent
        let fileExtension = url.pathExtension.lowercased()
        
        // 파일 형식 확인
        guard supportedExtensions.contains(fileExtension) else {
            throw FileProcessingError.unsupportedFileType
        }
        
        // 파일 접근 권한 확인
        guard url.startAccessingSecurityScopedResource() else {
            throw FileProcessingError.fileReadError
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            // 파일 크기 정보 얻기
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            let fileSize = resourceValues.fileSize ?? 0 // Int 타입으로 변경
            
            // DocumentInfo 생성 - 수정된 생성자 사용
            let documentInfo = DocumentInfo(
                fileName: fileName,
                fileSize: fileSize, // Int 타입
                fileType: fileExtension.uppercased()
                // filePath 매개변수 제거됨
            )
            
            let content: String
            
            switch fileExtension {
            case "pdf":
                content = try await processPDFFile(url: url)
            case "docx":
                content = try await processDocxFile(url: url)
            case "doc":
                // .doc 파일은 복잡한 바이너리 형식이므로 제한적 지원
                throw FileProcessingError.unsupportedFileType
            default:
                throw FileProcessingError.unsupportedFileType
            }
            
            // 빈 내용 체크
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedContent.isEmpty else {
                throw FileProcessingError.emptyContent
            }
            
            // ProcessedDocument 생성 (DocumentModel 사용)
            return ProcessedDocument(originalDocument: documentInfo, content: trimmedContent)
            
        } catch {
            if error is FileProcessingError {
                throw error
            } else {
                throw FileProcessingError.fileReadError
            }
        }
    }
    
    // MARK: - PDF 파일 처리
    private func processPDFFile(url: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    guard let pdfDocument = PDFDocument(url: url) else {
                        continuation.resume(throwing: FileProcessingError.pdfProcessingError)
                        return
                    }
                    
                    let pageCount = pdfDocument.pageCount
                    var extractedText = ""
                    
                    // 각 페이지에서 텍스트 추출
                    for pageIndex in 0..<pageCount {
                        guard let page = pdfDocument.page(at: pageIndex) else { continue }
                        
                        if let pageText = page.string {
                            extractedText += pageText + "\n"
                        }
                    }
                    
                    // 텍스트 정리
                    let cleanedText = self.cleanExtractedText(extractedText)
                    
                    continuation.resume(returning: cleanedText)
                    
                } catch {
                    continuation.resume(throwing: FileProcessingError.pdfProcessingError)
                }
            }
        }
    }
    
    // MARK: - Word(.docx) 파일 처리
    private func processDocxFile(url: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // .docx 파일을 ZIP으로 읽기
                    let fileManager = FileManager.default
                    let tempDirectory = fileManager.temporaryDirectory
                    let extractPath = tempDirectory.appendingPathComponent(UUID().uuidString)
                    
                    // ZIP 압축 해제 (ZipFoundation 사용)
                    try fileManager.createDirectory(at: extractPath, withIntermediateDirectories: true)
                    
                    guard let archive = Archive(url: url, accessMode: .read) else {
                        try? fileManager.removeItem(at: extractPath)
                        continuation.resume(throwing: FileProcessingError.wordProcessingError)
                        return
                    }
                    
                    // document.xml 파일 찾기 및 추출
                    guard let documentEntry = archive["word/document.xml"] else {
                        try? fileManager.removeItem(at: extractPath)
                        continuation.resume(throwing: FileProcessingError.wordProcessingError)
                        return
                    }
                    
                    var xmlContent = ""
                    _ = try archive.extract(documentEntry) { data in
                        xmlContent += String(data: data, encoding: .utf8) ?? ""
                    }
                    
                    // XML에서 텍스트 추출
                    let extractedText = self.extractTextFromWordXML(xmlContent)
                    
                    // 임시 파일 정리
                    try? fileManager.removeItem(at: extractPath)
                    
                    continuation.resume(returning: extractedText)
                    
                } catch {
                    continuation.resume(throwing: FileProcessingError.wordProcessingError)
                }
            }
        }
    }
    
    // MARK: - Word XML에서 텍스트 추출
    private func extractTextFromWordXML(_ xmlContent: String) -> String {
        var extractedText = ""
        
        // <w:t> 태그 내의 텍스트 추출
        let pattern = "<w:t[^>]*>(.*?)</w:t>"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: xmlContent.utf16.count)
            
            let matches = regex.matches(in: xmlContent, options: [], range: range)
            
            for match in matches {
                if match.numberOfRanges > 1 {
                    let matchRange = match.range(at: 1)
                    if let swiftRange = Range(matchRange, in: xmlContent) {
                        let text = String(xmlContent[swiftRange])
                        // XML 엔티티 디코딩
                        let decodedText = text
                            .replacingOccurrences(of: "&lt;", with: "<")
                            .replacingOccurrences(of: "&gt;", with: ">")
                            .replacingOccurrences(of: "&amp;", with: "&")
                            .replacingOccurrences(of: "&quot;", with: "\"")
                            .replacingOccurrences(of: "&apos;", with: "'")
                        
                        extractedText += decodedText
                    }
                }
            }
            
            // 단락 구분 추가
            extractedText = extractedText.replacingOccurrences(of: "</w:p>", with: "\n")
            
        } catch {
            print("정규식 처리 오류: \(error)")
        }
        
        return cleanExtractedText(extractedText)
    }
    
    // MARK: - 추출된 텍스트 정리
    private func cleanExtractedText(_ text: String) -> String {
        return text
            // 중복 공백 제거
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            // 중복 줄바꿈 제거
            .replacingOccurrences(of: "\\n+", with: "\n", options: .regularExpression)
            // 앞뒤 공백 제거
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - 텍스트 미리보기 생성
    func generatePreview(from content: String, maxLength: Int = 200) -> String {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedContent.count <= maxLength {
            return trimmedContent
        }
        
        let preview = String(trimmedContent.prefix(maxLength))
        return preview + "..."
    }
    
    // MARK: - 파일 정보 유효성 검사
    func validateFile(at url: URL) -> (isValid: Bool, error: FileProcessingError?) {
        let fileExtension = url.pathExtension.lowercased()
        
        // 지원하는 형식인지 확인
        guard supportedExtensions.contains(fileExtension) else {
            return (false, .unsupportedFileType)
        }
        
        // 파일 존재 확인
        do {
            guard try url.checkResourceIsReachable() else {
                return (false, .fileReadError)
            }
        } catch {
            return (false, .fileReadError)
        }
        
        return (true, nil)
    }
}
