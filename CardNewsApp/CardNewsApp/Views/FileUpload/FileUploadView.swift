import SwiftUI

struct FileUploadView: View {
    @StateObject private var viewModel = FileUploadViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var shouldStayOpen = true
    @State private var preventDismiss = true // 강화된 모달 보호
    
    let preselectedFile: URL?
    
    init(preselectedFile: URL? = nil) {
        self.preselectedFile = preselectedFile
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 상단 제목 영역
                headerSection
                
                // 파일 업로드 영역
                uploadSection
                
                // 🔧 강제 디버깅 정보 표시
                debugInfoSection
                
                // 🔧 선택된 파일 정보 표시 - 조건 제거
                fileInfoSection
                
                // 파일 처리 진행 상태
                if viewModel.isProcessing {
                    processingSection
                }
                
                // 🔧 처리된 내용 미리보기 - 조건 완전 제거
                contentPreviewSection
                
                Spacer()
                
                // 🔧 하단 버튼 영역 - 조건 완전 제거
                bottomButtons
            }
            .padding()
            .navigationTitle("파일 업로드")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        print("🔍 [FileUploadView] 사용자가 취소 버튼 클릭")
                        shouldStayOpen = false
                        preventDismiss = false
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showFilePicker) {
                DocumentPicker { url in
                    print("🔍 [FileUploadView] 파일 선택 콜백 받음: \(url.lastPathComponent)")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        viewModel.handleFileSelection(url)
                        viewModel.showFilePicker = false
                        print("🔍 [FileUploadView] 파일 선택 처리 완료")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showTextInput) {
                TextInputView { text in
                    print("🔍 [FileUploadView] 텍스트 입력 받음: \(text.count)자")
                    print("🔍 [FileUploadView] 모달 보호 상태: preventDismiss=\(preventDismiss)")
                    
                    // 🔧 모달 보호 강화
                    preventDismiss = true
                    
                    // 텍스트 처리
                    viewModel.handleTextInput(text)
                    
                    print("🔍 [FileUploadView] 텍스트 처리 완료 후 상태 확인")
                }
                .interactiveDismissDisabled(preventDismiss) // 🔧 스와이프로 닫기 방지
            }
            .alert("오류", isPresented: $viewModel.showError) {
                Button("확인") {
                    viewModel.showError = false
                }
            } message: {
                Text(viewModel.errorMessage ?? "알 수 없는 오류가 발생했습니다.")
            }
            .onAppear {
                shouldStayOpen = true
                preventDismiss = true
                print("🔍 [FileUploadView] 뷰 나타남 - 모달 보호 활성화")
                
                if let file = preselectedFile {
                    print("🔍 [FileUploadView] 미리 선택된 파일 로드: \(file.lastPathComponent)")
                    viewModel.handleFileSelection(file)
                }
            }
            .onDisappear {
                if shouldStayOpen && preventDismiss {
                    print("⚠️ [FileUploadView] 예상치 못한 모달 닫힘 감지!")
                }
            }
            // 🔧 상태 변화 모니터링 강화
            .onChange(of: viewModel.isFileSelected) { _, newValue in
                print("🔍 [FileUploadView] isFileSelected 변경: \(newValue)")
            }
            .onChange(of: viewModel.isProcessed) { _, newValue in
                print("🔍 [FileUploadView] isProcessed 변경: \(newValue)")
                if newValue {
                    print("🎉 [FileUploadView] 파일 처리 완료 - UI 업데이트됨")
                }
            }
            .onChange(of: viewModel.showTextInput) { _, newValue in
                print("🔍 [FileUploadView] showTextInput 변경: \(newValue)")
                if !newValue {
                    // 텍스트 입력 모달이 닫혔을 때
                    print("🔍 [FileUploadView] 텍스트 입력 모달 닫힘")
                }
            }
            .onChange(of: viewModel.contentPreview) { _, newValue in
                print("🔍 [FileUploadView] contentPreview 변경: \(newValue.count)자")
            }
        }
        .interactiveDismissDisabled(preventDismiss) // 🔧 메인 모달도 보호
    }
    
    // 🔧 디버깅 정보 섹션
    private var debugInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("🔍 디버깅 상태:")
                .font(.caption)
                .foregroundColor(.red)
            Text("isFileSelected: \(viewModel.isFileSelected)")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("isProcessed: \(viewModel.isProcessed)")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("isProcessing: \(viewModel.isProcessing)")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("contentPreview.count: \(viewModel.contentPreview.count)")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("contentPreview.isEmpty: \(viewModel.contentPreview.isEmpty)")
                .font(.caption)
                .foregroundColor(.secondary)
            if let doc = viewModel.processedDocument {
                Text("processedDocument exists: wordCount=\(doc.wordCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("processedDocument: nil")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color.yellow.opacity(0.2))
        .cornerRadius(4)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: viewModel.isProcessed ? "checkmark.circle.fill" : "doc.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(viewModel.isProcessed ? .green : .blue)
            
            Text(viewModel.isProcessed ? "처리 완료!" : "문서를 선택해주세요")
                .font(.title2)
                .fontWeight(.semibold)
            
            if !viewModel.isProcessed {
                Text("PDF 파일을 업로드하거나 텍스트를 직접 입력하여\n카드뉴스로 변환할 수 있습니다")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("문서 내용을 성공적으로 처리했습니다")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Upload Section
    private var uploadSection: some View {
        VStack(spacing: 16) {
            // 파일 선택 버튼
            Button(action: {
                viewModel.presentFilePicker()
            }) {
                VStack(spacing: 12) {
                    Image(systemName: getUploadIconName())
                        .font(.system(size: 40))
                        .foregroundColor(getUploadIconColor())
                    
                    Text(getUploadButtonText())
                        .font(.headline)
                    
                    if !viewModel.isFileSelected {
                        Text("PDF, DOCX, DOC 파일 (최대 10MB)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            getUploadBorderColor(),
                            style: StrokeStyle(lineWidth: 2, dash: viewModel.isProcessed ? [] : [8])
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.isProcessing)
            
            // OR 구분선
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3))
                Text("또는")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3))
            }
            
            // 텍스트 직접 입력 버튼
            Button(action: {
                print("🔍 [FileUploadView] 텍스트 직접 입력 버튼 클릭")
                viewModel.showTextInput = true
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "text.cursor")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                    
                    Text("텍스트 직접 입력")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    
                    Text("(파일 업로드 문제 해결용)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.green, style: StrokeStyle(lineWidth: 1))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // 로딩 인디케이터
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("파일 정보 확인 중...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // 🔧 File Info Section - 조건 제거하고 항상 표시
    private var fileInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isFileSelected {
                Text("선택된 파일")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    fileInfoRow(icon: "doc.text", title: "파일명", value: viewModel.fileName)
                    fileInfoRow(icon: "externaldrive", title: "크기", value: viewModel.fileSize)
                    fileInfoRow(icon: "tag", title: "형식", value: viewModel.fileType)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else {
                Text("파일 선택 대기 중...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Processing Section
    private var processingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gearshape.2")
                    .foregroundColor(.blue)
                Text("파일 처리 중...")
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("진행률")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(viewModel.processingProgress * 100))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                ProgressView(value: viewModel.processingProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                
                Text(getProcessingStatusText())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBlue).opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    // 🔧 Content Preview Section - 조건 완전 제거하고 항상 표시
    private var contentPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "eye")
                    .foregroundColor(.green)
                Text("내용 미리보기")
                    .font(.headline)
                Spacer()
                
                if let doc = viewModel.processedDocument {
                    Text("\(doc.wordCount)단어")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                }
            }
            
            ScrollView {
                if viewModel.contentPreview.isEmpty {
                    Text("내용을 불러오는 중...")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(viewModel.contentPreview)
                        .font(.body)
                        .lineLimit(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(.primary)
                }
            }
            .frame(maxHeight: 150)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // 디버깅 정보 추가
            VStack(alignment: .leading, spacing: 4) {
                Text("디버깅 정보:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let doc = viewModel.processedDocument {
                    Text("원본 텍스트 길이: \(doc.content.count)자")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("현재 상태: isProcessed=\(viewModel.isProcessed)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("processedDocument가 nil입니다")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Text("미리보기 길이: \(viewModel.contentPreview.count)자")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("미리보기 isEmpty: \(viewModel.contentPreview.isEmpty)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
    }
    
    // 파일 정보 행
    private func fileInfoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
    
    // 🔧 Bottom Buttons - 조건 완전 제거하고 항상 표시
    private var bottomButtons: some View {
        VStack(spacing: 12) {
            // 🔧 항상 버튼 표시
            if viewModel.isFileSelected {
                // 다음 단계 버튼
                Button(action: {
                    viewModel.proceedToNextStep()
                }) {
                    HStack {
                        Text(viewModel.isProcessed ? "요약 설정" : "파일 처리")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isProcessing ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isProcessing)
                
                HStack(spacing: 16) {
                    // 다른 파일 선택 버튼
                    Button(action: {
                        viewModel.clearSelectedFile()
                    }) {
                        Text("다른 파일 선택")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    
                    // 🔧 재처리 버튼 - 항상 표시
                    Button(action: {
                        viewModel.reprocessContent()
                    }) {
                        Text("다시 처리")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                }
            } else {
                Text("파일을 선택하거나 텍스트를 입력해주세요")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 🔧 강제 테스트 버튼 (디버깅용)
            Button("🔧 강제 상태 확인") {
                print("🔧 [DEBUG] 강제 상태 확인:")
                print("  - isFileSelected: \(viewModel.isFileSelected)")
                print("  - isProcessed: \(viewModel.isProcessed)")
                print("  - isProcessing: \(viewModel.isProcessing)")
                print("  - contentPreview: '\(viewModel.contentPreview)'")
                print("  - processedDocument: \(viewModel.processedDocument != nil)")
            }
            .font(.caption)
            .foregroundColor(.red)
        }
    }
    
    // MARK: - Helper Methods
    private func getUploadIconName() -> String {
        if viewModel.isProcessed {
            return "checkmark.circle.fill"
        } else if viewModel.isFileSelected {
            return "doc.fill"
        } else {
            return "plus.circle"
        }
    }
    
    private func getUploadIconColor() -> Color {
        if viewModel.isProcessed {
            return .green
        } else if viewModel.isFileSelected {
            return .blue
        } else {
            return .blue
        }
    }
    
    private func getUploadButtonText() -> String {
        if viewModel.isProcessed {
            return "처리 완료"
        } else if viewModel.isFileSelected {
            return "파일 선택됨"
        } else {
            return "파일 선택"
        }
    }
    
    private func getUploadBorderColor() -> Color {
        if viewModel.isProcessed {
            return .green
        } else if viewModel.isFileSelected {
            return .blue
        } else {
            return .blue
        }
    }
    
    private func getProcessingStatusText() -> String {
        let progress = viewModel.processingProgress
        
        if progress < 0.3 {
            return "파일 읽는 중..."
        } else if progress < 0.8 {
            return "텍스트 추출 중..."
        } else if progress < 1.0 {
            return "내용 정리 중..."
        } else {
            return "처리 완료!"
        }
    }
}

#Preview {
    FileUploadView()
}
