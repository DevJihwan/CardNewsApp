import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var usageService = UsageTrackingService.shared
    @State private var selectedTier: SubscriptionTier = .basic
    @State private var showingPurchase = false
    @State private var isProcessingPurchase = false
    
    let triggerReason: PaywallTrigger
    
    init(triggerReason: PaywallTrigger = .freeUsageExhausted) {
        self.triggerReason = triggerReason
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // 헤더 섹션
                    headerSection
                    
                    // 혜택 요약
                    benefitsSection
                    
                    // 구독 플랜 선택
                    subscriptionPlansSection
                    
                    // 구독 버튼
                    subscribeButton
                    
                    // 무료 체험 정보 (해당하는 경우)
                    if triggerReason == .freeUsageExhausted {
                        freeTrialInfoSection
                    }
                    
                    // 하단 정보
                    footerSection
                    
                    // 하단 여백
                    Color.clear.frame(height: 50)
                }
                .padding()
            }
            .navigationTitle("프리미엄 업그레이드")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("나중에") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .onAppear {
                print("💰 [PaywallView] 결제 화면 표시, 트리거: \(triggerReason)")
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // 아이콘
            Image(systemName: getHeaderIcon())
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            // 제목 및 설명
            VStack(spacing: 8) {
                Text(getHeaderTitle())
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(getHeaderDescription())
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Benefits Section
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic 플랜의 혜택")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                benefitCard(
                    icon: "rectangle.3.group.fill",
                    title: "월 20개 카드뉴스",
                    description: "텍스트 카드뉴스 제작"
                )
                
                benefitCard(
                    icon: "paintbrush.pointed.fill",
                    title: "모든 스타일",
                    description: "다양한 디자인 템플릿"
                )
                
                benefitCard(
                    icon: "clock.fill",
                    title: "우선 처리",
                    description: "빠른 생성 속도"
                )
                
                benefitCard(
                    icon: "folder.fill",
                    title: "무제한 히스토리",
                    description: "모든 작업 저장"
                )
            }
        }
    }
    
    // MARK: - Subscription Plans Section
    private var subscriptionPlansSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("플랜 선택")
                .font(.headline)
            
            VStack(spacing: 12) {
                // Basic 플랜 (활성화)
                subscriptionPlanCard(tier: .basic, isEnabled: true)
                
                // Pro 플랜 (비활성화)
                subscriptionPlanCard(tier: .pro, isEnabled: false)
                
                // Premium 플랜 (비활성화)
                subscriptionPlanCard(tier: .premium, isEnabled: false)
            }
        }
    }
    
    // MARK: - Subscribe Button
    private var subscribeButton: some View {
        VStack(spacing: 12) {
            Button(action: {
                handleSubscription()
            }) {
                HStack {
                    if isProcessingPurchase {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "crown.fill")
                    }
                    Text(isProcessingPurchase ? "처리 중..." : "\(selectedTier.monthlyPrice)/월로 시작하기")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(radius: 4)
            }
            .disabled(isProcessingPurchase)
            
            Text("언제든지 취소 가능 • 자동 갱신")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Free Trial Info Section
    private var freeTrialInfoSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                Text("무료 체험 완료")
                    .font(.headline)
                    .foregroundColor(.orange)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• 2회 무료 카드뉴스 생성을 모두 사용하셨습니다")
                Text("• 계속 사용하려면 Basic 구독이 필요합니다")
                Text("• 구독 시 바로 월 20개 카드뉴스 이용 가능합니다")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 8) {
            Text("Basic 구독으로 더 많은 기능을 이용하세요")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Link("이용약관", destination: URL(string: "https://cardnews.app/terms")!)
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Link("개인정보처리방침", destination: URL(string: "https://cardnews.app/privacy")!)
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("복원") {
                    // TODO: 구매 복원 기능
                    print("💰 [PaywallView] 구매 복원 요청")
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func benefitCard(icon: String, title: String, description: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func subscriptionPlanCard(tier: SubscriptionTier, isEnabled: Bool) -> some View {
        Button(action: {
            if isEnabled {
                selectedTier = tier
                print("💰 [PaywallView] 플랜 선택: \(tier.displayName)")
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(tier.displayName)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(isEnabled ? .primary : .secondary)
                        
                        if tier == .basic && isEnabled {
                            Text("사용 가능")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(8)
                        } else if !isEnabled {
                            Text("준비 중")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.gray)
                                .cornerRadius(8)
                        }
                        
                        Spacer()
                    }
                    
                    Text(tier.monthlyPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(isEnabled ? .blue : .secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("텍스트: \(tier.textLimit)")
                            .font(.subheadline)
                            .foregroundColor(isEnabled ? .secondary : .secondary.opacity(0.6))
                        Text("이미지: \(tier.imageLimit)")
                            .font(.subheadline)
                            .foregroundColor(isEnabled ? .secondary : .secondary.opacity(0.6))
                    }
                }
                
                Spacer()
                
                Image(systemName: selectedTier == tier && isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(selectedTier == tier && isEnabled ? .blue : .gray)
            }
            .padding()
            .background(
                Group {
                    if selectedTier == tier && isEnabled {
                        Color.blue.opacity(0.1)
                    } else if isEnabled {
                        Color(.systemGray6)
                    } else {
                        Color(.systemGray6).opacity(0.5)
                    }
                }
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedTier == tier && isEnabled ? Color.blue : Color.clear, lineWidth: 2)
            )
            .opacity(isEnabled ? 1.0 : 0.6)
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
    
    private func handleSubscription() {
        print("💰 [PaywallView] 구독 처리 시작: \(selectedTier.displayName)")
        isProcessingPurchase = true
        
        // TODO: StoreKit 2 구독 처리
        // 현재는 시뮬레이션
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isProcessingPurchase = false
            
            // 구독 성공 시뮬레이션
            usageService.updateSubscription(isActive: true, tier: selectedTier)
            
            // 구독 성공 알림
            NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
            
            print("✅ [PaywallView] 구독 완료: \(selectedTier.displayName)")
            dismiss()
        }
    }
}

// MARK: - Supporting Types

enum PaywallTrigger {
    case freeUsageExhausted    // 무료 사용량 소진
    case imageGenerationRequested  // 이미지 생성 요청
    case upgradePrompt         // 업그레이드 프롬프트
}

// MARK: - Preview

#Preview {
    PaywallView(triggerReason: .freeUsageExhausted)
}
