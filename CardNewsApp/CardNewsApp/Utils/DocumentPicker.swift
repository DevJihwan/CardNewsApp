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
            
            // 🔧 즉시 콜백 실행 (뷰 서비스 종료 전에)
            self.parent.onFileSelected?(url)
            print("✅ [DocumentPicker] 콜백 완료")
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("🔍 [DocumentPicker] 사용자가 취소함")
        }
    }
}
