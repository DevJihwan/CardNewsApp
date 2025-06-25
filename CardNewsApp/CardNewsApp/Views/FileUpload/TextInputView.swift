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
        VStack(spacing: 20) {
            Text("텍스트 직접 입력 (테스트용)")
                .font(.headline)
            
            Text("파일 업로드 문제를 우회하기 위해 텍스트를 직접 입력해서 테스트할 수 있습니다.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            TextEditor(text: $inputText)
                .border(Color.gray, width: 1)
                .frame(minHeight: 200)
            
            Button("이 텍스트로 테스트") {
                onTextSubmitted(inputText)
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .cornerRadius(12)
        }
        .padding()
    }
}
