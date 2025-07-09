import SwiftUI
import UIKit
import UniformTypeIdentifiers

// 더 안전한 DocumentPicker 구현
struct DocumentPicker: UIViewControllerRepresentable {
    let onFileSelected: ((URL) -> Void)?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [
                .pdf,           // PDF 파일
                .data           // 모든 데이터 파일 (DOCX 포함)
            ],
            asCopy: true        // ⭐️ CRITICAL: 파일을 앱으로 복사
        )
        
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // 업데이트할 내용 없음
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            print("🔍 [DocumentPicker] 파일 선택됨: \(urls.map { $0.lastPathComponent })")
            
            guard let url = urls.first else {
                print("❌ [DocumentPicker] URL이 없음")
                return
            }
            
            // 파일 형식 검증
            let fileExtension = url.pathExtension.lowercased()
            guard ["pdf", "docx"].contains(fileExtension) else {
                print("❌ [DocumentPicker] 지원하지 않는 파일 형식: \(fileExtension)")
                return
            }
            
            print("✅ [DocumentPicker] 선택된 파일: \(url.lastPathComponent)")
            print("🔍 [DocumentPicker] 파일 경로: \(url.path)")
            
            // ⭐️ IMPROVED: 다중 접근 방법 시도
            processFileWithMultipleStrategies(url: url, fileExtension: fileExtension)
        }
        
        private func processFileWithMultipleStrategies(url: URL, fileExtension: String) {
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
            
            // Strategy 4: 최종 백업 - 원본 URL 그대로 전달
            print("⚠️ [DocumentPicker] 모든 접근 방법 실패 - 원본 URL로 시도")
            self.parent.onFileSelected?(url)
        }
        
        // Strategy 1: asCopy=true인 경우 직접 접근
        private func tryDirectAccess(url: URL, fileExtension: String) -> Bool {
            print("🔍 [DocumentPicker] Strategy 1: 직접 접근 시도")
            
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("❌ [DocumentPicker] Strategy 1 실패: 파일이 존재하지 않음")
                return false
            }
            
            // 파일 읽기 테스트
            guard isFileReadable(at: url) else {
                print("❌ [DocumentPicker] Strategy 1 실패: 파일 읽기 불가")
                return false
            }
            
            print("✅ [DocumentPicker] Strategy 1 성공: 직접 접근")
            self.parent.onFileSelected?(url)
            return true
        }
        
        // Strategy 2: Security-Scoped Resource 접근
        private func trySecurityScopedAccess(url: URL, fileExtension: String) -> Bool {
            print("🔍 [DocumentPicker] Strategy 2: Security-Scoped Resource 접근 시도")
            
            // Security-Scoped Resource 접근 시작
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ [DocumentPicker] Strategy 2 실패: Security-Scoped Resource 접근 실패")
                return false
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
                print("🔓 [DocumentPicker] Security-Scoped Resource 접근 종료")
            }
            
            print("🔐 [DocumentPicker] Security-Scoped Resource 접근 성공")
            
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
                print("✅ [DocumentPicker] Strategy 2 성공: 파일 복사 완료")
                
                // 복사된 임시 파일 URL로 콜백 실행
                self.parent.onFileSelected?(tempURL)
                return true
                
            } catch {
                print("❌ [DocumentPicker] Strategy 2 실패: 파일 복사 오류 - \(error)")
                return false
            }
        }
        
        // Strategy 3: 파일명 정규화 후 재시도
        private func tryWithNormalizedFilename(url: URL, fileExtension: String) -> Bool {
            print("🔍 [DocumentPicker] Strategy 3: 파일명 정규화 후 재시도")
            
            let tempDirectory = FileManager.default.temporaryDirectory
            let normalizedFileName = sanitizeFileName(url.lastPathComponent, extension: fileExtension)
            let normalizedURL = tempDirectory.appendingPathComponent(normalizedFileName)
            
            // Security-Scoped Resource 접근 시도
            guard url.startAccessingSecurityScopedResource() else {
                // Security-Scoped 없이도 시도해볼 수 있음
                print("⚠️ [DocumentPicker] Strategy 3: Security-Scoped 접근 없이 시도")
                return copyWithNormalizedName(from: url, to: normalizedURL)
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            return copyWithNormalizedName(from: url, to: normalizedURL)
        }
        
        private func copyWithNormalizedName(from sourceURL: URL, to destinationURL: URL) -> Bool {
            do {
                // 기존 파일 삭제
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // 파일 복사
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                print("✅ [DocumentPicker] Strategy 3 성공: 정규화된 파일명으로 복사")
                
                self.parent.onFileSelected?(destinationURL)
                return true
                
            } catch {
                print("❌ [DocumentPicker] Strategy 3 실패: \(error)")
                return false
            }
        }
        
        // 파일 읽기 가능 여부 확인
        private func isFileReadable(at url: URL) -> Bool {
            do {
                let _ = try Data(contentsOf: url, options: .mappedIfSafe)
                return true
            } catch {
                print("❌ [DocumentPicker] 파일 읽기 테스트 실패: \(error)")
                return false
            }
        }
        
        // 파일명 정규화 (특수문자, 긴 한글명 처리)
        private func sanitizeFileName(_ fileName: String, extension fileExtension: String) -> String {
            // 확장자 제거
            let nameWithoutExtension = fileName.replacingOccurrences(of: ".\(fileExtension)", with: "")
            
            // 특수문자 제거 및 길이 제한
            let sanitized = nameWithoutExtension
                .replacingOccurrences(of: "[\\/:\\*\\?\"<>\\|]", with: "_", options: .regularExpression)
                .replacingOccurrences(of: " ", with: "_")
                .prefix(50) // 파일명 길이 제한
            
            // UUID 추가로 중복 방지
            let shortUUID = UUID().uuidString.prefix(8)
            return "\(sanitized)_\(shortUUID).\(fileExtension)"
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("🔍 [DocumentPicker] 사용자가 취소함")
        }
    }
}