import SwiftUI
import Photos

struct SummaryResultView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var currentCardIndex = 0
    @State private var showShareSheet = false
    @State private var showSaveConfirmation = false
    @State private var saveError: String?
    @State private var showSaveError = false
    @State private var cardScale: CGFloat = 1.0
    @State private var isSavingAll = false // 🆕 모든 카드 저장 중 상태
    @State private var saveProgress = 0 // 🆕 저장 진행도
    
    let summaryResult: SummaryResult
    
    init(summaryResult: SummaryResult) {
        self.summaryResult = summaryResult
        
        // 디버깅 로그 추가
        print("🔍 [SummaryResultView] 초기화 시작")
        print("📄 [SummaryResultView] 파일명: \(summaryResult.originalDocument.fileName)")
        print("🎯 [SummaryResultView] 카드 수: \(summaryResult.cards.count)장")
        print("⚙️ [SummaryResultView] 설정: \(summaryResult.config.cardCount.displayName), \(summaryResult.config.outputStyle.displayName)")
        
        // 각 카드 내용 확인
        for (index, card) in summaryResult.cards.enumerated() {
            print("📇 [SummaryResultView] 카드 \(index + 1): '\(card.title)' (내용 길이: \(card.content.count)자)")
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 🎨 Modern Background
                backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 상단 정보 바 - Premium Design
                    topInfoSection
                    
                    // 카드뷰가 비어있는지 확인
                    if summaryResult.cards.isEmpty {
                        emptyStateView
                    } else {
                        // 메인 카드 뷰어
                        cardViewerSection
                        
                        // 하단 컨트롤 - Modern Navigation
                        bottomControlsSection
                    }
                }
                
                // 🆕 저장 진행 상태 오버레이
                if isSavingAll {
                    saveProgressOverlay
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        print("🔍 [SummaryResultView] 완료 버튼 클릭 - 모든 모달 닫기")
                        // 모든 모달을 닫는 노티피케이션 발송
                        NotificationCenter.default.post(name: .dismissAllModals, object: nil)
                        dismiss()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("완료")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(AppColors.primaryStart)
                    }
                    .disabled(isSavingAll) // 🆕 저장 중일 때 비활성화
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    actionMenuButton
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityViewController(activityItems: generateShareContent())
            }
            .alert("저장 완료", isPresented: $showSaveConfirmation) {
                Button("확인") { }
            } message: {
                Text(isSavingAll ? "모든 카드가 갤러리에 저장되었습니다." : "카드뉴스가 갤러리에 저장되었습니다.")
            }
            .alert("저장 실패", isPresented: $showSaveError) {
                Button("확인") { 
                    isSavingAll = false // 🆕 오류 시 저장 상태 초기화
                }
            } message: {
                Text(saveError ?? "갤러리 저장 중 오류가 발생했습니다.")
            }
            .onAppear {
                print("🔍 [SummaryResultView] 화면 표시됨")
                print("📊 [SummaryResultView] 현재 카드 인덱스: \(currentCardIndex)")
                print("📋 [SummaryResultView] 총 카드 수: \(summaryResult.cards.count)")
            }
        }
    }
    
    // MARK: - 🆕 Save Progress Overlay
    private var saveProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // 진행 상태 표시
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(saveProgress) / CGFloat(summaryResult.cards.count))
                            .stroke(AppGradients.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: saveProgress)
                        
                        Text("\(saveProgress)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 8) {
                        Text("갤러리에 저장 중...")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("\(saveProgress) / \(summaryResult.cards.count) 카드")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                )
            }
        }
    }
    
    // MARK: - Background Gradient
    private var backgroundGradient: some View {
        AppGradients.backgroundLight
            .overlay(
                Color.white.opacity(colorScheme == .light ? 0.9 : 0.1)
            )
    }
    
    // MARK: - Action Menu Button
    private var actionMenuButton: some View {
        Menu {
            Button(action: { showShareSheet = true }) {
                Label("공유하기", systemImage: "square.and.arrow.up")
            }
            .disabled(isSavingAll) // 🆕 저장 중일 때 비활성화
            
            Button(action: { saveCurrentCard() }) {
                Label("현재 카드 저장", systemImage: "square.and.arrow.down")
            }
            .disabled(isSavingAll) // 🆕 저장 중일 때 비활성화
            
            Button(action: { saveAllCards() }) {
                Label("모든 카드 저장", systemImage: "rectangle.stack")
            }
            .disabled(isSavingAll) // 🆕 저장 중일 때 비활성화
            
            Divider()
            
            Button(action: { exportAsPDF() }) {
                Label("PDF로 내보내기", systemImage: "doc.fill")
            }
            .disabled(isSavingAll) // 🆕 저장 중일 때 비활성화
        } label: {
            ZStack {
                Circle()
                    .fill(AppColors.primaryStart.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.primaryStart)
                    .opacity(isSavingAll ? 0.5 : 1.0) // 🆕 저장 중일 때 반투명
            }
        }
        .disabled(isSavingAll) // 🆕 저장 중일 때 비활성화
    }
    
    // MARK: - Top Info Section
    private var topInfoSection: some View {
        VStack(spacing: 16) {
            // 문서 정보 헤더
            HStack(spacing: 16) {
                // 문서 아이콘
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppGradients.primary)
                        .frame(width: 48, height: 48)
                        .shadow(color: AppColors.primaryStart.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                // 문서 정보
                VStack(alignment: .leading, spacing: 6) {
                    Text(summaryResult.originalDocument.fileName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.3.group.fill")
                                .font(.system(size: 12, weight: .medium))
                            Text(summaryResult.config.cardCount.displayName)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(AppColors.primaryStart)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "paintbrush.fill")
                                .font(.system(size: 12, weight: .medium))
                            Text(summaryResult.config.outputStyle.displayName)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(AppColors.accent)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .font(.system(size: 12, weight: .medium))
                            Text(summaryResult.config.language.displayName)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(AppColors.success)
                    }
                }
                
                Spacer()
                
                // 카드 진행도
                VStack(alignment: .trailing, spacing: 6) {
                    if !summaryResult.cards.isEmpty {
                        Text("\(currentCardIndex + 1)/\(summaryResult.cards.count)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                    } else {
                        Text("0/0")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppColors.error)
                    }
                    
                    Text(formatDate(summaryResult.createdAt))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            // 진행도 바
            if !summaryResult.cards.isEmpty {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppGradients.primary)
                            .frame(
                                width: geometry.size.width * CGFloat(currentCardIndex + 1) / CGFloat(summaryResult.cards.count),
                                height: 6
                            )
                            .animation(.easeInOut(duration: 0.3), value: currentCardIndex)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(AppColors.error.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "doc.questionmark")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(AppColors.error)
            }
            
            VStack(spacing: 12) {
                Text("카드뉴스를 불러올 수 없습니다")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("저장된 데이터에 문제가 있을 수 있습니다.\n다시 시도해주세요.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            
            Button("다시 시도") {
                print("🔍 [SummaryResultView] 다시 시도 버튼 클릭")
                dismiss()
            }
            .premiumButton(gradient: AppGradients.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - Card Viewer Section
    private var cardViewerSection: some View {
        TabView(selection: $currentCardIndex) {
            ForEach(Array(summaryResult.cards.enumerated()), id: \.offset) { index, card in
                ModernCardView(
                    card: card,
                    config: summaryResult.config,
                    isCurrentCard: currentCardIndex == index
                )
                .tag(index)
                .scaleEffect(cardScale)
                .onTapGesture(count: 2) {
                    // Double tap to zoom
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        cardScale = cardScale == 1.0 ? 1.2 : 1.0
                    }
                }
                .onAppear {
                    print("🔍 [SummaryResultView] 카드 \(index + 1) 표시됨: '\(card.title)'")
                }
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .onChange(of: currentCardIndex) { oldValue, newValue in
            print("🔍 [SummaryResultView] 카드 변경: \(oldValue + 1) → \(newValue + 1)")
            
            // Reset zoom when changing cards
            withAnimation(.easeInOut(duration: 0.2)) {
                cardScale = 1.0
            }
        }
    }
    
    // MARK: - Bottom Controls Section
    private var bottomControlsSection: some View {
        VStack(spacing: 20) {
            // 페이지 인디케이터 - Modern Dots
            HStack(spacing: 8) {
                ForEach(0..<summaryResult.cards.count, id: \.self) { index in
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            currentCardIndex = index
                        }
                    }) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                currentCardIndex == index ?
                                AppGradients.primary :
                                LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(
                                width: currentCardIndex == index ? 24 : 8,
                                height: 8
                            )
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentCardIndex)
                    }
                    .disabled(isSavingAll) // 🆕 저장 중일 때 비활성화
                }
            }
            
            // 네비게이션 컨트롤 - Modern Design
            HStack(spacing: 24) {
                // Previous Button
                Button(action: { previousCard() }) {
                    ZStack {
                        Circle()
                            .fill(currentCardIndex > 0 ? AppGradients.primary : AppGradients.disabled)
                            .frame(width: 56, height: 56)
                            .shadow(
                                color: currentCardIndex > 0 ? AppColors.primaryStart.opacity(0.3) : .clear,
                                radius: currentCardIndex > 0 ? 8 : 0,
                                x: 0,
                                y: currentCardIndex > 0 ? 4 : 0
                            )
                        
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(currentCardIndex <= 0 || isSavingAll) // 🆕 저장 중일 때 비활성화
                .scaleEffect(currentCardIndex > 0 ? 1.0 : 0.9)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentCardIndex)
                
                // Current Card Info
                if currentCardIndex < summaryResult.cards.count {
                    VStack(spacing: 8) {
                        Text("카드 \(currentCardIndex + 1)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(summaryResult.cards[currentCardIndex].title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    VStack {
                        Text("오류")
                            .font(.caption)
                            .foregroundColor(AppColors.error)
                        
                        Text("카드 인덱스 오류")
                            .font(.subheadline)
                            .foregroundColor(AppColors.error)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Next Button
                Button(action: { nextCard() }) {
                    ZStack {
                        Circle()
                            .fill(currentCardIndex < summaryResult.cards.count - 1 ? AppGradients.primary : AppGradients.disabled)
                            .frame(width: 56, height: 56)
                            .shadow(
                                color: currentCardIndex < summaryResult.cards.count - 1 ? AppColors.primaryStart.opacity(0.3) : .clear,
                                radius: currentCardIndex < summaryResult.cards.count - 1 ? 8 : 0,
                                x: 0,
                                y: currentCardIndex < summaryResult.cards.count - 1 ? 4 : 0
                            )
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(currentCardIndex >= summaryResult.cards.count - 1 || isSavingAll) // 🆕 저장 중일 때 비활성화
                .scaleEffect(currentCardIndex < summaryResult.cards.count - 1 ? 1.0 : 0.9)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentCardIndex)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: -2)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - Helper Methods
    
    private func previousCard() {
        guard currentCardIndex > 0 else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentCardIndex -= 1
        }
    }
    
    private func nextCard() {
        guard currentCardIndex < summaryResult.cards.count - 1 else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentCardIndex += 1
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "방금 전"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)분 전"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)시간 전"
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
    
    private func saveCurrentCard() {
        print("🔍 [SummaryResultView] 현재 카드 저장 시작")
        saveToGallery(cardIndex: currentCardIndex)
    }
    
    // MARK: - 🔧 수정된 saveAllCards 함수
    private func saveAllCards() {
        print("🔍 [SummaryResultView] 모든 카드 저장 시작")
        
        // 이미 저장 중이면 무시
        guard !isSavingAll else {
            print("⚠️ [SummaryResultView] 이미 저장 중입니다.")
            return
        }
        
        // 저장 상태 초기화
        isSavingAll = true
        saveProgress = 0
        
        // 먼저 사진 권한 확인
        checkPhotoPermissionAndSaveAll()
    }
    
    // MARK: - 🆕 권한 확인 후 순차 저장
    private func checkPhotoPermissionAndSaveAll() {
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch authStatus {
        case .authorized, .limited:
            // 권한이 있으면 바로 순차 저장 시작
            startSequentialSave()
            
        case .denied, .restricted:
            // 권한이 거부되었으면 오류 표시
            saveError = "사진 라이브러리 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요."
            showSaveError = true
            isSavingAll = false
            
        case .notDetermined:
            // 권한이 결정되지 않았으면 요청
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                DispatchQueue.main.async {
                    if status == .authorized || status == .limited {
                        self.startSequentialSave()
                    } else {
                        self.saveError = "사진 라이브러리 접근 권한이 거부되었습니다."
                        self.showSaveError = true
                        self.isSavingAll = false
                    }
                }
            }
            
        @unknown default:
            saveError = "알 수 없는 권한 상태입니다."
            showSaveError = true
            isSavingAll = false
        }
    }
    
    // MARK: - 🆕 순차적 카드 저장
    private func startSequentialSave() {
        print("🔍 [SummaryResultView] 순차 저장 시작")
        
        // 첫 번째 카드부터 순차적으로 저장
        saveCardAtIndex(0)
    }
    
    private func saveCardAtIndex(_ index: Int) {
        // 모든 카드를 저장했으면 완료
        guard index < summaryResult.cards.count else {
            // 저장 완료
            DispatchQueue.main.async {
                self.isSavingAll = false
                self.saveProgress = 0
                self.showSaveConfirmation = true
                print("✅ [SummaryResultView] 모든 카드 저장 완료")
            }
            return
        }
        
        let card = summaryResult.cards[index]
        print("🔍 [SummaryResultView] 카드 \(index + 1) 저장 중...")
        
        // ModernCardView를 이미지로 렌더링
        let cardView = ModernCardView(card: card, config: summaryResult.config, isCurrentCard: true)
            .frame(width: 375, height: 650) // 카드 크기 고정 (9:16 비율)
        
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0 // 고해상도
        
        guard let uiImage = renderer.uiImage else {
            // 이미지 생성 실패 시 다음 카드로 진행
            print("❌ [SummaryResultView] 카드 \(index + 1) 이미지 생성 실패")
            DispatchQueue.main.async {
                self.saveProgress += 1
                self.saveCardAtIndex(index + 1)
            }
            return
        }
        
        // 사진 라이브러리에 저장
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ [SummaryResultView] 카드 \(index + 1) 저장 성공")
                } else {
                    print("❌ [SummaryResultView] 카드 \(index + 1) 저장 실패: \(error?.localizedDescription ?? "알 수 없는 오류")")
                }
                
                // 진행도 업데이트 후 다음 카드 저장
                self.saveProgress += 1
                
                // 잠시 대기 후 다음 카드 저장 (시스템 부하 방지)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.saveCardAtIndex(index + 1)
                }
            }
        }
    }
    
    // MARK: - 🔧 기존 saveToGallery 함수 (단일 카드용)
    private func saveToGallery(cardIndex: Int? = nil) {
        let targetIndex = cardIndex ?? currentCardIndex
        
        print("🔍 [SummaryResultView] 갤러리 저장 시작 - 카드 \(targetIndex + 1)")
        
        // 사진 권한 확인
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch authStatus {
        case .authorized, .limited:
            performSaveToGallery(cardIndex: targetIndex)
        case .denied, .restricted:
            saveError = "사진 라이브러리 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요."
            showSaveError = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                DispatchQueue.main.async {
                    if status == .authorized || status == .limited {
                        self.performSaveToGallery(cardIndex: targetIndex)
                    } else {
                        self.saveError = "사진 라이브러리 접근 권한이 거부되었습니다."
                        self.showSaveError = true
                    }
                }
            }
        @unknown default:
            saveError = "알 수 없는 권한 상태입니다."
            showSaveError = true
        }
    }
    
    private func performSaveToGallery(cardIndex: Int) {
        // 해당 카드를 이미지로 변환하여 저장
        guard cardIndex < summaryResult.cards.count else {
            saveError = "저장할 카드를 찾을 수 없습니다."
            showSaveError = true
            return
        }
        
        let card = summaryResult.cards[cardIndex]
        
        // ModernCardView를 이미지로 렌더링
        let cardView = ModernCardView(card: card, config: summaryResult.config, isCurrentCard: true)
            .frame(width: 375, height: 650) // 카드 크기 고정 (9:16 비율)
        
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0 // 고해상도
        
        guard let uiImage = renderer.uiImage else {
            saveError = "이미지 생성에 실패했습니다."
            showSaveError = true
            return
        }
        
        // 사진 라이브러리에 저장
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
        }) { [self] success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ [SummaryResultView] 카드 \(cardIndex + 1) 갤러리 저장 성공")
                    showSaveConfirmation = true
                } else {
                    print("❌ [SummaryResultView] 갤러리 저장 실패: \(error?.localizedDescription ?? "알 수 없는 오류")")
                    saveError = error?.localizedDescription ?? "이미지 저장에 실패했습니다."
                    showSaveError = true
                }
            }
        }
    }
    
    private func exportAsPDF() {
        // TODO: PDF 내보내기 기능
        print("🔍 [SummaryResultView] PDF 내보내기 기능 (구현 예정)")
    }
    
    private func generateShareContent() -> [Any] {
        let shareText = """
        📱 CardNews App으로 만든 카드뉴스
        
        📄 원본: \(summaryResult.originalDocument.fileName)
        🎨 스타일: \(summaryResult.config.outputStyle.displayName)
        📊 \(summaryResult.config.cardCount.displayName) 구성
        
        \(summaryResult.cards.enumerated().map { index, card in
            "[카드 \(index + 1)] \(card.title)\n\(card.content)"
        }.joined(separator: "\n\n"))
        """
        
        return [shareText]
    }
}

// MARK: - Modern Card View

struct ModernCardView: View {
    let card: SummaryResult.CardContent
    let config: SummaryConfig
    let isCurrentCard: Bool
    @Environment(\.colorScheme) var colorScheme
    
    init(card: SummaryResult.CardContent, config: SummaryConfig, isCurrentCard: Bool = true) {
        self.card = card
        self.config = config
        self.isCurrentCard = isCurrentCard
        
        print("🔍 [ModernCardView] 카드 \(card.cardNumber) 생성: '\(card.title)' (내용: \(card.content.prefix(50))...)")
        print("🎨 [ModernCardView] 출력 스타일: \(config.outputStyle.displayName)")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 카드 헤더 - Modern Design
            VStack(spacing: 20) {
                // 카드 번호 배지
                HStack {
                    Spacer()
                    
                    ZStack {
                        Capsule()
                            .fill(AppGradients.primary)
                            .frame(width: 80, height: 36)
                            .shadow(color: AppColors.primaryStart.opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        Text("카드 \(card.cardNumber)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                }
                
                // 카드 제목 - Enhanced Typography
                Text(card.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: card.textColor ?? "#000000"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 40)
            
            Spacer()
            
            // 카드 내용 - Improved Typography
            ScrollView {
                VStack(spacing: 16) {
                    Text(card.content)
                        .font(.system(size: 18, weight: .medium))
                        .lineSpacing(6)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color(hex: card.textColor ?? "#000000"))
                        .padding(.horizontal, 32)
                    
                    // ✅ 이미지 플레이스홀더 - 출력 스타일에 따른 조건부 렌더링
                    if config.outputStyle == .image,
                       let imagePrompt = card.imagePrompt, !imagePrompt.isEmpty {
                        VStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.gray.opacity(0.1),
                                            Color.gray.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 140)
                                .overlay(
                                    VStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(AppColors.primaryStart.opacity(0.1))
                                                .frame(width: 48, height: 48)
                                            
                                            Image(systemName: "photo")
                                                .font(.title2)
                                                .foregroundColor(AppColors.primaryStart)
                                        }
                                        
                                        Text("AI 이미지 생성 예정")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            
                            Text("💡 \(imagePrompt)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.gray.opacity(0.1))
                                )
                        }
                        .padding(.horizontal, 32)
                    }
                }
            }
            .frame(maxHeight: 450)
            
            Spacer()
            
            // 하단 장식 - Subtle Footer
            HStack {
                Spacer()
                
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppColors.primaryStart)
                            .frame(width: 4, height: 4)
                        Circle()
                            .fill(AppColors.primaryEnd)
                            .frame(width: 4, height: 4)
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 4, height: 4)
                    }
                    
                    Text("CardNews")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: card.backgroundColor ?? "#FFFFFF"))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(
            color: isCurrentCard ? .black.opacity(0.15) : .black.opacity(0.05),
            radius: isCurrentCard ? 20 : 8,
            x: 0,
            y: isCurrentCard ? 10 : 4
        )
        .scaleEffect(isCurrentCard ? 1.0 : 0.95)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isCurrentCard)
        .onAppear {
            print("🔍 [ModernCardView] 카드 \(card.cardNumber) 화면에 표시됨")
            print("🎨 [ModernCardView] 이미지 표시 여부: \(config.outputStyle == .image ? "예" : "아니오")")
        }
    }
}

// MARK: - Activity View Controller

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview {
    let sampleCards = [
        SummaryResult.CardContent(
            cardNumber: 1,
            title: "AI의 미래와 우리의 일상",
            content: "인공지능은 이제 우리 일상 깊숙이 자리잡고 있습니다. 스마트폰의 음성인식부터 자동차의 자율주행까지, AI는 우리 삶을 편리하게 만들고 있어요. 앞으로 AI가 어떻게 발전할지, 그리고 우리는 어떻게 준비해야 할지 함께 알아보겠습니다.",
            imagePrompt: "미래적인 도시와 AI 로봇이 함께 있는 모습",
            backgroundColor: "#F8FAFF",
            textColor: "#1A1A2E"
        ),
        SummaryResult.CardContent(
            cardNumber: 2,
            title: "AI가 바꾸는 업무 환경",
            content: "AI는 단순 반복 업무를 자동화하여 우리가 더 창의적인 일에 집중할 수 있게 도와줍니다. 문서 작성, 데이터 분석, 고객 응대 등 다양한 영역에서 AI가 활용되고 있어요. 중요한 것은 AI를 두려워하기보다는 어떻게 활용할지 배우는 것입니다.",
            imagePrompt: "현대적인 오피스에서 AI와 협업하는 직장인들",
            backgroundColor: "#FFF8F0",
            textColor: "#2D1810"
        ),
        SummaryResult.CardContent(
            cardNumber: 3,
            title: "AI 시대의 필수 역량",
            content: "AI 시대에는 기술적 이해력, 창의적 사고, 인간적 감성이 더욱 중요해집니다. AI가 할 수 없는 영역인 공감, 상상력, 윤리적 판단 등을 기르는 것이 핵심이에요. 평생 학습하는 자세로 새로운 기술에 적응하는 능력도 필수입니다.",
            imagePrompt: "책과 디지털 기기를 함께 사용하며 학습하는 모습",
            backgroundColor: "#F0FFF8",
            textColor: "#0D2818"
        ),
        SummaryResult.CardContent(
            cardNumber: 4,
            title: "함께 만들어가는 AI의 미래",
            content: "AI의 발전은 기술자들만의 몫이 아닙니다. 모든 사람이 AI의 발전 방향에 대해 생각하고 의견을 나누는 것이 중요해요. 윤리적이고 인간 중심적인 AI 발전을 위해서는 우리 모두의 관심과 참여가 필요합니다. 함께 더 나은 미래를 만들어가요!",
            imagePrompt: "다양한 사람들이 손을 잡고 있는 따뜻한 미래의 모습",
            backgroundColor: "#FFF0F8",
            textColor: "#2D0818"
        )
    ]
    
    // ✅ 수정된 Preview - DocumentInfo 생성자에 맞춤
    let sampleDocumentInfo = DocumentInfo(
        fileName: "AI와 미래사회.pdf",
        fileSize: 2048000,
        fileType: "PDF"
    )
    
    let sampleResult = SummaryResult(
        id: UUID().uuidString,
        config: SummaryConfig(
            cardCount: .four,
            outputStyle: .text,
            language: .korean,
            tone: .friendly
        ),
        originalDocument: sampleDocumentInfo,
        cards: sampleCards,
        createdAt: Date(),
        tokensUsed: 2500
    )
    
    SummaryResultView(summaryResult: sampleResult)
}
