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
    case permissionDenied
    
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
        case .permissionDenied:
            return "파일 접근 권한이 없습니다."
        }
    }
}

// 파일 처리 서비스 클래스 - iPhone/iPad 호환성 개선
class FileProcessingService: ObservableObject {
    
    // 지원하는 파일 형식
    private let supportedExtensions = ["pdf", "docx", "doc"]
    
    // 재시도 설정 - iPad 호환성 강화
    private let maxRetryCount = 3
    private let retryDelay: UInt64 = 1_000_000_000 // 1초 (iPad에서 더 긴 지연 필요)
    
    // 메인 처리 함수 - iPad 호환성 개선
    func processDocument(from url: URL) async throws -> ProcessedDocument {
        let deviceType = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        print("🔍 [FileProcessingService] 문서 처리 시작: \(url.lastPathComponent)")
        print("🔍 [FileProcessingService] 기기 정보: \(deviceType) - \(UIDevice.current.systemVersion)")
        
        let fileName = url.lastPathComponent
        let fileExtension = url.pathExtension.lowercased()
        
        // 파일 형식 확인
        guard supportedExtensions.contains(fileExtension) else {
            print("❌ [FileProcessingService] 지원하지 않는 파일 형식: \(fileExtension)")
            throw FileProcessingError.unsupportedFileType
        }
        
        // iPad/iPhone에서 안정적인 처리를 위한 재시도 로직
        for attempt in 1...maxRetryCount {
            do {
                print("🔍 [FileProcessingService] 처리 시도 \(attempt)/\(maxRetryCount) - 기기: \(deviceType)")
                
                let result = try await processDocumentInternal(url: url, fileName: fileName, fileExtension: fileExtension)
                print("✅ [FileProcessingService] 문서 처리 성공 (시도 \(attempt)) - 기기: \(deviceType)")
                return result
                
            } catch FileProcessingError.permissionDenied, FileProcessingError.fileReadError {
                if attempt < maxRetryCount {
                    print("⏳ [FileProcessingService] 파일 접근 재시도 중... (\(attempt)/\(maxRetryCount)) - 기기: \(deviceType)")
                    try await Task.sleep(nanoseconds: retryDelay)
                    continue
                } else {
                    print("❌ [FileProcessingService] 최종 실패 - 파일 접근 불가 - 기기: \(deviceType)")
                    throw FileProcessingError.permissionDenied
                }
            } catch {
                if attempt < maxRetryCount {
                    print("⏳ [FileProcessingService] 처리 재시도 중... (\(attempt)/\(maxRetryCount)) - 기기: \(deviceType): \(error)")
                    try await Task.sleep(nanoseconds: retryDelay)
                    continue
                } else {
                    print("❌ [FileProcessingService] 최종 실패 - 기기: \(deviceType): \(error)")
                    throw error
                }
            }
        }
        
        throw FileProcessingError.fileReadError
    }
    
    // 내부 처리 함수 - iPad 호환성 강화
    private func processDocumentInternal(url: URL, fileName: String, fileExtension: String) async throws -> ProcessedDocument {
        
        let deviceType = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        let isInAppSandbox = isFileInAppSandbox(url: url)
        print("🔍 [FileProcessingService] 앱 샌드박스 내 파일: \(isInAppSandbox) - 기기: \(deviceType)")
        
        var needsSecurityScoped = false
        
        // Security-Scoped Resource 처리 - iPad 호환성 개선
        if !isInAppSandbox {
            // iPad에서는 보안 스코프 접근이 더 엄격할 수 있으므로 추가 검증
            let hasAccess = url.startAccessingSecurityScopedResource()
            
            if !hasAccess {
                print("❌ [FileProcessingService] Security-Scoped Resource 접근 실패 - 기기: \(deviceType)")
                
                // iPad 특별 처리: 파일 복사 시도
                if UIDevice.current.userInterfaceIdiom == .pad {
                    return try await handleIPadFileAccess(url: url, fileName: fileName, fileExtension: fileExtension)
                } else {
                    throw FileProcessingError.permissionDenied
                }
            }
            
            needsSecurityScoped = true
            print("🔐 [FileProcessingService] Security-Scoped Resource 접근 시작 - 기기: \(deviceType)")
        }
        
        defer {
            if needsSecurityScoped {
                url.stopAccessingSecurityScopedResource()
                print("🔓 [FileProcessingService] Security-Scoped Resource 접근 종료 - 기기: \(deviceType)")
            }
        }
        
        return try await processFileWithAccess(url: url, fileName: fileName, fileExtension: fileExtension, deviceType: deviceType)
    }
    
    // iPad 전용 파일 접근 처리
    private func handleIPadFileAccess(url: URL, fileName: String, fileExtension: String) async throws -> ProcessedDocument {
        print("🔍 [FileProcessingService] iPad 전용 파일 접근 처리 시작")
        
        // 임시 디렉토리에 파일 복사 시도
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempURL = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)
        
        do {
            // 원본 파일 데이터 읽기 시도
            let fileData = try Data(contentsOf: url)
            try fileData.write(to: tempURL)
            
            print("✅ [FileProcessingService] iPad: 임시 파일 생성 성공")
            
            // 임시 파일로 처리
            let result = try await processFileWithAccess(url: tempURL, fileName: fileName, fileExtension: fileExtension, deviceType: "iPad")
            
            // 임시 파일 정리
            try? FileManager.default.removeItem(at: tempURL)
            
            return result
            
        } catch {
            print("❌ [FileProcessingService] iPad: 파일 복사 실패: \(error)")
            // 임시 파일 정리
            try? FileManager.default.removeItem(at: tempURL)
            throw FileProcessingError.permissionDenied
        }
    }
    
    // 실제 파일 처리 로직
    private func processFileWithAccess(url: URL, fileName: String, fileExtension: String, deviceType: String) async throws -> ProcessedDocument {
        do {
            // 파일 존재 및 읽기 권한 확인
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("❌ [FileProcessingService] 파일이 존재하지 않음: \(url.path) - 기기: \(deviceType)")
                throw FileProcessingError.fileReadError
            }
            
            // 파일 접근성 확인
            do {
                _ = try url.checkResourceIsReachable()
            } catch {
                print("❌ [FileProcessingService] 파일 접근 불가: \(error) - 기기: \(deviceType)")
                throw FileProcessingError.fileReadError
            }
            
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                print("❌ [FileProcessingService] 파일 읽기 권한 없음 - 기기: \(deviceType)")
                throw FileProcessingError.permissionDenied
            }
            
            // 파일 크기 정보 얻기
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            let fileSize = resourceValues.fileSize ?? 0
            
            print("✅ [FileProcessingService] 파일 정보 확인 완료: \(fileSize) bytes - 기기: \(deviceType)")
            
            // DocumentInfo 생성
            let documentInfo = DocumentInfo(
                fileName: fileName,
                fileSize: fileSize,
                fileType: fileExtension.uppercased()
            )
            
            let content: String
            
            switch fileExtension {
            case "pdf":
                print("🔍 [FileProcessingService] PDF 파일 처리 시작 - 기기: \(deviceType)")
                content = try await processPDFFile(url: url)
            case "docx":
                print("🔍 [FileProcessingService] DOCX 파일 처리 시작 - 기기: \(deviceType)")
                content = try await processDocxFile(url: url)
            case "doc":
                // .doc 파일은 복잡한 바이너리 형식이므로 제한적 지원
                print("❌ [FileProcessingService] DOC 파일은 지원하지 않음 - 기기: \(deviceType)")
                throw FileProcessingError.unsupportedFileType
            default:
                throw FileProcessingError.unsupportedFileType
            }
            
            // 빈 내용 체크
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedContent.isEmpty else {
                print("❌ [FileProcessingService] 추출된 내용이 비어있음 - 기기: \(deviceType)")
                throw FileProcessingError.emptyContent
            }
            
            print("✅ [FileProcessingService] 문서 처리 완료: \(trimmedContent.count)자 - 기기: \(deviceType)")
            
            // ProcessedDocument 생성
            return ProcessedDocument(originalDocument: documentInfo, content: trimmedContent)
            
        } catch {
            print("❌ [FileProcessingService] 문서 처리 오류: \(error) - 기기: \(deviceType)")
            if error is FileProcessingError {
                throw error
            } else {
                throw FileProcessingError.fileReadError
            }
        }
    }
    
    // 파일이 앱 샌드박스에 있는지 확인 - iPad 호환성 개선
    private func isFileInAppSandbox(url: URL) -> Bool {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        
        let isInSandbox = url.path.contains(bundleIdentifier) ||
                         url.path.contains("/tmp/") ||
                         url.path.contains("/Documents/") ||
                         url.path.contains("/Library/")
        
        let deviceType = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        print("🔍 [FileProcessingService] 샌드박스 확인: \(isInSandbox) - 기기: \(deviceType) - 경로: \(url.path)")
        return isInSandbox
    }
    
    // MARK: - PDF 파일 처리
    private func processPDFFile(url: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    guard let pdfDocument = PDFDocument(url: url) else {
                        print("❌ [FileProcessingService] PDF 문서를 열 수 없음")
                        continuation.resume(throwing: FileProcessingError.pdfProcessingError)
                        return
                    }
                    
                    let pageCount = pdfDocument.pageCount
                    guard pageCount > 0 else {
                        print("❌ [FileProcessingService] PDF 페이지가 없음")
                        continuation.resume(throwing: FileProcessingError.emptyContent)
                        return
                    }
                    
                    var extractedText = ""
                    
                    print("🔍 [FileProcessingService] PDF 페이지 수: \(pageCount)")
                    
                    // 각 페이지에서 텍스트 추출
                    for pageIndex in 0..<pageCount {
                        autoreleasepool {
                            guard let page = pdfDocument.page(at: pageIndex) else { 
                                print("⚠️ [FileProcessingService] 페이지 \(pageIndex) 로드 실패")
                                return 
                            }
                            
                            if let pageText = page.string {
                                extractedText += pageText + "\n"
                            }
                        }
                    }
                    
                    // 텍스트 정리
                    let cleanedText = self.cleanExtractedText(extractedText)
                    
                    guard !cleanedText.isEmpty else {
                        print("❌ [FileProcessingService] PDF에서 텍스트 추출 실패")
                        continuation.resume(throwing: FileProcessingError.emptyContent)
                        return
                    }
                    
                    print("✅ [FileProcessingService] PDF 텍스트 추출 완료: \(cleanedText.count)자")
                    
                    continuation.resume(returning: cleanedText)
                    
                } catch {
                    print("❌ [FileProcessingService] PDF 처리 오류: \(error)")
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
                    
                    print("🔍 [FileProcessingService] DOCX 파일 압축 해제 시작")
                    
                    // ZIP 압축 해제 (ZipFoundation 사용)
                    do {
                        try fileManager.createDirectory(at: extractPath, withIntermediateDirectories: true)
                    } catch {
                        print("❌ [FileProcessingService] 임시 디렉토리 생성 실패: \(error)")
                        continuation.resume(throwing: FileProcessingError.wordProcessingError)
                        return
                    }
                    
                    guard let archive = Archive(url: url, accessMode: .read) else {
                        try? fileManager.removeItem(at: extractPath)
                        print("❌ [FileProcessingService] DOCX 아카이브를 열 수 없음")
                        continuation.resume(throwing: FileProcessingError.wordProcessingError)
                        return
                    }
                    
                    // document.xml 파일 찾기 및 추출
                    guard let documentEntry = archive["word/document.xml"] else {
                        try? fileManager.removeItem(at: extractPath)
                        print("❌ [FileProcessingService] document.xml을 찾을 수 없음")
                        continuation.resume(throwing: FileProcessingError.wordProcessingError)
                        return
                    }
                    
                    var xmlContent = ""
                    do {
                        _ = try archive.extract(documentEntry) { data in
                            xmlContent += String(data: data, encoding: .utf8) ?? ""
                        }
                    } catch {
                        try? fileManager.removeItem(at: extractPath)
                        print("❌ [FileProcessingService] XML 추출 실패: \(error)")
                        continuation.resume(throwing: FileProcessingError.wordProcessingError)
                        return
                    }
                    
                    print("🔍 [FileProcessingService] XML 데이터 추출 완료: \(xmlContent.count)자")
                    
                    // XML에서 텍스트 추출
                    let extractedText = self.extractTextFromWordXML(xmlContent)
                    
                    // 임시 파일 정리
                    try? fileManager.removeItem(at: extractPath)
                    
                    guard !extractedText.isEmpty else {
                        print("❌ [FileProcessingService] DOCX에서 텍스트 추출 실패")
                        continuation.resume(throwing: FileProcessingError.emptyContent)
                        return
                    }
                    
                    print("✅ [FileProcessingService] DOCX 텍스트 추출 완료: \(extractedText.count)자")
                    
                    continuation.resume(returning: extractedText)
                    
                } catch {
                    print("❌ [FileProcessingService] DOCX 처리 오류: \(error)")
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
            print("❌ [FileProcessingService] 정규식 처리 오류: \(error)")
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
            
            guard FileManager.default.fileExists(atPath: url.path) else {
                return (false, .fileReadError)
            }
            
            // 파일 크기 확인
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            let fileSize = resourceValues.fileSize ?? 0
            
            guard fileSize > 0 else {
                return (false, .emptyContent)
            }
            
            // 최대 크기 확인 (10MB)
            guard fileSize <= 10 * 1024 * 1024 else {
                return (false, .fileReadError)
            }
            
        } catch {
            let deviceType = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
            print("❌ [FileProcessingService] 파일 검증 오류 - 기기: \(deviceType): \(error)")
            return (false, .fileReadError)
        }
        
        return (true, nil)
    }
}