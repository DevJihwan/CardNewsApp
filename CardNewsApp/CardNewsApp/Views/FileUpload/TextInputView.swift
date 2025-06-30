import SwiftUI

struct TextInputView: View {
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
        VStack(spacing: 32) {
            // Header Section - Clear & Professional
            VStack(spacing: 20) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .shadow(color: .blue.opacity(0.2), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "text.cursor")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                // Title & Description
                VStack(spacing: 12) {
                    Text("텍스트 직접 입력")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("테스트용으로 텍스트를 직접 입력해서\n카드뉴스를 생성해보세요")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
            }
            
            // Text Input Section - Large & Clear
            VStack(alignment: .leading, spacing: 16) {
                Text("내용 입력")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                // Large Text Editor with clear boundaries
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 2)
                        )
                        .frame(minHeight: 280)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    
                    TextEditor(text: $inputText)
                        .font(.system(size: 16)) // Large, readable font
                        .foregroundColor(.primary)
                        .padding(20) // Generous padding
                        .background(Color.clear)
                        .scrollContentBackground(.hidden)
                }
                
                // Character count helper
                HStack {
                    Spacer()
                    Text("\(inputText.count)자")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            // Action Button - Large touch target
            Button(action: {
                onTextSubmitted(inputText)
            }) {
                HStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                    
                    Text("카드뉴스 생성하기")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18) // Large touch target
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
            
            // Helper Text
            VStack(spacing: 8) {
                Text("💡 더 정확한 결과를 위한 팁")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.blue)
                        Text("명확한 제목과 단락으로 구성해주세요")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.blue)
                        Text("최소 500자 이상 입력하시면 더 좋은 결과를 얻을 수 있습니다")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.05))
            )
            
            Spacer()
        }
        .padding(.horizontal, 24) // Generous margins
        .padding(.vertical, 20)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    TextInputView { text in
        print("Text submitted: \(text)")
    }
}
