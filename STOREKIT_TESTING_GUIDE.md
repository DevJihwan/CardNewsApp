# StoreKit 인앱 구매 테스트 가이드

## 문제 상황
Xcode 시뮬레이터에서 무료 체험 완료 후 구독 시도 시 다음 오류 발생:
```
💎 [UsageTrackingService] 구독 상태 업데이트: 비활성, 티어: none
💰 [PaywallView] 구독 처리 시작: Basic
💰 [SubscriptionService] 구매 시작: cardnews_basic_monthly
❌ [SubscriptionService] 제품을 찾을 수 없음: cardnews_basic_monthly
```

## 해결 방법

### 1. Xcode Scheme 설정 확인

#### 1.1 Scheme 편집
1. Xcode에서 **Product** > **Edit Scheme** 선택
2. **Run** 섹션 선택
3. **Options** 탭 클릭

#### 1.2 StoreKit Configuration 설정
1. **StoreKit Configuration** 드롭다운에서 `Configuration.storekit` 선택
2. **Use StoreKit Configuration File** 체크박스 활성화
3. **Close** 클릭

### 2. 프로젝트 설정 확인

#### 2.1 Configuration.storekit 파일 확인
- 파일 위치: `CardNewsApp/Configuration.storekit`
- 제품 ID 확인:
  - `cardnews_basic_monthly` ($4.99)
  - `cardnews_pro_monthly` ($9.99)
  - `cardnews_premium_monthly` ($19.99)

#### 2.2 Target Membership 확인
1. `Configuration.storekit` 파일 선택
2. **File Inspector**에서 **Target Membership** 확인
3. `CardNewsApp` 타겟이 체크되어 있는지 확인

### 3. 시뮬레이터 재설정

#### 3.1 앱 완전 삭제 및 재설치
```bash
# 시뮬레이터에서 앱 삭제
# Xcode에서 Clean Build Folder
⇧⌘K (Shift + Cmd + K)

# 앱 재설치
⌘R (Cmd + R)
```

#### 3.2 시뮬레이터 재시작
1. **Device** > **Restart** 선택
2. 또는 시뮬레이터 완전 종료 후 재시작

### 4. 디버깅 단계

#### 4.1 제품 로드 확인
앱 실행 후 다음 로그 확인:
```
💰 [SubscriptionService] 제품 정보 로드 시작
💰 [SubscriptionService] 제품 로드 시도 1/3
✅ [SubscriptionService] 3개 제품 로드 완료
   📦 ID: cardnews_basic_monthly, 이름: Basic Monthly, 가격: $4.99
   📦 ID: cardnews_pro_monthly, 이름: Pro Monthly, 가격: $9.99
   📦 ID: cardnews_premium_monthly, 이름: Premium Monthly, 가격: $19.99
```

#### 4.2 로드 실패 시
로그에서 다음과 같은 메시지가 나타나면:
```
⚠️ [SubscriptionService] 로드된 제품이 없음. StoreKit Configuration 확인 필요
```

**해결책:**
1. Scheme 설정 재확인
2. `Configuration.storekit` 파일 재설정
3. 프로젝트 클린 빌드

### 5. Debug 기능 활용

#### 5.1 Debug 메뉴 사용
PaywallView의 우측 상단 햄머 아이콘(🔨) 클릭:
- **무료 사용량 리셋**: 무료 체험 횟수 초기화
- **구독 해제**: 구독 상태 초기화  
- **제품 다시 로드**: StoreKit 제품 정보 재로드

#### 5.2 로그 모니터링
Xcode Console에서 다음 키워드로 필터링:
- `[SubscriptionService]`
- `[PaywallView]`
- `[UsageTrackingService]`

### 6. 실제 기기 테스트

시뮬레이터에서 계속 문제가 발생하는 경우:

#### 6.1 TestFlight 내부 테스팅
1. App Store Connect에서 인앱 구매 제품 설정
2. TestFlight으로 내부 테스터에게 배포
3. Sandbox 환경에서 실제 테스트

#### 6.2 Sandbox 계정 설정
1. **Settings** > **App Store** > **Sandbox Account**
2. 테스트용 Apple ID로 로그인
3. 실제 기기에서 테스트

### 7. 일반적인 문제 및 해결책

#### 7.1 "제품을 찾을 수 없음" 오류
**원인:**
- StoreKit Configuration이 Scheme에 설정되지 않음
- 제품 ID 불일치
- 시뮬레이터 캐시 문제

**해결책:**
1. Scheme 설정 재확인
2. 제품 ID 정확성 확인
3. 시뮬레이터 재시작

#### 7.2 구매 프로세스 중단
**원인:**
- 네트워크 연결 문제
- StoreKit 프레임워크 로딩 실패

**해결책:**
1. 네트워크 연결 확인
2. 앱 재시작
3. Xcode 재시작

#### 7.3 구독 상태 동기화 문제
**원인:**
- Transaction listener 미동작
- UserDefaults 데이터 손상

**해결책:**
1. 앱 완전 재시작
2. Debug 메뉴로 상태 초기화
3. 구매 복원 기능 사용

### 8. 최종 체크리스트

구독 테스트 전 다음 사항들을 확인하세요:

- [ ] Xcode Scheme에 `Configuration.storekit` 설정됨
- [ ] `Configuration.storekit` 파일이 타겟에 포함됨
- [ ] 제품 ID가 코드와 일치함
- [ ] 시뮬레이터가 최신 상태임
- [ ] 앱이 완전히 재설치됨
- [ ] Console 로그에서 제품 로드 성공 확인됨

### 9. 추가 리소스

- [Apple StoreKit Testing Documentation](https://developer.apple.com/documentation/storekit/in-app_purchase/testing_in-app_purchases_with_storekit_testing)
- [StoreKit Configuration File Reference](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode)

---

**최종 업데이트:** 2025년 7월 7일  
**문서 버전:** 1.0
