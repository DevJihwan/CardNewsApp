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
                UTType(filenameExtension: "docx")!, // .docx만 지원
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
            
            // 🔧 안전한 콜백 실행
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                print("🔍 [DocumentPicker] 콜백 실행")
                
                // 뷰 서비스 오류 방지를 위해 지연 없이 즉시 실행
                self.parent.onFileSelected?(url)
                print("✅ [DocumentPicker] 콜백 완료")
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("🔍 [DocumentPicker] 사용자가 취소함")
            // 아무것도 하지 않음 - 자동으로 닫힘
        }
        
        // 🔧 추가: 오류 처리
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
            // 단일 파일 선택 시 호출될 수 있는 메서드
            print("🔍 [DocumentPicker] 단일 파일 선택됨: \(url.lastPathComponent)")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.parent.onFileSelected?(url)
            }
        }
    }
}
