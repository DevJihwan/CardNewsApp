import SwiftUI

struct FileUploadView: View {
    @StateObject private var viewModel = FileUploadViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var shouldStayOpen = true
    @State private var preventDismiss = true
    @State private var showingFilePicker = false
    @State private var hasAppeared = false
    
    let preselectedFile: URL?
    
    init(preselectedFile: URL? = nil) {
        self.preselectedFile = preselectedFile
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 상단 제목 영역
                    headerSection
                    
                    // 파일 업로드 영역
                    uploadSection
                    
                    // 선택된 파일 정보 표시
                    if viewModel.isFileSelected {
                        fileInfoSection
                    }
                    
                    // 파일 처리 진행 상태
                    if viewModel.isProcessing {
                        processingSection
                    }
                    
                    // 처리된 내용 미리보기
                    if viewModel.isProcessed {
                        contentPreviewSection
                    }
                    
                    // 하단 버튼 영역
                    if viewModel.isFileSelected {
                        bottomButtons
                    }
                    
                    // 하단 여백
                    Color.clear.frame(height: 50)
                }
                .padding()
            }
            .navigationTitle("파일 업로드")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        print("🔍 [FileUploadView] 사용자가 의도적으로 취소 버튼 클릭")
                        shouldStayOpen = false
                        preventDismiss = false
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingFilePicker) {
                DocumentPickerWrapper { url in
                    handleFileSelection(url)
                    showingFilePicker = false
                } onCancel: {
                    print("🔍 [FileUploadView] 파일 선택 취소됨")
                    showingFilePicker = false
                }
            }
            // ✅ 요약 설정 화면 네비게이션 추가
            .sheet(isPresented: $viewModel.showSummaryConfig) {
                if let processedDocument = viewModel.processedDocument {
                    SummaryConfigView(processedDocument: processedDocument)
                }
            }
            .alert("오류", isPresented: $viewModel.showError) {
                Button("확인") {
                    viewModel.showError = false
                }
            } message: {
                Text(viewModel.errorMessage ?? "알 수 없는 오류가 발생했습니다.")
            }
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                
                shouldStayOpen = true
                preventDismiss = true
                print("🔍 [FileUploadView] 뷰 나타남 - 모달 보호 활성화")
                
                if let file = preselectedFile {
                    print("🔍 [FileUploadView] 미리 선택된 파일 로드: \(file.lastPathComponent)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        viewModel.handleFileSelection(file)
                    }
                }
            }
            .onDisappear {
                if shouldStayOpen && preventDismiss {
                    print("⚠️ [FileUploadView] 예상치 못한 모달 닫힘 감지!")
                } else {
                    print("✅ [FileUploadView] 정상적인 모달 닫힘")
                }
            }
            .onChange(of: viewModel.isFileSelected) { _, newValue in
                print("🔍 [FileUploadView] isFileSelected 변경: \(newValue)")
                
                if newValue {
                    shouldStayOpen = true
                    preventDismiss = true
                    print("🔧 [FileUploadView] 파일 선택 완료 - 모달 보호 강화")
                }
            }
            .onChange(of: viewModel.isProcessed) { _, newValue in
                print("🔍 [FileUploadView] isProcessed 변경: \(newValue)")
                if newValue {
                    print("🎉 [FileUploadView] 파일 처리 완료 - UI 업데이트됨")
                }
            }
            .onChange(of: viewModel.showSummaryConfig) { _, newValue in
                print("🔍 [FileUploadView] showSummaryConfig 변경: \(newValue)")
                if newValue {
                    print("🎯 [FileUploadView] 요약 설정 화면 열림")
                }
            }
        }
        .interactiveDismissDisabled(preventDismiss)
    }
    
    // 안전한 파일 선택 처리 함수
    private func handleFileSelection(_ url: URL) {
        print("🔍 [FileUploadView] 파일 선택 처리 시작")
        
        // 모달 보호 설정
        shouldStayOpen = true
        preventDismiss = true
        
        // 메인 스레드에서 안전하게 처리
        DispatchQueue.main.async {
            viewModel.handleFileSelection(url)
        }
        
        print("🔍 [FileUploadView] 파일 선택 처리 완료")
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
                Text("PDF 또는 Word 파일을 업로드하여\n카드뉴스로 변환할 수 있습니다")
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
                print("🔍 [FileUploadView] 파일 선택 버튼 클릭")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showingFilePicker = true
                }
            }) {
                VStack(spacing: 12) {
                    Image(systemName: getUploadIconName())
                        .font(.system(size: 40))
                        .foregroundColor(getUploadIconColor())
                    
                    Text(getUploadButtonText())
                        .font(.headline)
                    
                    if !viewModel.isFileSelected {
                        Text("PDF, DOCX 파일 (최대 10MB)")
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
    
    // MARK: - File Info Section
    private var fileInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
    
    // MARK: - Content Preview Section
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
                Text(viewModel.contentPreview.isEmpty ? "내용을 불러오는 중..." : viewModel.contentPreview)
                    .font(.body)
                    .lineLimit(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(viewModel.contentPreview.isEmpty ? .secondary : .primary)
            }
            .frame(maxHeight: 150)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
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
    
    // MARK: - Bottom Buttons
    private var bottomButtons: some View {
        VStack(spacing: 12) {
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
                
                // 재처리 버튼 (처리 완료 후에만 표시)
                if viewModel.isProcessed {
                    Button(action: {
                        viewModel.reprocessContent()
                    }) {
                        Text("다시 처리")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                }
            }
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

// DocumentPicker 래퍼
struct DocumentPickerWrapper: View {
    let onFileSelected: (URL) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            StableDocumentPicker(onFileSelected: onFileSelected)
                .navigationTitle("파일 선택")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("취소") {
                            onCancel()
                        }
                    }
                }
        }
    }
}

// 안정성이 개선된 DocumentPicker
struct StableDocumentPicker: UIViewControllerRepresentable {
    let onFileSelected: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.pdf, .data],
            asCopy: true
        )
        
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: StableDocumentPicker
        
        init(_ parent: StableDocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            let fileExtension = url.pathExtension.lowercased()
            guard ["pdf", "docx"].contains(fileExtension) else { return }
            
            print("🔍 [StableDocumentPicker] 파일 선택됨: \(url.lastPathComponent)")
            
            DispatchQueue.main.async {
                self.parent.onFileSelected(url)
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("🔍 [StableDocumentPicker] 사용자가 취소함")
        }
    }
}

#Preview {
    FileUploadView()
}
