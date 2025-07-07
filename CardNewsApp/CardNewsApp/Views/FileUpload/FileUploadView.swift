import SwiftUI

struct FileUploadView: View {
    @StateObject private var viewModel = FileUploadViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var shouldStayOpen = true
    @State private var preventDismiss = true
    @State private var showingFilePicker = false
    @State private var hasAppeared = false
    @State private var pickerAttemptCount = 0
    @State private var showRetryAlert = false
    @State private var isSimulator = false
    
    let preselectedFile: URL?
    
    init(preselectedFile: URL? = nil) {
        self.preselectedFile = preselectedFile
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header Section - Clear Instructions
                    headerSection
                    
                    // Upload Section - Large touch targets
                    uploadSection
                    
                    // Selected File Info
                    if viewModel.isFileSelected {
                        fileInfoSection
                    }
                    
                    // Processing Progress
                    if viewModel.isProcessing {
                        processingSection
                    }
                    
                    // Content Preview
                    if viewModel.isProcessed {
                        contentPreviewSection
                    }
                    
                    // Action Buttons
                    if viewModel.isFileSelected {
                        bottomButtons
                    }
                    
                    // Bottom spacing
                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
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
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                }
            }
            .sheet(isPresented: $showingFilePicker) {
                DocumentPickerWrapper { url in
                    handleFileSelection(url)
                    showingFilePicker = false
                    pickerAttemptCount = 0 // 성공 시 카운트 리셋
                } onCancel: {
                    print("🔍 [FileUploadView] 파일 선택 취소됨")
                    showingFilePicker = false
                } onViewServiceError: {
                    print("⚠️ [FileUploadView] DocumentPicker View Service 에러 감지")
                    showingFilePicker = false
                    handlePickerViewServiceError()
                }
            }
            .sheet(isPresented: $viewModel.showSummaryConfig) {
                if let processedDocument = viewModel.processedDocument {
                    SummaryConfigView(processedDocument: processedDocument)
                }
            }
            .alert("파일 선택 오류", isPresented: $showRetryAlert) {
                Button("다시 시도") {
                    retryFilePicker()
                }
                Button("취소", role: .cancel) { }
            } message: {
                if isSimulator {
                    Text("시뮬레이터에서 첫 번째 파일 선택이 실패했습니다.\n이는 알려진 시뮬레이터 문제입니다.\n\n다시 시도하면 정상 작동합니다.")
                } else {
                    Text("파일 선택 중 오류가 발생했습니다.\n다시 시도해주세요.")
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
                
                // 시뮬레이터 환경 감지
                #if targetEnvironment(simulator)
                isSimulator = true
                print("🔍 [FileUploadView] 시뮬레이터 환경 감지됨")
                #else
                isSimulator = false
                print("🔍 [FileUploadView] 실제 기기 환경")
                #endif
                
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
    
    // MARK: - File Selection Handler
    private func handleFileSelection(_ url: URL) {
        print("🔍 [FileUploadView] 파일 선택 처리 시작")
        
        shouldStayOpen = true
        preventDismiss = true
        
        DispatchQueue.main.async {
            viewModel.handleFileSelection(url)
        }
        
        print("🔍 [FileUploadView] 파일 선택 처리 완료")
    }
    
    // MARK: - DocumentPicker Error Handling
    private func handlePickerViewServiceError() {
        pickerAttemptCount += 1
        print("🔧 [FileUploadView] DocumentPicker 시도 횟수: \(pickerAttemptCount)")
        
        if pickerAttemptCount < 3 && isSimulator {
            // 시뮬레이터에서 자동 재시도
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🔄 [FileUploadView] 시뮬레이터에서 자동 재시도 (\(pickerAttemptCount + 1)번째)")
                retryFilePicker()
            }
        } else {
            // 재시도 알림 표시
            showRetryAlert = true
        }
    }
    
    private func retryFilePicker() {
        print("🔄 [FileUploadView] DocumentPicker 재시도")
        
        // 충분한 지연 시간을 두고 재시도
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showingFilePicker = true
        }
    }
    
    // MARK: - Header Section - Clear Instructions
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(getHeaderColor().opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: getHeaderIcon())
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(getHeaderColor())
            }
            
            // Title & Instructions
            VStack(spacing: 12) {
                Text(getHeaderTitle())
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(getHeaderDescription())
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
    }
    
    // MARK: - Upload Section - Enhanced for simulator compatibility
    private var uploadSection: some View {
        VStack(spacing: 20) {
            // Main Upload Button
            Button(action: {
                print("🔍 [FileUploadView] 파일 선택 버튼 클릭")
                
                // 시뮬레이터에서 더 긴 지연 시간 적용
                let delay = isSimulator ? 0.3 : 0.1
                
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    pickerAttemptCount = 0
                    showingFilePicker = true
                }
            }) {
                VStack(spacing: 20) {
                    // Upload Icon
                    ZStack {
                        Circle()
                            .fill(getUploadIconColor().opacity(0.15))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: getUploadIconName())
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundColor(getUploadIconColor())
                    }
                    
                    // Upload Text
                    VStack(spacing: 8) {
                        Text(getUploadButtonText())
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        
                        if !viewModel.isFileSelected {
                            VStack(spacing: 4) {
                                Text("PDF 또는 Word 파일 (최대 10MB)")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                
                                if isSimulator && pickerAttemptCount > 0 {
                                    Text("시뮬레이터에서 첫 시도가 실패할 수 있습니다")
                                        .font(.system(size: 14))
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    getUploadBorderColor(),
                                    style: StrokeStyle(
                                        lineWidth: 3,
                                        dash: viewModel.isProcessed ? [] : [12, 8]
                                    )
                                )
                        )
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.isProcessing)
            
            // Loading Indicator
            if viewModel.isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.0)
                    Text("파일 정보 확인 중...")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - File Info Section
    private var fileInfoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("선택된 파일")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                fileInfoRow(
                    icon: "doc.text.fill",
                    title: "파일명",
                    value: viewModel.fileName,
                    color: .blue
                )
                
                fileInfoRow(
                    icon: "externaldrive.fill",
                    title: "파일 크기",
                    value: viewModel.fileSize,
                    color: .green
                )
                
                fileInfoRow(
                    icon: "tag.fill",
                    title: "파일 형식",
                    value: viewModel.fileType,
                    color: .orange
                )
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
        }
    }
    
    // MARK: - Processing Section
    private var processingSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                Text("파일 처리 중...")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("진행률")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(viewModel.processingProgress * 100))%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.blue)
                }
                
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * viewModel.processingProgress, height: 12)
                            .animation(.easeInOut(duration: 0.3), value: viewModel.processingProgress)
                    }
                }
                .frame(height: 12)
                
                Text(getProcessingStatusText())
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.05))
            )
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Content Preview Section
    private var contentPreviewSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "eye.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.green)
                }
                
                Text("내용 미리보기")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let doc = viewModel.processedDocument {
                    Text("\(doc.wordCount)단어")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.green)
                        )
                }
            }
            
            ScrollView {
                Text(viewModel.contentPreview.isEmpty ? "내용을 불러오는 중..." : viewModel.contentPreview)
                    .font(.system(size: 16))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(viewModel.contentPreview.isEmpty ? .secondary : .primary)
            }
            .frame(maxHeight: 200)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemGroupedBackground))
            )
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - File Info Row
    private func fileInfoRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Bottom Buttons
    private var bottomButtons: some View {
        VStack(spacing: 16) {
            // Primary Action Button
            Button(action: {
                viewModel.proceedToNextStep()
            }) {
                HStack(spacing: 12) {
                    if viewModel.isProcessing {
                        ProgressView()
                            .scaleEffect(0.9)
                            .foregroundColor(.white)
                    } else {
                        Text(viewModel.isProcessed ? "요약 설정하기" : "파일 처리하기")
                            .font(.system(size: 18, weight: .bold))
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18) // Large touch target
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            viewModel.isProcessing ?
                            LinearGradient(colors: [Color.gray, Color.gray.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(
                            color: viewModel.isProcessing ? .clear : .blue.opacity(0.3),
                            radius: 8, x: 0, y: 4
                        )
                )
            }
            .disabled(viewModel.isProcessing)
            
            // Secondary Actions
            HStack(spacing: 24) {
                Button("다른 파일 선택") {
                    viewModel.clearSelectedFile()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
                
                if viewModel.isProcessed {
                    Button("다시 처리") {
                        viewModel.reprocessContent()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.orange)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getHeaderIcon() -> String {
        if viewModel.isProcessed {
            return "checkmark.circle.fill"
        } else if viewModel.isFileSelected {
            return "doc.text.fill"
        } else {
            return "doc.badge.plus"
        }
    }
    
    private func getHeaderColor() -> Color {
        if viewModel.isProcessed {
            return .green
        } else if viewModel.isFileSelected {
            return .blue
        } else {
            return .blue
        }
    }
    
    private func getHeaderTitle() -> String {
        if viewModel.isProcessed {
            return "처리 완료!"
        } else if viewModel.isFileSelected {
            return "파일이 선택되었습니다"
        } else {
            return "문서를 선택해주세요"
        }
    }
    
    private func getHeaderDescription() -> String {
        if viewModel.isProcessed {
            return "문서 내용을 성공적으로 처리했습니다.\n이제 요약 설정을 진행해주세요."
        } else if viewModel.isFileSelected {
            return "선택된 파일을 처리하여\n카드뉴스로 변환할 준비가 되었습니다."
        } else {
            return "PDF 또는 Word 파일을 업로드하여\n카드뉴스로 변환할 수 있습니다."
        }
    }
    
    private func getUploadIconName() -> String {
        if viewModel.isProcessed {
            return "checkmark.circle.fill"
        } else if viewModel.isFileSelected {
            return "doc.fill"
        } else {
            return "plus.circle.fill"
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
            return "파일 선택하기"
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
            return "파일을 읽고 있습니다..."
        } else if progress < 0.8 {
            return "텍스트를 추출하고 있습니다..."
        } else if progress < 1.0 {
            return "내용을 정리하고 있습니다..."
        } else {
            return "처리가 완료되었습니다!"
        }
    }
}

// MARK: - Enhanced Document Picker Wrapper

struct DocumentPickerWrapper: View {
    let onFileSelected: (URL) -> Void
    let onCancel: () -> Void
    let onViewServiceError: () -> Void
    
    var body: some View {
        NavigationView {
            StableDocumentPicker(
                onFileSelected: onFileSelected,
                onViewServiceError: onViewServiceError
            )
            .navigationTitle("파일 선택")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        onCancel()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Enhanced Stable Document Picker

struct StableDocumentPicker: UIViewControllerRepresentable {
    let onFileSelected: (URL) -> Void
    let onViewServiceError: () -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.pdf, .data],
            asCopy: true
        )
        
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        
        // 시뮬레이터 최적화 설정
        #if targetEnvironment(simulator)
        picker.modalPresentationStyle = .fullScreen
        #endif
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: StableDocumentPicker
        private var hasHandledResult = false
        
        init(_ parent: StableDocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard !hasHandledResult else { return }
            hasHandledResult = true
            
            guard let url = urls.first else { return }
            
            let fileExtension = url.pathExtension.lowercased()
            guard ["pdf", "docx"].contains(fileExtension) else { return }
            
            print("🔍 [StableDocumentPicker] 파일 선택됨: \(url.lastPathComponent)")
            
            DispatchQueue.main.async {
                self.parent.onFileSelected(url)
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            guard !hasHandledResult else { return }
            hasHandledResult = true
            
            print("🔍 [StableDocumentPicker] 사용자가 취소함")
        }
        
        // View Controller 생명주기 관리
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            // View Service 에러로 인한 예기치 않은 dismiss 감지
            if !hasHandledResult {
                print("⚠️ [StableDocumentPicker] View Service 에러로 인한 예기치 않은 dismiss")
                DispatchQueue.main.async {
                    self.parent.onViewServiceError()
                }
            }
        }
    }
}

#Preview {
    FileUploadView()
}
