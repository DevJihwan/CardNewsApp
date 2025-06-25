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
    @Published var showTextInput: Bool = false // 텍스트 입력 모달
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // 파일 처리 관련 상태
    @Published var isProcessing: Bool = false
    @Published var processingProgress: Double = 0.0
    @Published var processedDocument: ProcessedDocument?
    @Published var isProcessed: Bool = false
    @Published var contentPreview: String = ""
    
    // 상수 정의
    private let maxFileSize: Int = 10 * 1024 * 1024 // 10MB
    private let supportedExtensions = ["pdf", "docx", "doc"]
    
    // 파일 선택 후 처리 (안전성 강화 버전)
    func handleFileSelection(_ url: URL) {
        print("🔍 [DEBUG] 파일 선택됨: \(url.lastPathComponent)")
        
        // 안전성을 위해 try-catch로 감싸기
        do {
            isLoading = true
            
            // 파일 검증
            print("🔍 [DEBUG] 파일 검증 시작...")
            guard validateFile(url) else {
                print("❌ [DEBUG] 파일 검증 실패")
                isLoading = false
                return
            }
            print("✅ [DEBUG] 파일 검증 성공")
            
            // 파일 정보 설정
            print("🔍 [DEBUG] 파일 정보 업데이트 시작...")
            updateFileInfo(url)
            print("✅ [DEBUG] 파일 정보 업데이트 완료: \(fileName)")
            
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
    
    // 파일 검증 함수 (디버깅 버전)
    private func validateFile(_ url: URL) -> Bool {
        print("🔍 [DEBUG] validateFile 시작: \(url.path)")
        
        do {
            // 파일 접근 권한 확인
            print("🔍 [DEBUG] 파일 접근 권한 확인...")
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ [DEBUG] 파일 접근 권한 실패")
                showErrorMessage("파일에 접근할 수 없습니다.")
                return false
            }
            print("✅ [DEBUG] 파일 접근 권한 성공")
            
            // 파일 존재 확인
            print("🔍 [DEBUG] 파일 존재 확인...")
            guard try url.checkResourceIsReachable() else {
                print("❌ [DEBUG] 파일 접근 불가")
                url.stopAccessingSecurityScopedResource()
                showErrorMessage("파일에 접근할 수 없습니다.")
                return false
            }
            print("✅ [DEBUG] 파일 존재 확인 성공")
            
            // 파일 확장자 확인
            let fileExtension = url.pathExtension.lowercased()
            print("🔍 [DEBUG] 파일 확장자: \(fileExtension)")
            guard supportedExtensions.contains(fileExtension) else {
                print("❌ [DEBUG] 지원하지 않는 파일 형식: \(fileExtension)")
                url.stopAccessingSecurityScopedResource()
                showErrorMessage("지원하지 않는 파일 형식입니다.\n지원 형식: PDF, DOCX, DOC")
                return false
            }
            print("✅ [DEBUG] 파일 형식 지원됨")
            
            // 파일 크기 확인
            print("🔍 [DEBUG] 파일 크기 확인...")
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            let fileSize = resourceValues.fileSize ?? 0
            print("🔍 [DEBUG] 파일 크기: \(fileSize) bytes")
            
            guard fileSize <= maxFileSize else {
                print("❌ [DEBUG] 파일 크기 초과: \(fileSize) > \(maxFileSize)")
                url.stopAccessingSecurityScopedResource()
                showErrorMessage("파일 크기가 너무 큽니다.\n최대 크기: 10MB")
                return false
            }
            
            guard fileSize > 0 else {
                print("❌ [DEBUG] 빈 파일")
                url.stopAccessingSecurityScopedResource()
                showErrorMessage("파일이 비어있습니다.")
                return false
            }
            print("✅ [DEBUG] 파일 크기 정상: \(fileSize) bytes")
            
            // 여기서는 stopAccessingSecurityScopedResource를 호출하지 않음
            // 나중에 파일 처리할 때까지 권한 유지
            
            return true
            
        } catch {
            print("❌ [DEBUG] 파일 검증 중 오류: \(error)")
            url.stopAccessingSecurityScopedResource()
            showErrorMessage("파일 정보를 읽는 중 오류가 발생했습니다.\n\(error.localizedDescription)")
            return false
        }
    }
    
    // 파일 정보 업데이트 (디버깅 버전)
    private func updateFileInfo(_ url: URL) {
        print("🔍 [DEBUG] updateFileInfo 시작")
        
        fileName = url.lastPathComponent
        fileType = url.pathExtension.uppercased()
        print("🔍 [DEBUG] 파일명: \(fileName), 형식: \(fileType)")
        
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            let sizeInBytes = resourceValues.fileSize ?? 0
            fileSize = formatFileSize(sizeInBytes)
            print("🔍 [DEBUG] 파일 크기 포맷팅: \(fileSize)")
        } catch {
            print("❌ [DEBUG] 파일 크기 읽기 실패: \(error)")
            fileSize = "알 수 없음"
        }
        
        print("✅ [DEBUG] updateFileInfo 완료")
    }
    
    // 파일 크기를 사람이 읽기 쉬운 형태로 변환
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // 파일 처리 실행
    func processFile() async {
        print("🔍 [DEBUG] processFile 시작")
        
        guard let url = selectedFileURL else {
            print("❌ [DEBUG] 선택된 파일이 없음")
            showErrorMessage("선택된 파일이 없습니다.")
            return
        }
        
        isProcessing = true
        processingProgress = 0.0
        errorMessage = nil
        
        do {
            // 진행률 업데이트
            processingProgress = 0.2
            print("🔍 [DEBUG] 파일 처리 시작: \(url.lastPathComponent)")
            
            // 파일 처리 서비스 호출
            let processed = try await fileProcessingService.processDocument(from: url)
            
            processingProgress = 0.8
            print("✅ [DEBUG] 파일 처리 성공")
            
            // 결과 저장
            processedDocument = processed
            print("🔍 [DEBUG] 추출된 텍스트 길이: \(processed.content.count)자")
            print("🔍 [DEBUG] 추출된 텍스트 내용 (처음 100자): \(String(processed.content.prefix(100)))")
            
            contentPreview = fileProcessingService.generatePreview(from: processed.content, maxLength: 300)
            print("🔍 [DEBUG] 생성된 미리보기 길이: \(contentPreview.count)자")
            print("🔍 [DEBUG] 생성된 미리보기 내용: \(contentPreview)")
            
            isProcessed = true
            
            processingProgress = 1.0
            
            print("🎉 [DEBUG] 파일 처리 완료: \(processed.wordCount)단어, \(processed.characterCount)자")
            
        } catch let error as FileProcessingError {
            print("❌ [DEBUG] 파일 처리 오류: \(error.localizedDescription)")
            showErrorMessage(error.localizedDescription)
        } catch {
            print("❌ [DEBUG] 예상치 못한 오류: \(error)")
            showErrorMessage("파일 처리 중 예상치 못한 오류가 발생했습니다.\n\(error.localizedDescription)")
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
    
    // 오류 메시지 표시 (디버깅 버전)
    private func showErrorMessage(_ message: String) {
        print("❌ [DEBUG] 오류 메시지: \(message)")
        errorMessage = message
        showError = true
    }
    
    // 파일 선택 초기화
    func clearSelectedFile() {
        print("🔍 [DEBUG] 파일 선택 초기화")
        selectedFileURL?.stopAccessingSecurityScopedResource()
        selectedFileURL = nil
        fileName = ""
        fileSize = ""
        fileType = ""
        isFileSelected = false
        errorMessage = nil
        showError = false
        showTextInput = false
        resetProcessingState()
    }
    
    // 파일 피커 표시
    func presentFilePicker() {
        print("🔍 [DEBUG] 파일 피커 표시")
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
        // TODO: 요약 설정 화면으로 네비게이션
    }
    
    // 🔧 수정된 텍스트 직접 입력 처리 함수
    func handleTextInput(_ text: String) {
        print("🔍 [DEBUG] 텍스트 직접 입력 시작: \(text.count)자")
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showErrorMessage("텍스트를 입력해주세요.")
            return
        }
        
        // Task를 사용하여 비동기 처리
        Task { @MainActor in
            print("🔍 [DEBUG] 텍스트 처리 시작...")
            
            // 먼저 텍스트 입력 모달 닫기
            showTextInput = false
            
            // 짧은 지연 후 상태 업데이트 (UI 업데이트 순서 보장)
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초
            
            // 가짜 DocumentInfo 생성
            let documentInfo = DocumentInfo(
                fileName: "직접입력_텍스트.txt",
                fileType: "TXT",
                fileSize: Int64(text.count),
                filePath: URL(string: "file://localhost/temp/text")!
            )
            
            // ProcessedDocument 생성
            let processed = ProcessedDocument(originalDocument: documentInfo, content: text)
            
            // 결과 저장
            processedDocument = processed
            
            // 미리보기 생성 (FileProcessingService 사용)
            contentPreview = fileProcessingService.generatePreview(from: processed.content, maxLength: 300)
            print("🔍 [DEBUG] 생성된 미리보기: \(contentPreview)")
            
            // 파일 선택 상태 설정
            fileName = "직접 입력한 텍스트"
            fileSize = "\(text.count)자"
            fileType = "텍스트"
            isFileSelected = true
            isProcessed = true
            
            print("🎉 [DEBUG] 텍스트 입력 처리 완료!")
            print("🔍 [DEBUG] - 단어 수: \(processed.wordCount)")
            print("🔍 [DEBUG] - 문자 수: \(processed.characterCount)")
            print("🔍 [DEBUG] - 미리보기 길이: \(contentPreview.count)자")
            print("🔍 [DEBUG] - isFileSelected: \(isFileSelected)")
            print("🔍 [DEBUG] - isProcessed: \(isProcessed)")
        }
    }
    
    // 파일 다시 처리
    func reprocessContent() {
        guard isFileSelected else { return }
        resetProcessingState()
        
        if let url = selectedFileURL {
            // 파일이 있으면 파일 처리
            Task {
                await processFile()
            }
        } else {
            // 텍스트 입력이었으면 텍스트 입력 모달 다시 열기
            showTextInput = true
        }
    }
}
