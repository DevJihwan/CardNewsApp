import UIKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Safe Document Picker Representable (개선된 버전)

struct SafeDocumentPickerRepresentable: UIViewControllerRepresentable {
    let onResult: (Result<URL, Error>) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // ⚠️ FIX: PDF와 DOCX만 허용하도록 수정
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [
                .pdf,  // PDF 파일
                UTType(filenameExtension: "docx")!  // Word 파일
            ],
            asCopy: true  // 파일을 앱으로 복사
        )
        
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onResult: (Result<URL, Error>) -> Void
        private var hasProcessedResult = false
        
        init(onResult: @escaping (Result<URL, Error>) -> Void) {
            self.onResult = onResult
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard !hasProcessedResult else { return }
            hasProcessedResult = true
            
            guard let url = urls.first else {
                onResult(.failure(DocumentPickerError.noFileSelected))
                return
            }
            
            let fileExtension = url.pathExtension.lowercased()
            guard ["pdf", "docx"].contains(fileExtension) else {
                onResult(.failure(DocumentPickerError.unsupportedFileType))
                return
            }
            
            print("✅ [SafeDocumentPicker] 파일 선택 성공: \(url.lastPathComponent)")
            print("🔍 [SafeDocumentPicker] 파일 경로: \(url.path)")
            print("🔍 [SafeDocumentPicker] URL 스킴: \(url.scheme ?? "없음")")
            print("🔍 [SafeDocumentPicker] 파일 존재 여부: \(FileManager.default.fileExists(atPath: url.path))")
            
            // ⭐️ IMPROVED: 다중 전략으로 파일 처리
            processFileWithMultipleStrategies(url: url, fileExtension: fileExtension)
        }
        
        private func processFileWithMultipleStrategies(url: URL, fileExtension: String) {
            // ⭐️ CRITICAL: 파일이 이미 앱 샌드박스에 있는지 확인
            if isFileInAppSandbox(url: url) {
                print("🎯 [SafeDocumentPicker] Strategy 0: 파일이 이미 앱 샌드박스에 있음 - 직접 사용")
                if tryDirectAccessInSandbox(url: url) {
                    return
                }
            }
            
            // Strategy 1: asCopy=true로 설정했으므로 직접 접근 시도
            if tryDirectAccess(url: url, fileExtension: fileExtension) {
                return
            }
            
            // Strategy 2: Security-Scoped Resource 접근 시도
            if trySecurityScopedAccess(url: url, fileExtension: fileExtension) {
                return
            }
            
            // Strategy 3: 파일명 정규화 후 재시도
            if tryWithNormalizedFilename(url: url, fileExtension: fileExtension) {
                return
            }
            
            // Strategy 4: Document Interaction Controller 방식
            if tryDocumentInteractionMethod(url: url, fileExtension: fileExtension) {
                return
            }
            
            // Strategy 5: 최종 백업 - 원본 URL 그대로 전달
            print("⚠️ [SafeDocumentPicker] 모든 접근 방법 실패 - 원본 URL로 시도")
            onResult(.success(url))
        }
        
        // ⭐️ NEW: 파일이 앱 샌드박스에 있는지 확인
        private func isFileInAppSandbox(url: URL) -> Bool {
            let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
            let sandboxIdentifier = "com.devjihwan.cardnewsapp.CardNewsApp"
            
            // 경로에 앱 식별자가 포함되어 있는지 확인
            return url.path.contains(bundleIdentifier) || url.path.contains(sandboxIdentifier)
        }
        
        // ⭐️ NEW: 앱 샌드박스 내 파일 직접 접근
        private func tryDirectAccessInSandbox(url: URL) -> Bool {
            print("🔍 [SafeDocumentPicker] Strategy 0: 샌드박스 내 파일 직접 접근 시도")
            
            // 파일 존재 확인
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("❌ [SafeDocumentPicker] Strategy 0 실패: 파일이 존재하지 않음")
                return false
            }
            
            // 파일 읽기 권한 확인
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                print("❌ [SafeDocumentPicker] Strategy 0 실패: 파일 읽기 권한 없음")
                return false
            }
            
            // 실제 데이터 읽기 테스트
            do {
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                guard data.count > 0 else {
                    print("❌ [SafeDocumentPicker] Strategy 0 실패: 빈 파일")
                    return false
                }
                
                print("✅ [SafeDocumentPicker] Strategy 0 성공: 샌드박스 내 직접 접근 (크기: \(data.count) bytes)")
                onResult(.success(url))
                return true
                
            } catch {
                print("❌ [SafeDocumentPicker] Strategy 0 실패: 데이터 읽기 오류 - \(error)")
                return false
            }
        }
        
        // Strategy 1: asCopy=true인 경우 직접 접근
        private func tryDirectAccess(url: URL, fileExtension: String) -> Bool {
            print("🔍 [SafeDocumentPicker] Strategy 1: 직접 접근 시도")
            
            // 파일 존재 확인
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("❌ [SafeDocumentPicker] Strategy 1 실패: 파일이 존재하지 않음")
                return false
            }
            
            // 파일 읽기 권한 확인
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                print("❌ [SafeDocumentPicker] Strategy 1 실패: 파일 읽기 권한 없음")
                return false
            }
            
            // 실제 데이터 읽기 테스트
            do {
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                guard data.count > 0 else {
                    print("❌ [SafeDocumentPicker] Strategy 1 실패: 빈 파일")
                    return false
                }
                
                print("✅ [SafeDocumentPicker] Strategy 1 성공: 직접 접근 (크기: \(data.count) bytes)")
                onResult(.success(url))
                return true
                
            } catch {
                print("❌ [SafeDocumentPicker] Strategy 1 실패: 데이터 읽기 오류 - \(error)")
                return false
            }
        }
        
        // Strategy 2: Security-Scoped Resource 접근
        private func trySecurityScopedAccess(url: URL, fileExtension: String) -> Bool {
            print("🔍 [SafeDocumentPicker] Strategy 2: Security-Scoped Resource 접근 시도")
            
            // Security-Scoped Resource 접근 시작
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ [SafeDocumentPicker] Strategy 2 실패: Security-Scoped Resource 접근 실패")
                return false
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
                print("🔓 [SafeDocumentPicker] Security-Scoped Resource 접근 종료")
            }
            
            print("🔐 [SafeDocumentPicker] Security-Scoped Resource 접근 성공")
            
            // 임시 디렉토리로 파일 복사
            let tempDirectory = FileManager.default.temporaryDirectory
            let sanitizedFileName = sanitizeFileName(url.lastPathComponent, extension: fileExtension)
            let tempURL = tempDirectory.appendingPathComponent(sanitizedFileName)
            
            do {
                // 기존 임시 파일이 있다면 삭제
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                
                // 원본 파일을 임시 위치로 복사
                try FileManager.default.copyItem(at: url, to: tempURL)
                
                // 복사된 파일 검증
                let copiedData = try Data(contentsOf: tempURL)
                guard copiedData.count > 0 else {
                    throw DocumentPickerError.viewServiceError
                }
                
                print("✅ [SafeDocumentPicker] Strategy 2 성공: 파일 복사 완료 (크기: \(copiedData.count) bytes)")
                onResult(.success(tempURL))
                return true
                
            } catch {
                print("❌ [SafeDocumentPicker] Strategy 2 실패: 파일 복사 오류 - \(error)")
                return false
            }
        }
        
        // Strategy 3: 파일명 정규화 후 재시도
        private func tryWithNormalizedFilename(url: URL, fileExtension: String) -> Bool {
            print("🔍 [SafeDocumentPicker] Strategy 3: 파일명 정규화 후 재시도")
            
            let tempDirectory = FileManager.default.temporaryDirectory
            let normalizedFileName = sanitizeFileName(url.lastPathComponent, extension: fileExtension)
            let normalizedURL = tempDirectory.appendingPathComponent(normalizedFileName)
            
            // Security-Scoped Resource 접근 시도
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                return copyWithNormalizedName(from: url, to: normalizedURL)
            } else {
                // Security-Scoped 없이도 시도해볼 수 있음
                print("⚠️ [SafeDocumentPicker] Strategy 3: Security-Scoped 접근 없이 시도")
                return copyWithNormalizedName(from: url, to: normalizedURL)
            }
        }
        
        // Strategy 4: Document Interaction Controller 방식
        private func tryDocumentInteractionMethod(url: URL, fileExtension: String) -> Bool {
            print("🔍 [SafeDocumentPicker] Strategy 4: Document Interaction 방식 시도")
            
            // URL의 bookmarkData 생성 시도
            do {
                let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                
                // bookmarkData에서 URL 복원
                var isStale = false
                let resolvedURL = try URL(resolvingBookmarkData: bookmarkData, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale)
                
                if !isStale {
                    print("✅ [SafeDocumentPicker] Strategy 4 성공: bookmark 방식")
                    onResult(.success(resolvedURL))
                    return true
                }
                
            } catch {
                print("❌ [SafeDocumentPicker] Strategy 4 실패: bookmark 오류 - \(error)")
            }
            
            return false
        }
        
        private func copyWithNormalizedName(from sourceURL: URL, to destinationURL: URL) -> Bool {
            do {
                // 기존 파일 삭제
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // 파일 복사
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                
                // 복사된 파일 검증
                let copiedData = try Data(contentsOf: destinationURL)
                guard copiedData.count > 0 else {
                    throw DocumentPickerError.viewServiceError
                }
                
                print("✅ [SafeDocumentPicker] Strategy 3 성공: 정규화된 파일명으로 복사 (크기: \(copiedData.count) bytes)")
                onResult(.success(destinationURL))
                return true
                
            } catch {
                print("❌ [SafeDocumentPicker] Strategy 3 실패: \(error)")
                return false
            }
        }
        
        // 파일명 정규화 (특수문자, 긴 한글명 처리)
        private func sanitizeFileName(_ fileName: String, extension fileExtension: String) -> String {
            // 확장자 제거
            let nameWithoutExtension = fileName.replacingOccurrences(of: ".\(fileExtension)", with: "")
            
            // 특수문자 제거 및 길이 제한
            let sanitized = nameWithoutExtension
                .replacingOccurrences(of: "[/:\\*\\?\"<>\\|\\(\\)]", with: "_", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression)
                .replacingOccurrences(of: "[^a-zA-Z0-9가-힣_]", with: "_", options: .regularExpression)
                .prefix(30) // 파일명 길이 제한을 더 짧게
            
            // UUID 추가로 중복 방지
            let shortUUID = UUID().uuidString.prefix(8)
            return "\(sanitized)_\(shortUUID).\(fileExtension)"
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            guard !hasProcessedResult else { return }
            hasProcessedResult = true
            
            print("🔄 [SafeDocumentPicker] 선택 취소됨")
            onResult(.failure(DocumentPickerError.userCancelled))
        }
    }
}