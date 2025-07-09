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
            ]
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
            
            // 🔧 Security-Scoped Resource 접근 시작
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ [DocumentPicker] Security-Scoped Resource 접근 실패")
                return
            }
            
            print("🔐 [DocumentPicker] Security-Scoped Resource 접근 성공")
            
            // 파일을 임시 위치로 복사
            let tempDirectory = FileManager.default.temporaryDirectory
            let tempFileName = UUID().uuidString + "." + fileExtension
            let tempURL = tempDirectory.appendingPathComponent(tempFileName)
            
            do {
                // 기존 임시 파일이 있다면 삭제
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                
                // 원본 파일을 임시 위치로 복사
                try FileManager.default.copyItem(at: url, to: tempURL)
                print("✅ [DocumentPicker] 파일 복사 성공: \(tempURL.lastPathComponent)")
                
                // Security-Scoped Resource 접근 종료
                url.stopAccessingSecurityScopedResource()
                print("🔓 [DocumentPicker] Security-Scoped Resource 접근 종료")
                
                // 복사된 임시 파일 URL로 콜백 실행
                self.parent.onFileSelected?(tempURL)
                print("✅ [DocumentPicker] 콜백 완료 (임시 파일)")
                
            } catch {
                print("❌ [DocumentPicker] 파일 복사 실패: \(error)")
                // 실패해도 Security-Scoped Resource 접근 종료
                url.stopAccessingSecurityScopedResource()
                
                // 실패 시 원본 URL로 콜백 시도 (백업)
                self.parent.onFileSelected?(url)
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("🔍 [DocumentPicker] 사용자가 취소함")
        }
    }
}
