import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var usageService = UsageTrackingService.shared
    @StateObject private var subscriptionService = SubscriptionService(usageService: UsageTrackingService.shared)
    @State private var selectedTier: SubscriptionTier = .basic
    @State private var showingPurchase = false
    @State private var isProcessingPurchase = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var productsLoadAttempts = 0
    @State private var maxLoadAttempts = 3
    
    let triggerReason: PaywallTrigger
    
    init(triggerReason: PaywallTrigger = .freeUsageExhausted) {
        self.triggerReason = triggerReason
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 40) {
                    // Header Section - Clear Value Proposition
                    headerSection
                    
                    // Benefits Summary - Time-saving Focus
                    benefitsSection
                    
                    // Subscription Plans - Simple & Clear
                    subscriptionPlansSection
                    
                    // Subscribe Button - Large & Prominent
                    subscribeButton
                    
                    // Free Trial Info (if applicable)
                    if triggerReason == .freeUsageExhausted {
                        freeTrialInfoSection
                    }
                    
                    // Footer Information
                    footerSection
                    
                    // Bottom spacing
                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("프리미엄 구독")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("나중에") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                }
                
                // 🧪 테스트용: 무료 사용량 리셋 버튼
                #if DEBUG
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("무료 사용량 리셋") {
                            usageService.resetFreeUsage()
                            print("🧪 [PaywallView] 무료 사용량 리셋 완료")
                        }
                        
                        Button("구독 해제") {
                            usageService.updateSubscription(isActive: false, tier: .none)
                            print("🧪 [PaywallView] 구독 해제 완료")
                        }
                        
                        Button("제품 다시 로드") {
                            Task {
                                await subscriptionService.loadProducts()
                                print("🧪 [PaywallView] 제품 재로드 완료")
                            }
                        }
                    } label: {
                        Image(systemName: "hammer.circle")
                            .foregroundColor(.orange)
                    }
                }
                #endif
            }
            .alert("구독 오류", isPresented: $showingError) {
                Button("확인") { }
                
                // StoreKit 설정 관련 오류인 경우 추가 옵션 제공
                if errorMessage?.contains("StoreKit Configuration") == true || 
                   errorMessage?.contains("제품 정보가 로드되지") == true {
                    Button("다시 시도") {
                        Task {
                            await subscriptionService.loadProducts()
                        }
                    }
                }
            } message: {
                Text(errorMessage ?? "알 수 없는 오류가 발생했습니다.")
            }
            .onAppear {
                print("💰 [PaywallView] 결제 화면 표시, 트리거: \(triggerReason)")
                loadProductsWithRetry()
            }
            .refreshable {
                await subscriptionService.loadProducts()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 24) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [getHeaderColor(), getHeaderColor().opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: getHeaderColor().opacity(0.3), radius: 12, x: 0, y: 6)
                
                Image(systemName: getHeaderIcon())
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Title & Description
            VStack(spacing: 16) {
                Text(getHeaderTitle())
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(getHeaderDescription())
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
    }
    
    // MARK: - Benefits Section
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("QuickCard 플랜의 혜택")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20)
            ], spacing: 20) {
                benefitCard(
                    icon: "rectangle.3.group.fill",
                    title: "다양한 카드뉴스",
                    description: "텍스트, 웹툰, 이미지\n다양한 형식 지원",
                    color: .blue
                )
                
                benefitCard(
                    icon: "paintbrush.pointed.fill",
                    title: "전용 디자인 스타일",
                    description: "각 플랜별 최적화된\n고급 템플릿 제공",
                    color: .purple
                )
                
                benefitCard(
                    icon: "clock.fill",
                    title: "우선 처리",
                    description: "빠른 생성 속도로\n시간 절약",
                    color: .green
                )
                
                benefitCard(
                    icon: "folder.fill",
                    title: "무제한 히스토리",
                    description: "모든 작업 내역\n영구 저장",
                    color: .orange
                )
            }
        }
    }
    
    // MARK: - Subscription Plans Section
    private var subscriptionPlansSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("구독 플랜")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                // Basic Plan
                subscriptionPlanCard(tier: .basic, isEnabled: true)
                
                // Webtoon Plan (Coming Soon)
                subscriptionPlanCard(tier: .webtoon, isEnabled: false)
                
                // Pro Plan (Coming Soon)
                subscriptionPlanCard(tier: .pro, isEnabled: false)
                
                // Premium Plan (Coming Soon)
                subscriptionPlanCard(tier: .premium, isEnabled: false)
            }
        }
    }
    
    // MARK: - Subscribe Button
    private var subscribeButton: some View {
        VStack(spacing: 16) {
            Button(action: {
                Task {
                    await handleSubscription()
                }
            }) {
                HStack(spacing: 16) {
                    if isProcessingPurchase {
                        ProgressView()
                            .scaleEffect(1.0)
                            .foregroundColor(.white)
                    } else if subscriptionService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                        Text("제품 정보 로딩 중...")
                            .font(.system(size: 16, weight: .medium))
                    } else if !subscriptionService.areProductsLoaded() {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 20, weight: .bold))
                        Text("제품 정보 로드 실패")
                            .font(.system(size: 16, weight: .medium))
                    } else {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 20, weight: .bold))
                        Text("\(selectedTier.monthlyPrice)/월로 시작하기")
                            .font(.system(size: 18, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18) // Large touch target
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: buttonColors(),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: buttonShadowColor(), radius: 12, x: 0, y: 6)
                )
            }
            .disabled(isProcessingPurchase || subscriptionService.isLoading || !subscriptionService.areProductsLoaded())
            .scaleEffect(isProcessingPurchase ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isProcessingPurchase)
            
            // Status message
            if subscriptionService.isLoading {
                Text("제품 정보를 불러오고 있습니다...")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            } else if !subscriptionService.areProductsLoaded() {
                VStack(spacing: 8) {
                    Text("제품 정보를 불러올 수 없습니다")
                        .font(.system(size: 15))
                        .foregroundColor(.red)
                    
                    Button("다시 시도") {
                        loadProductsWithRetry()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                }
            } else {
                Text("언제든지 취소 가능 • 자동 갱신")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Free Trial Info Section
    private var freeTrialInfoSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 20, weight: .semibold))
                
                Text("무료 체험 완료")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.orange)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("• 2회 무료 카드뉴스 생성을 모두 사용하셨습니다")
                Text("• 계속 사용하려면 구독이 필요합니다")
                Text("• 용도에 맞는 플랜을 선택해주세요")
            }
            .font(.system(size: 16))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 16) {
            Text("QuickCard로 더 많은 기능을 이용하세요")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 20) {
                Link("이용약관", destination: URL(string: "https://cardnews.app/terms")!)
                    .font(.system(size: 15))
                    .foregroundColor(.blue)
                
                Text("•")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                
                Link("개인정보처리방침", destination: URL(string: "https://cardnews.app/privacy")!)
                    .font(.system(size: 15))
                    .foregroundColor(.blue)
                
                Text("•")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                
                Button("복원") {
                    Task {
                        await subscriptionService.restorePurchases()
                    }
                }
                .font(.system(size: 15))
                .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func benefitCard(icon: String, title: String, description: String, color: Color) -> some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(color)
            }
            
            // Text
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .lineLimit(3)
            }
            .frame(minHeight: 60)
        }
        .padding(20)
        .frame(minHeight: 140, maxHeight: 140)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    private func subscriptionPlanCard(tier: SubscriptionTier, isEnabled: Bool) -> some View {
        Button(action: {
            if isEnabled {
                selectedTier = tier
                print("💰 [PaywallView] 플랜 선택: \(tier.displayName)")
            }
        }) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Text(tier.displayName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(isEnabled ? .primary : .secondary)
                        
                        if isEnabled {
                            Text("이용 가능")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.green)
                                )
                        } else {
                            Text("준비 중")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.gray)
                                )
                        }
                        
                        Spacer()
                    }
                    
                    Text(tier.monthlyPrice)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(isEnabled ? .blue : .secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("텍스트 카드뉴스: \(tier.textLimit)")
                            .font(.system(size: 16))
                            .foregroundColor(isEnabled ? .secondary : .secondary.opacity(0.6))
                        
                        Text("웹툰 카드뉴스: \(tier.webtoonLimit)")
                            .font(.system(size: 16))
                            .foregroundColor(isEnabled ? .secondary : .secondary.opacity(0.6))
                        
                        if tier == .premium {
                            Text("이미지 카드뉴스: \(tier.imageLimit)")
                                .font(.system(size: 16))
                                .foregroundColor(isEnabled ? .secondary : .secondary.opacity(0.6))
                        }
                    }
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    
                    if selectedTier == tier && isEnabled {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(24)
            .frame(minHeight: 80)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                selectedTier == tier && isEnabled ?
                                Color.blue : Color.clear,
                                lineWidth: 3
                            )
                    )
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
            .opacity(isEnabled ? 1.0 : 0.6)
            .scaleEffect(selectedTier == tier && isEnabled ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: selectedTier)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
    }
    
    // MARK: - Helper Methods
    
    private func buttonColors() -> [Color] {
        if !subscriptionService.areProductsLoaded() {
            return [Color.gray, Color.gray.opacity(0.8)]
        } else if subscriptionService.isLoading {
            return [Color.orange, Color.orange.opacity(0.8)]
        } else {
            return [Color.blue, Color.blue.opacity(0.8)]
        }
    }
    
    private func buttonShadowColor() -> Color {
        if !subscriptionService.areProductsLoaded() {
            return .gray.opacity(0.3)
        } else if subscriptionService.isLoading {
            return .orange.opacity(0.4)
        } else {
            return .blue.opacity(0.4)
        }
    }
    
    private func getHeaderIcon() -> String {
        switch triggerReason {
        case .freeUsageExhausted:
            return "exclamationmark.triangle.fill"
        case .imageGenerationRequested:
            return "photo.artframe"
        case .upgradePrompt:
            return "crown.fill"
        }
    }
    
    private func getHeaderColor() -> Color {
        switch triggerReason {
        case .freeUsageExhausted:
            return .orange
        case .imageGenerationRequested:
            return .purple
        case .upgradePrompt:
            return .blue
        }
    }
    
    private func getHeaderTitle() -> String {
        switch triggerReason {
        case .freeUsageExhausted:
            return "무료 체험 완료"
        case .imageGenerationRequested:
            return "더 많은 기능이\n곧 출시됩니다"
        case .upgradePrompt:
            return "QuickCard 구독으로\n시작해보세요"
        }
    }
    
    private func getHeaderDescription() -> String {
        switch triggerReason {
        case .freeUsageExhausted:
            return "2회 무료 생성을 모두 사용하셨습니다.\n용도에 맞는 플랜을 선택해보세요."
        case .imageGenerationRequested:
            return "이미지 생성 기능은 곧 Premium 플랜과 함께 출시됩니다.\n지금은 다른 플랜으로 카드뉴스를 이용해보세요."
        case .upgradePrompt:
            return "텍스트, 웹툰, 이미지 카드뉴스로\n더욱 풍성한 콘텐츠를 만들어보세요."
        }
    }
    
    private func loadProductsWithRetry() {
        Task {
            await subscriptionService.loadProducts()
            
            // 제품 로드에 실패하고 최대 시도 횟수에 도달하지 않은 경우 재시도
            if !subscriptionService.areProductsLoaded() && productsLoadAttempts < maxLoadAttempts {
                productsLoadAttempts += 1
                print("💰 [PaywallView] 제품 로드 재시도 \(productsLoadAttempts)/\(maxLoadAttempts)")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    loadProductsWithRetry()
                }
            }
        }
    }
    
    @MainActor
    private func handleSubscription() async {
        print("💰 [PaywallView] 구독 처리 시작: \(selectedTier.displayName)")
        
        // 제품이 로드되지 않은 경우 처리
        if !subscriptionService.areProductsLoaded() {
            print("⚠️ [PaywallView] 제품이 로드되지 않음. 재로드 시도...")
            await subscriptionService.loadProducts()
            
            if !subscriptionService.areProductsLoaded() {
                errorMessage = """
                제품 정보를 불러올 수 없습니다.
                
                시뮬레이터에서 테스트하는 경우:
                1. Xcode > Edit Scheme > Run > Options
                2. StoreKit Configuration에서 'Configuration.storekit' 선택
                3. 앱을 완전히 종료 후 재실행
                
                문제가 계속되면 실제 기기에서 테스트해주세요.
                """
                showingError = true
                return
            }
        }
        
        isProcessingPurchase = true
        
        let productID = getProductID(for: selectedTier)
        
        await subscriptionService.purchase(productID: productID)
        
        // 구독 상태 확인
        if subscriptionService.purchaseState == .purchased {
            print("✅ [PaywallView] 구독 완료: \(selectedTier.displayName)")
            dismiss()
        } else if subscriptionService.purchaseState == .failed {
            errorMessage = subscriptionService.errorMessage
            showingError = true
        }
        
        isProcessingPurchase = false
    }
    
    private func getProductID(for tier: SubscriptionTier) -> String {
        switch tier {
        case .basic:
            return "cardnews_basic_monthly"
        case .webtoon:
            return "cardnews_webtoon_monthly"
        case .pro:
            return "cardnews_pro_monthly"
        case .premium:
            return "cardnews_premium_monthly"
        case .none:
            return ""
        }
    }
}

// MARK: - Supporting Types

enum PaywallTrigger {
    case freeUsageExhausted    // 무료 사용량 소진
    case imageGenerationRequested  // 이미지 생성 요청
    case upgradePrompt         // 업그레이드 프롬프트
}

#Preview {
    PaywallView(triggerReason: .freeUsageExhausted)
}
