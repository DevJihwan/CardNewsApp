import SwiftUI

struct TextInputView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var inputText = """
    오픈뱅킹 공동업무 API 명세서
    
    1. 개요
    본 문서는 오픈뱅킹 시스템의 API 사용을 위한 기술 명세서입니다.
    
    2. 인증 방식
    OAuth 2.0 방식을 사용하여 인증을 처리합니다.
    
    3. 주요 API
    - 계좌 조회 API
    - 잔액 조회 API  
    - 거래 내역 조회 API
    - 송금 API
    
    4. 보안 요구사항
    모든 API 호출은 HTTPS를 통해 이루어져야 하며, 적절한 인증 토큰이 필요합니다.
    
    5. 오류 처리
    API 호출 실패 시 표준 HTTP 상태 코드와 함께 오류 메시지가 반환됩니다.
    """
    
    let onTextSubmitted: (String) -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Header Section
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppGradients.primary)
                        .frame(width: 60, height: 60)
                        .shadow(color: AppColors.primaryStart.opacity(0.3), radius: 12, x: 0, y: 6)
                    
                    Image(systemName: "text.cursor")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                Text("텍스트 직접 입력")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("테스트용으로 텍스트를 직접 입력해서 카드뉴스를 생성해보세요.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.top)
            
            // Text Editor Section
            VStack(alignment: .leading, spacing: 12) {
                Text("내용 입력")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ? AppColors.glassBackgroundDark : AppColors.glassBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    colorScheme == .dark ? AppColors.glassBorderDark : AppColors.glassBorder,
                                    lineWidth: 1
                                )
                        )
                        .frame(minHeight: 240)
                    
                    TextEditor(text: $inputText)
                        .font(.body)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(16)
                        .background(Color.clear)
                        .scrollContentBackground(.hidden)
                }
                .shadow(color: AppColors.primaryStart.opacity(0.1), radius: 8, x: 0, y: 4)
            }
            
            // Action Button
            Button(action: {
                onTextSubmitted(inputText)
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("카드뉴스 생성하기")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppGradients.buttonSuccess)
                        .shadow(color: AppColors.success.opacity(0.4), radius: 12, x: 0, y: 6)
                )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
            
            Spacer()
        }
        .padding(20)
    }
}

#Preview {
    TextInputView { text in
        print("Text submitted: \(text)")
    }
}
