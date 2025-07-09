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
    @State private var isFirstLaunch = true
    @State private var fileSelectionInProgress = false
    @State private var hasSuccessfullySelectedFile = false
    @State private var selectedFileURL: URL? // ✅ NEW: 선택된 파일 URL 저장
    
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
                        
                        // ✅ NEW: 사용자 취소 알림 전송
                        NotificationCenter.default.post(name: .fileUploadUserCancelled, object: nil)
                        
                        shouldStayOpen = false
                        preventDismiss = false
                        isFirstLaunch = false
                        fileSelectionInProgress = false
                        hasSuccessfullySelectedFile = false
                        selectedFileURL = nil
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                }
            }
            .sheet(isPresented: $showingFilePicker) {
                SafeDocumentPickerView { result in
                    handleFilePickerResult(result)
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
                    Text("시뮬레이터에서 파일 선택 중 오류가 발생했습니다.\n실제 기기에서는 정상 작동합니다.\n\n다시 시도해보세요.")
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
                fileSelectionInProgress = false
                hasSuccessfullySelectedFile = false
                print("🔍 [FileUploadView] 뷰 나타남 - 모달 보호 활성화")
                
                if let file = preselectedFile {
                    print("🔍 [FileUploadView] 미리 선택된 파일 로드: \(file.lastPathComponent)")
                    selectedFileURL = file // ✅ 저장
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        viewModel.handleFileSelection(file)
                    }
                }
            }
            .onDisappear {
                print("🔍 [FileUploadView] onDisappear 호출")
                print("🔍 [FileUploadView] 상태: shouldStayOpen=\(shouldStayOpen), preventDismiss=\(preventDismiss)")
                print("🔍 [FileUploadView] 파일상태: isFileSelected=\(viewModel.isFileSelected), hasSuccessfullySelectedFile=\(hasSuccessfullySelectedFile)")
                print("🔍 [FileUploadView] 선택상태: fileSelectionInProgress=\(fileSelectionInProgress), isFirstLaunch=\(isFirstLaunch)")
                
                // ✅ IMPROVED: 파일 선택 성공 여부를 더 정확히 체크
                if shouldStayOpen && preventDismiss && !showingFilePicker {
                    // 파일이 성공적으로 선택되었거나 ViewModel에서 파일이 선택된 상태라면 정상 종료
                    if hasSuccessfullySelectedFile || viewModel.isFileSelected {
                        print("✅ [FileUploadView] 파일 선택 완료 - View Service disconnect는 정상 (무시)")
                    }
                    // 첫 번째 시도에서 파일 선택이 실제로 실패한 경우에만 재시도 요청
                    else if isFirstLaunch && fileSelectionInProgress && !hasSuccessfullySelectedFile {
                        print("🔧 [FileUploadView] 첫 번째 시도 실패 감지 - MainView에 재시도 요청")
                        
                        // MainView에게 재시도 요청 Notification 전송
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            NotificationCenter.default.post(
                                name: .fileUploadFirstAttemptFailed,
                                object: nil
                            )
                        }
                    } else {
                        print("⚠️ [FileUploadView] 예상치 못한 모달 닫힘 (기타 사유)")
                    }
                } else {
                    print("✅ [FileUploadView] 정상적인 모달 닫힘")
                }
            }
            .onChange(of: showingFilePicker) { _, newValue in
                print("🔍 [FileUploadView] showingFilePicker 변경: \(newValue)")
                
                if newValue {
                    fileSelectionInProgress = true
                    if isFirstLaunch {
                        print("🔧 [FileUploadView] 첫 번째 파일 피커 열림")
                    } else {
                        print("🔧 [FileUploadView] 파일 피커 열림 (재시도)")
                    }
                } else {
                    print("🔧 [FileUploadView] 파일 피커 닫힘")
                }
            }
            .onChange(of: viewModel.isFileSelected) { _, newValue in
                print("🔍 [FileUploadView] isFileSelected 변경: \(newValue)")
                
                if newValue {
                    shouldStayOpen = true
                    preventDismiss = true
                    fileSelectionInProgress = false // 파일 선택 완료
                    hasSuccessfullySelectedFile = true // 성공적 파일 선택 마크
                    isFirstLaunch = false // 성공했으므로 더 이상 첫 번째가 아님
                    
                    // ✅ IMPROVED: 파일 선택 성공 알림 전송 (파일 정보 포함)
                    if let fileURL = selectedFileURL {
                        NotificationCenter.default.post(name: .fileUploadSuccess, object: fileURL)
                        print("🎉 [FileUploadView] 파일 선택 성공 알림 전송: \(fileURL.lastPathComponent)")
                    } else {
                        NotificationCenter.default.post(name: .fileUploadSuccess, object: nil)
                        print("🎉 [FileUploadView] 파일 선택 성공 알림 전송 (파일 정보 없음)")
                    }
                    
                    print("🔧 [FileUploadView] 파일 선택 완료 - 모달 보호 강화 및 성공 상태 설정")
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
    
    // MARK: - File Selection Result Processing
    private func handleFilePickerResult(_ result: Result<URL, Error>) {
        print("🔍 [FileUploadView] 파일 선택 결과 수신")
        
        DispatchQueue.main.async {
            showingFilePicker = false
            processFileSelectionResult(result)
        }
    }
    
    private func processFileSelectionResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("✅ [FileUploadView] 파일 선택 성공: \(url.lastPathComponent)")
            fileSelectionInProgress = false
            hasSuccessfullySelectedFile = true // 성공 상태 즉시 설정
            selectedFileURL = url // ✅ 파일 URL 저장
            isFirstLaunch = false
            handleFileSelection(url)
            pickerAttemptCount = 0 // 성공 시 카운트 리셋
            
        case .failure(let error):
            print("❌ [FileUploadView] 파일 선택 실패: \(error)")
            hasSuccessfullySelectedFile = false
            selectedFileURL = nil // ✅ 실패 시 클리어
            // 실패 시에는 fileSelectionInProgress를 유지하여 재시도 로직이 작동하도록 함
            handlePickerError(error)
        }
    }
    
    // MARK: - File Selection Handler
    private func handleFileSelection(_ url: URL) {
        print("🔍 [FileUploadView] 파일 선택 처리 시작")
        
        shouldStayOpen = true
        preventDismiss = true
        selectedFileURL = url // ✅ 파일 URL 저장
        
        DispatchQueue.main.async {
            viewModel.handleFileSelection(url)
        }
        
        print("🔍 [FileUploadView] 파일 선택 처리 완료")
    }
    
    // MARK: - DocumentPicker Error Handling
    private func handlePickerError(_ error: Error) {
        pickerAttemptCount += 1
        print("🔧 [FileUploadView] DocumentPicker 시도 횟수: \(pickerAttemptCount)")
        
        if pickerAttemptCount < 3 && isSimulator {
            // 시뮬레이터에서 자동 재시도
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("🔄 [FileUploadView] 시뮬레이터에서 자동 재시도 (\(pickerAttemptCount + 1)번째)")
                retryFilePicker()
            }
        } else {
            // 재시도 알림 표시
            fileSelectionInProgress = false
            showRetryAlert = true
        }
    }
    
    private func retryFilePicker() {
        print("🔄 [FileUploadView] DocumentPicker 재시도")
        
        // 충분한 지연 시간을 두고 재시도
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isFirstLaunch = false
            fileSelectionInProgress = false
            hasSuccessfullySelectedFile = false
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
                
                // 지연 시간 적용
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
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
                                    Text("시뮬레이터에서 문제가 발생할 수 있습니다")
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

// MARK: - Safe Document Picker View (완전 분리된 뷰)

struct SafeDocumentPickerView: View {
    let onResult: (Result<URL, Error>) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var hasProcessedResult = false
    
    var body: some View {
        NavigationView {
            SafeDocumentPickerRepresentable { result in
                guard !hasProcessedResult else { return }
                hasProcessedResult = true
                
                print("📁 [SafeDocumentPicker] 결과 수신: \(result)")
                
                DispatchQueue.main.async {
                    onResult(result)
                }
            }
            .navigationTitle("파일 선택")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        guard !hasProcessedResult else { return }
                        hasProcessedResult = true
                        
                        print("📁 [SafeDocumentPicker] 사용자 취소")
                        DispatchQueue.main.async {
                            onResult(.failure(DocumentPickerError.userCancelled))
                        }
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                }
            }
        }
        .interactiveDismissDisabled(true) // 의도치 않은 닫힘 방지
    }
}

// MARK: - Safe Document Picker Representable (개선된 버전)

struct SafeDocumentPickerRepresentable: UIViewControllerRepresentable {
    let onResult: (Result<URL, Error>) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.pdf, .data],
            asCopy: true  // ⭐️ CRITICAL: 파일을 앱으로 복사
        )
        
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onResult: (Result<URL, Error>) -> Void
        private var hasProcessedResult = false
        
        init(onResult: @escaping (Result<URL, Error>) -> Void) {
            self.onResult = onResult
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard !hasProcessedResult else { return }
            hasProcessedResult = true
            
            guard let url = urls.first else {
                onResult(.failure(DocumentPickerError.noFileSelected))
                return
            }
            
            let fileExtension = url.pathExtension.lowercased()
            guard ["pdf", "docx"].contains(fileExtension) else {
                onResult(.failure(DocumentPickerError.unsupportedFileType))
                return
            }
            
            print("✅ [SafeDocumentPicker] 파일 선택 성공: \(url.lastPathComponent)")
            print("🔍 [SafeDocumentPicker] 파일 경로: \(url.path)")
            print("🔍 [SafeDocumentPicker] URL 스킴: \(url.scheme ?? "없음")")
            print("🔍 [SafeDocumentPicker] 파일 존재 여부: \(FileManager.default.fileExists(atPath: url.path))")
            
            // ⭐️ IMPROVED: 다중 전략으로 파일 처리
            processFileWithMultipleStrategies(url: url, fileExtension: fileExtension)
        }
        
        private func processFileWithMultipleStrategies(url: URL, fileExtension: String) {
            // ⭐️ CRITICAL: 파일이 이미 앱 샌드박스에 있는지 확인
            if isFileInAppSandbox(url: url) {
                print("🎯 [SafeDocumentPicker] Strategy 0: 파일이 이미 앱 샌드박스에 있음 - 직접 사용")
                if tryDirectAccessInSandbox(url: url) {
                    return
                }
            }
            
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
            
            // Strategy 4: Document Interaction Controller 방식
            if tryDocumentInteractionMethod(url: url, fileExtension: fileExtension) {
                return
            }
            
            // Strategy 5: 최종 백업 - 원본 URL 그대로 전달
            print("⚠️ [SafeDocumentPicker] 모든 접근 방법 실패 - 원본 URL로 시도")
            onResult(.success(url))
        }
        
        // ⭐️ NEW: 파일이 앱 샌드박스에 있는지 확인
        private func isFileInAppSandbox(url: URL) -> Bool {
            let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
            let sandboxIdentifier = "com.devjihwan.cardnewsapp.CardNewsApp"
            
            // 경로에 앱 식별자가 포함되어 있는지 확인
            return url.path.contains(bundleIdentifier) || url.path.contains(sandboxIdentifier)
        }
        
        // ⭐️ NEW: 앱 샌드박스 내 파일 직접 접근
        private func tryDirectAccessInSandbox(url: URL) -> Bool {
            print("🔍 [SafeDocumentPicker] Strategy 0: 샌드박스 내 파일 직접 접근 시도")
            
            // 파일 존재 확인
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("❌ [SafeDocumentPicker] Strategy 0 실패: 파일이 존재하지 않음")
                return false
            }
            
            // 파일 읽기 권한 확인
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                print("❌ [SafeDocumentPicker] Strategy 0 실패: 파일 읽기 권한 없음")
                return false
            }
            
            // 실제 데이터 읽기 테스트
            do {
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                guard data.count > 0 else {
                    print("❌ [SafeDocumentPicker] Strategy 0 실패: 빈 파일")
                    return false
                }
                
                print("✅ [SafeDocumentPicker] Strategy 0 성공: 샌드박스 내 직접 접근 (크기: \(data.count) bytes)")
                onResult(.success(url))
                return true
                
            } catch {
                print("❌ [SafeDocumentPicker] Strategy 0 실패: 데이터 읽기 오류 - \(error)")
                return false
            }
        }
        
        // Strategy 1: asCopy=true인 경우 직접 접근
        private func tryDirectAccess(url: URL, fileExtension: String) -> Bool {
            print("🔍 [SafeDocumentPicker] Strategy 1: 직접 접근 시도")
            
            // 파일 존재 확인
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("❌ [SafeDocumentPicker] Strategy 1 실패: 파일이 존재하지 않음")
                return false
            }
            
            // 파일 읽기 권한 확인
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                print("❌ [SafeDocumentPicker] Strategy 1 실패: 파일 읽기 권한 없음")
                return false
            }
            
            // 실제 데이터 읽기 테스트
            do {
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                guard data.count > 0 else {
                    print("❌ [SafeDocumentPicker] Strategy 1 실패: 빈 파일")
                    return false
                }
                
                print("✅ [SafeDocumentPicker] Strategy 1 성공: 직접 접근 (크기: \(data.count) bytes)")
                onResult(.success(url))
                return true
                
            } catch {
                print("❌ [SafeDocumentPicker] Strategy 1 실패: 데이터 읽기 오류 - \(error)")
                return false
            }
        }
        
        // Strategy 2: Security-Scoped Resource 접근
        private func trySecurityScopedAccess(url: URL, fileExtension: String) -> Bool {
            print("🔍 [SafeDocumentPicker] Strategy 2: Security-Scoped Resource 접근 시도")
            
            // Security-Scoped Resource 접근 시작
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ [SafeDocumentPicker] Strategy 2 실패: Security-Scoped Resource 접근 실패")
                return false
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
                print("🔓 [SafeDocumentPicker] Security-Scoped Resource 접근 종료")
            }
            
            print("🔐 [SafeDocumentPicker] Security-Scoped Resource 접근 성공")
            
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
                
                // 복사된 파일 검증
                let copiedData = try Data(contentsOf: tempURL)
                guard copiedData.count > 0 else {
                    throw DocumentPickerError.viewServiceError
                }
                
                print("✅ [SafeDocumentPicker] Strategy 2 성공: 파일 복사 완료 (크기: \(copiedData.count) bytes)")
                onResult(.success(tempURL))
                return true
                
            } catch {
                print("❌ [SafeDocumentPicker] Strategy 2 실패: 파일 복사 오류 - \(error)")
                return false
            }
        }
        
        // Strategy 3: 파일명 정규화 후 재시도
        private func tryWithNormalizedFilename(url: URL, fileExtension: String) -> Bool {
            print("🔍 [SafeDocumentPicker] Strategy 3: 파일명 정규화 후 재시도")
            
            let tempDirectory = FileManager.default.temporaryDirectory
            let normalizedFileName = sanitizeFileName(url.lastPathComponent, extension: fileExtension)
            let normalizedURL = tempDirectory.appendingPathComponent(normalizedFileName)
            
            // Security-Scoped Resource 접근 시도
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                return copyWithNormalizedName(from: url, to: normalizedURL)
            } else {
                // Security-Scoped 없이도 시도해볼 수 있음
                print("⚠️ [SafeDocumentPicker] Strategy 3: Security-Scoped 접근 없이 시도")
                return copyWithNormalizedName(from: url, to: normalizedURL)
            }
        }
        
        // Strategy 4: Document Interaction Controller 방식
        private func tryDocumentInteractionMethod(url: URL, fileExtension: String) -> Bool {
            print("🔍 [SafeDocumentPicker] Strategy 4: Document Interaction 방식 시도")
            
            // URL의 bookmarkData 생성 시도
            do {
                let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                
                // bookmarkData에서 URL 복원
                var isStale = false
                let resolvedURL = try URL(resolvingBookmarkData: bookmarkData, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale)
                
                if !isStale {
                    print("✅ [SafeDocumentPicker] Strategy 4 성공: bookmark 방식")
                    onResult(.success(resolvedURL))
                    return true
                }
                
            } catch {
                print("❌ [SafeDocumentPicker] Strategy 4 실패: bookmark 오류 - \(error)")
            }
            
            return false
        }
        
        private func copyWithNormalizedName(from sourceURL: URL, to destinationURL: URL) -> Bool {
            do {
                // 기존 파일 삭제
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // 파일 복사
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                
                // 복사된 파일 검증
                let copiedData = try Data(contentsOf: destinationURL)
                guard copiedData.count > 0 else {
                    throw DocumentPickerError.viewServiceError
                }
                
                print("✅ [SafeDocumentPicker] Strategy 3 성공: 정규화된 파일명으로 복사 (크기: \(copiedData.count) bytes)")
                onResult(.success(destinationURL))
                return true
                
            } catch {
                print("❌ [SafeDocumentPicker] Strategy 3 실패: \(error)")
                return false
            }
        }
        
        // 파일명 정규화 (특수문자, 긴 한글명 처리)
        private func sanitizeFileName(_ fileName: String, extension fileExtension: String) -> String {
            // 확장자 제거
            let nameWithoutExtension = fileName.replacingOccurrences(of: ".\(fileExtension)", with: "")
            
            // 특수문자 제거 및 길이 제한
            let sanitized = nameWithoutExtension
                .replacingOccurrences(of: "[\\/:\\*\\?\"<>\\|\\(\\)]", with: "_", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression)
                .replacingOccurrences(of: "[^a-zA-Z0-9가-힣_]", with: "_", options: .regularExpression)
                .prefix(30) // 파일명 길이 제한을 더 짧게
            
            // UUID 추가로 중복 방지
            let shortUUID = UUID().uuidString.prefix(8)
            return "\(sanitized)_\(shortUUID).\(fileExtension)"
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            guard !hasProcessedResult else { return }
            hasProcessedResult = true
            
            print("🔄 [SafeDocumentPicker] 선택 취소됨")
            onResult(.failure(DocumentPickerError.userCancelled))
        }
    }
}

// MARK: - Enhanced Document Picker Errors

enum DocumentPickerError: LocalizedError, CustomStringConvertible {
    case userCancelled
    case noFileSelected
    case unsupportedFileType
    case viewServiceError
    case fileAccessDenied
    case fileCorrupted
    case securityScopedResourceFailed
    
    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "파일 선택이 취소되었습니다"
        case .noFileSelected:
            return "파일이 선택되지 않았습니다"
        case .unsupportedFileType:
            return "지원하지 않는 파일 형식입니다 (PDF 또는 DOCX만 지원)"
        case .viewServiceError:
            return "파일 선택 중 시스템 오류가 발생했습니다"
        case .fileAccessDenied:
            return "파일에 접근할 수 없습니다. 권한을 확인해주세요"
        case .fileCorrupted:
            return "파일이 손상되었거나 읽을 수 없습니다"
        case .securityScopedResourceFailed:
            return "파일 보안 접근 권한을 얻을 수 없습니다"
        }
    }
    
    var description: String {
        return errorDescription ?? "알 수 없는 오류"
    }
}

#Preview {
    FileUploadView()
}