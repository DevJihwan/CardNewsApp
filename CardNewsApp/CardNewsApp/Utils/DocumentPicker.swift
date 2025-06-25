import SwiftUI
import UIKit
import UniformTypeIdentifiers

// UIKit의 UIDocumentPickerViewController를 SwiftUI에서 사용하기 위한 브릿지
struct DocumentPicker: UIViewControllerRepresentable {
    let onFileSelected: ((URL) -> Void)?
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [
                UTType.pdf,           // PDF 파일
                UTType("org.openxmlformats.wordprocessingml.document")!, // .docx
                UTType("com.microsoft.word.doc")! // .doc (레거시)
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
            
            print("✅ [DocumentPicker] 선택된 파일: \(url.lastPathComponent)")
            
            // 메인 스레드에서 콜백만 실행 (모달은 자동으로 닫힘)
            DispatchQueue.main.async {
                print("🔍 [DocumentPicker] 콜백 실행")
                self.parent.onFileSelected?(url)
                print("✅ [DocumentPicker] 콜백 완료")
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("🔍 [DocumentPicker] 사용자가 취소함")
            // 아무것도 하지 않음 - 자동으로 닫힘
        }
    }
}
