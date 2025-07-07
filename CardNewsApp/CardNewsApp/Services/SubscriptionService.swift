import Foundation
import StoreKit

/// StoreKit 2 기반 구독 관리 서비스
@available(iOS 15.0, *)
class SubscriptionService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var purchaseState: PurchaseState = .idle
    @Published var errorMessage: String?
    
    // MARK: - Constants
    private let productIDs: [String] = [
        "cardnews_basic_monthly",
        "cardnews_pro_monthly", 
        "cardnews_premium_monthly"
    ]
    
    // MARK: - Private Properties
    private var products: [Product] = []
    private var usageService: UsageTrackingService
    private var updateListenerTask: Task<Void, Error>?
    private var maxRetryCount = 3
    
    // MARK: - Initialization
    init(usageService: UsageTrackingService) {
        self.usageService = usageService
        print("💰 [SubscriptionService] 초기화 완료")
        
        // 트랜잭션 업데이트 리스너 시작
        updateListenerTask = listenForTransactions()
        
        // 앱 시작 시 제품 로드
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// App Store 제품 정보 로드
    @MainActor
    func loadProducts() async {
        print("💰 [SubscriptionService] 제품 정보 로드 시작")
        isLoading = true
        
        for attempt in 1...maxRetryCount {
            do {
                print("💰 [SubscriptionService] 제품 로드 시도 \(attempt)/\(maxRetryCount)")
                let storeProducts = try await Product.products(for: productIDs)
                
                if storeProducts.isEmpty {
                    print("⚠️ [SubscriptionService] 로드된 제품이 없음. StoreKit Configuration 확인 필요")
                    if attempt < maxRetryCount {
                        print("💰 [SubscriptionService] 1초 후 재시도...")
                        try await Task.sleep(nanoseconds: 1_000_000_000) // 1초 대기
                        continue
                    } else {
                        throw SubscriptionError.productNotFound
                    }
                }
                
                self.products = storeProducts.sorted { $0.price < $1.price }
                
                print("✅ [SubscriptionService] \(products.count)개 제품 로드 완료")
                for product in products {
                    print("   📦 ID: \(product.id), 이름: \(product.displayName), 가격: \(product.displayPrice)")
                }
                
                // 성공 시 반복문 종료
                break
                
            } catch {
                print("❌ [SubscriptionService] 제품 로드 실패 (시도 \(attempt)): \(error)")
                
                if attempt == maxRetryCount {
                    // 최종 실패 시 더 자세한 에러 정보 제공
                    let detailError = """
                    제품 정보를 불러올 수 없습니다.
                    
                    가능한 원인:
                    1. StoreKit Configuration 파일이 Scheme에 설정되지 않음
                    2. 시뮬레이터에서 StoreKit 테스팅이 비활성화됨
                    3. 네트워크 연결 문제
                    
                    해결 방법:
                    1. Xcode > Edit Scheme > Run > Options > StoreKit Configuration 확인
                    2. 시뮬레이터 재시작
                    3. 실제 기기에서 테스트
                    
                    에러: \(error.localizedDescription)
                    """
                    errorMessage = detailError
                } else {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1초 대기 후 재시도
                }
            }
        }
        
        isLoading = false
    }
    
    /// 구독 상품 구매
    @MainActor
    func purchase(productID: String) async {
        print("💰 [SubscriptionService] 구매 시작: \(productID)")
        
        // 제품이 로드되지 않은 경우 먼저 로드 시도
        if products.isEmpty {
            print("💰 [SubscriptionService] 제품이 로드되지 않음. 제품 로드 시도...")
            await loadProducts()
        }
        
        guard let product = products.first(where: { $0.id == productID }) else {
            print("❌ [SubscriptionService] 제품을 찾을 수 없음: \(productID)")
            print("💰 [SubscriptionService] 현재 로드된 제품들:")
            for p in products {
                print("   📦 \(p.id)")
            }
            
            if products.isEmpty {
                errorMessage = """
                제품 정보가 로드되지 않았습니다.
                
                시뮬레이터에서 테스트하는 경우:
                1. Xcode > Edit Scheme > Run > Options
                2. StoreKit Configuration에서 'Configuration.storekit' 선택
                3. 앱 재실행
                
                계속 문제가 발생하면 실제 기기에서 테스트해주세요.
                """
            } else {
                errorMessage = "해당 제품(\(productID))을 찾을 수 없습니다"
            }
            return
        }
        
        purchaseState = .purchasing
        
        do {
            print("💰 [SubscriptionService] 제품 구매 요청: \(product.displayName) (\(product.displayPrice))")
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                await handleSuccessfulPurchase(verification: verification, product: product)
                
            case .userCancelled:
                print("🔄 [SubscriptionService] 사용자가 구매 취소")
                purchaseState = .cancelled
                
            case .pending:
                print("⏳ [SubscriptionService] 구매 대기 중")
                purchaseState = .pending
                
            @unknown default:
                print("❓ [SubscriptionService] 알 수 없는 구매 결과")
                purchaseState = .failed
            }
            
        } catch {
            print("❌ [SubscriptionService] 구매 실패: \(error)")
            errorMessage = "구매에 실패했습니다: \(error.localizedDescription)"
            purchaseState = .failed
        }
    }
    
    /// 구매 복원
    @MainActor
    func restorePurchases() async {
        print("💰 [SubscriptionService] 구매 복원 시작")
        isLoading = true
        
        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
            print("✅ [SubscriptionService] 구매 복원 완료")
        } catch {
            print("❌ [SubscriptionService] 구매 복원 실패: \(error)")
            errorMessage = "구매 복원에 실패했습니다: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// 현재 구독 상태 확인
    func checkSubscriptionStatus() async {
        print("💰 [SubscriptionService] 구독 상태 확인 시작")
        
        var activeSubscription: SubscriptionTier = .none
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if let tier = getSubscriptionTier(from: transaction.productID) {
                    activeSubscription = tier
                    print("✅ [SubscriptionService] 활성 구독 발견: \(tier.displayName)")
                }
                
            } catch {
                print("❌ [SubscriptionService] 트랜잭션 검증 실패: \(error)")
            }
        }
        
        await MainActor.run {
            let isActive = activeSubscription != .none
            usageService.updateSubscription(isActive: isActive, tier: activeSubscription)
            
            if isActive {
                purchaseState = .purchased
            }
        }
    }
    
    /// 사용 가능한 제품 목록 반환
    func getAvailableProducts() -> [Product] {
        return products
    }
    
    /// 제품 ID로 제품 정보 조회
    func getProduct(by id: String) -> Product? {
        return products.first { $0.id == id }
    }
    
    /// 제품 로드 상태 확인
    func areProductsLoaded() -> Bool {
        return !products.isEmpty
    }
    
    // MARK: - Private Methods
    
    private func handleSuccessfulPurchase(verification: VerificationResult<Transaction>, product: Product) async {
        do {
            let transaction = try checkVerified(verification)
            
            // 구독 상태 업데이트
            if let tier = getSubscriptionTier(from: product.id) {
                await MainActor.run {
                    usageService.updateSubscription(isActive: true, tier: tier)
                    purchaseState = .purchased
                    
                    // 구독 성공 알림
                    NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
                }
                
                print("🎉 [SubscriptionService] 구매 성공: \(tier.displayName)")
            }
            
            // 트랜잭션 완료 처리
            await transaction.finish()
            
        } catch {
            print("❌ [SubscriptionService] 구매 검증 실패: \(error)")
            await MainActor.run {
                errorMessage = "구매 검증에 실패했습니다"
                purchaseState = .failed
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    private func getSubscriptionTier(from productID: String) -> SubscriptionTier? {
        switch productID {
        case "cardnews_basic_monthly":
            return .basic
        case "cardnews_pro_monthly":
            return .pro
        case "cardnews_premium_monthly":
            return .premium
        default:
            return nil
        }
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updateSubscriptionStatus(for: transaction)
                    await transaction.finish()
                } catch {
                    print("❌ [SubscriptionService] 트랜잭션 업데이트 처리 실패: \(error)")
                }
            }
        }
    }
    
    private func updateSubscriptionStatus(for transaction: Transaction) async {
        if let tier = getSubscriptionTier(from: transaction.productID) {
            await MainActor.run {
                usageService.updateSubscription(isActive: true, tier: tier)
                NotificationCenter.default.post(name: .subscriptionStatusChanged, object: nil)
            }
        }
    }
}

// MARK: - Supporting Types

enum PurchaseState {
    case idle
    case purchasing
    case purchased
    case failed
    case cancelled
    case pending
    
    var displayMessage: String {
        switch self {
        case .idle:
            return ""
        case .purchasing:
            return "구매 중..."
        case .purchased:
            return "구매 완료!"
        case .failed:
            return "구매 실패"
        case .cancelled:
            return "구매 취소됨"
        case .pending:
            return "승인 대기 중"
        }
    }
}

enum SubscriptionError: Error, LocalizedError {
    case failedVerification
    case productNotFound
    case purchaseFailed
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "구매 검증에 실패했습니다"
        case .productNotFound:
            return "제품을 찾을 수 없습니다"
        case .purchaseFailed:
            return "구매에 실패했습니다"
        }
    }
}

// MARK: - Product Extensions

extension Product {
    var subscriptionTier: SubscriptionTier? {
        switch self.id {
        case "cardnews_basic_monthly":
            return .basic
        case "cardnews_pro_monthly":
            return .pro
        case "cardnews_premium_monthly":
            return .premium
        default:
            return nil
        }
    }
}
