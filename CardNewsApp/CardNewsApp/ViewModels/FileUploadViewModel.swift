import Foundation
import SwiftUI

// MVVM 패턴의 ViewModel - 파일 업로드 및 처리 비즈니스 로직 관리
@MainActor
class FileUploadViewModel: ObservableObject {
    // 파일 처리 서비스
    private let fileProcessingService = FileProcessingService()
    
    // UI에서 관찰할 수 있는 상태들
    @Published var selectedFileURL: URL?
    @Published var fileName: String = ""
    @Published var fileSize: String = ""
    @Published var fileType: String = ""
    @Published var isFileSelected: Bool = false
    @Published var showFilePicker: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // 파일 처리 관련 상태
    @Published var isProcessing: Bool = false
    @Published var processingProgress: Double = 0.0
    @Published var processedDocument: ProcessedDocument?
    @Published var isProcessed: Bool = false
    @Published var contentPreview: String = ""
    
    // 요약 설정 화면 관련 상태
    @Published var showSummaryConfig: Bool = false
    
    // 상수 정의
    private let maxFileSize: Int = 10 * 1024 * 1024 // 10MB
    private let supportedExtensions = ["pdf", "docx"]
    
    // 파일 선택 후 처리
    func handleFileSelection(_ url: URL) {
        print("🔍 [DEBUG] 파일 선택됨: \(url.lastPathComponent)")
        
        do {
            isLoading = true
            
            // 파일 검증
            guard validateFile(url) else {
                isLoading = false
                return
            }
            
            // 파일 정보 설정
            updateFileInfo(url)
            
            // 선택된 파일 URL 저장
            selectedFileURL = url
            isFileSelected = true
            isLoading = false
            
            // 처리 상태 초기화
            resetProcessingState()
            
            print("🎉 [DEBUG] 파일 업로드 준비 완료: \(fileName)")
            
        } catch {
            print("❌ [DEBUG] handleFileSelection에서 예상치 못한 오류: \(error)")
            isLoading = false
            showErrorMessage("파일 선택 중 오류가 발생했습니다: \(error.localizedDescription)")
        }
    }
    
    // 파일 검증 함수 - iPhone 전용으로 간소화
    private func validateFile(_ url: URL) -> Bool {
        print("🔍 [ViewModel] 파일 검증 시작: \(url.lastPathComponent)")
        
        do {
            // Security-Scoped Resource 접근 (iPhone에서 안정적)
            var needsSecurityScoped = false
            
            // 앱 샌드박스 외부 파일인지 확인
            if !isFileInAppSandbox(url: url) {
                guard url.startAccessingSecurityScopedResource() else {
                    showErrorMessage("파일에 접근할 수 없습니다.")
                    return false
                }
                needsSecurityScoped = true
                print("🔐 [ViewModel] Security-Scoped Resource 접근 시작")
            }
            
            // 함수 종료 시 Security-Scoped Resource 정리
            defer {
                if needsSecurityScoped {
                    url.stopAccessingSecurityScopedResource()
                    print("🔓 [ViewModel] Security-Scoped Resource 접근 종료")
                }
            }
            
            // 파일 존재 확인
            guard FileManager.default.fileExists(atPath: url.path) else {
                showErrorMessage("파일에 접근할 수 없습니다.")
                return false
            }
            
            // 파일 읽기 권한 확인
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                showErrorMessage("파일 읽기 권한이 없습니다.")
                return false
            }
            
            // 파일 확장자 확인
            let fileExtension = url.pathExtension.lowercased()
            guard supportedExtensions.contains(fileExtension) else {
                showErrorMessage("지원하지 않는 파일 형식입니다.\n지원 형식: PDF, DOCX")
                return false
            }
            
            // 파일 크기 확인
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            let fileSize = resourceValues.fileSize ?? 0
            
            guard fileSize <= maxFileSize else {
                showErrorMessage("파일 크기가 너무 큽니다.\n최대 크기: 10MB")
                return false
            }
            
            guard fileSize > 0 else {
                showErrorMessage("파일이 비어있습니다.")
                return false
            }
            
            // 파일 읽기 테스트
            do {
                let _ = try Data(contentsOf: url, options: .mappedIfSafe)
                print("✅ [ViewModel] 파일 검증 성공: \(fileSize) bytes")
                return true
            } catch {
                print("❌ [ViewModel] 파일 읽기 테스트 실패: \(error)")
                showErrorMessage("파일을 읽을 수 없습니다.")
                return false
            }
            
        } catch {
            print("❌ [ViewModel] 파일 검증 중 오류: \(error)")
            showErrorMessage("파일 정보를 읽는 중 오류가 발생했습니다.\n\(error.localizedDescription)")
            return false
        }
    }
    
    // 파일이 앱 샌드박스에 있는지 확인 - iPhone 전용으로 간소화
    private func isFileInAppSandbox(url: URL) -> Bool {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        
        return url.path.contains(bundleIdentifier) ||
               url.path.contains("/tmp/") ||
               url.path.contains("/Documents/") ||
               url.path.contains("/Library/")
    }
    
    // 파일 정보 업데이트
    private func updateFileInfo(_ url: URL) {
        fileName = url.lastPathComponent
        fileType = url.pathExtension.uppercased()
        
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            let sizeInBytes = resourceValues.fileSize ?? 0
            fileSize = formatFileSize(sizeInBytes)
        } catch {
            fileSize = "알 수 없음"
        }
    }
    
    // 파일 크기를 사람이 읽기 쉬운 형태로 변환
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // 파일 처리 실행 - 에러 핸들링 강화
    func processFile() async {
        print("🔍 [DEBUG] processFile 시작")
        
        guard let url = selectedFileURL else {
            showErrorMessage("선택된 파일이 없습니다.")
            return
        }
        
        isProcessing = true
        processingProgress = 0.0
        errorMessage = nil
        
        do {
            // 진행률 업데이트
            processingProgress = 0.2
            
            // 파일 처리 서비스 호출
            let processed = try await fileProcessingService.processDocument(from: url)
            
            processingProgress = 0.8
            
            // 결과 저장
            processedDocument = processed
            contentPreview = fileProcessingService.generatePreview(from: processed.content, maxLength: 300)
            isProcessed = true
            
            processingProgress = 1.0
            
            print("🎉 [DEBUG] 파일 처리 완료: \(processed.wordCount)단어, \(processed.characterCount)자")
            
        } catch let error as FileProcessingError {
            print("❌ [DEBUG] 파일 처리 오류: \(error)")
            showErrorMessage(error.localizedDescription)
        } catch {
            print("❌ [DEBUG] 예상치 못한 파일 처리 오류: \(error)")
            showErrorMessage("파일 처리 중 예상치 못한 오류가 발생했습니다.")
        }
        
        isProcessing = false
    }
    
    // 처리 상태 초기화
    private func resetProcessingState() {
        isProcessing = false
        processingProgress = 0.0
        processedDocument = nil
        isProcessed = false
        contentPreview = ""
    }
    
    // 오류 메시지 표시
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    // 파일 선택 초기화
    func clearSelectedFile() {
        // Security-Scoped Resource 정리
        if let url = selectedFileURL, !isFileInAppSandbox(url: url) {
            url.stopAccessingSecurityScopedResource()
        }
        
        selectedFileURL = nil
        fileName = ""
        fileSize = ""
        fileType = ""
        isFileSelected = false
        errorMessage = nil
        showError = false
        resetProcessingState()
    }
    
    // 파일 피커 표시
    func presentFilePicker() {
        showFilePicker = true
    }
    
    // 다음 단계로 진행 (파일 처리 또는 요약 설정 화면으로)
    func proceedToNextStep() {
        guard isFileSelected else { return }
        
        if !isProcessed {
            // 파일이 아직 처리되지 않았으면 처리 시작
            Task {
                await processFile()
            }
        } else {
            // 이미 처리되었으면 요약 설정 화면으로 이동
            proceedToSummaryConfig()
        }
    }
    
    // 요약 설정 화면으로 이동
    private func proceedToSummaryConfig() {
        guard let processed = processedDocument else { return }
        print("🎯 [DEBUG] 요약 설정 화면으로 이동: \(processed.originalDocument.fileName)")
        showSummaryConfig = true
    }
    
    // 파일 다시 처리
    func reprocessContent() {
        guard isFileSelected else { return }
        resetProcessingState()
        
        if let url = selectedFileURL {
            // 파일 다시 처리
            Task {
                await processFile()
            }
        }
    }
}