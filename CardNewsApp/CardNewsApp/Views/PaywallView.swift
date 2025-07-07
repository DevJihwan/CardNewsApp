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
                    } label: {
                        Image(systemName: "hammer.circle")
                            .foregroundColor(.orange)
                    }
                }
                #endif
            }
            .alert("구독 오류", isPresented: $showingError) {
                Button("확인") { }
            } message: {
                Text(errorMessage ?? "알 수 없는 오류가 발생했습니다.")
            }
            .onAppear {
                print("💰 [PaywallView] 결제 화면 표시, 트리거: \(triggerReason)")
                Task {
                    await subscriptionService.loadProducts()
                }
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
            Text("Basic 플랜의 혜택")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20)
            ], spacing: 20) {
                benefitCard(
                    icon: "rectangle.3.group.fill",
                    title: "월 20개 카드뉴스",
                    description: "텍스트 카드뉴스\n무제한 생성",
                    color: .blue
                )
                
                benefitCard(
                    icon: "paintbrush.pointed.fill",
                    title: "모든 디자인 스타일",
                    description: "웹툰, 텍스트, 이미지\n다양한 템플릿",
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
                // Basic Plan (Available)
                subscriptionPlanCard(tier: .basic, isEnabled: true)
                
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
                    } else {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 20, weight: .bold))
                    }
                    
                    Text(isProcessingPurchase ? "처리 중..." : "\(selectedTier.monthlyPrice)/월로 시작하기")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18) // Large touch target
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .blue.opacity(0.4), radius: 12, x: 0, y: 6)
                )
            }
            .disabled(isProcessingPurchase)
            .scaleEffect(isProcessingPurchase ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isProcessingPurchase)
            
            Text("언제든지 취소 가능 • 자동 갱신")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
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
                Text("• 계속 사용하려면 Basic 구독이 필요합니다")
                Text("• 구독 시 바로 월 20개 카드뉴스 이용 가능합니다")
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
            Text("Basic 구독으로 더 많은 기능을 이용하세요")
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
                        
                        if tier == .basic && isEnabled {
                            Text("이용 가능")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.green)
                                )
                        } else if !isEnabled {
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
                        
                        Text("이미지 카드뉴스: \(tier.imageLimit)")
                            .font(.system(size: 16))
                            .foregroundColor(isEnabled ? .secondary : .secondary.opacity(0.6))
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
            return "Basic 플랜으로\n시작해보세요"
        }
    }
    
    private func getHeaderDescription() -> String {
        switch triggerReason {
        case .freeUsageExhausted:
            return "2회 무료 생성을 모두 사용하셨습니다.\nBasic 플랜으로 월 20개 카드뉴스를 만들어보세요."
        case .imageGenerationRequested:
            return "이미지 생성 기능은 곧 Pro 플랜과 함께 출시됩니다.\n지금은 Basic 플랜으로 텍스트 카드뉴스를 이용해보세요."
        case .upgradePrompt:
            return "월 20개 텍스트 카드뉴스와 다양한 스타일로\n더욱 풍성한 콘텐츠를 만들어보세요."
        }
    }
    
    @MainActor
    private func handleSubscription() async {
        print("💰 [PaywallView] 구독 처리 시작: \(selectedTier.displayName)")
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
