import Foundation

/// API 키 임시 설정 헬퍼 (개발 중에만 사용)
class APIKeyHelper {
    static func setupDeveloperAPIKey() {
        // 🔑 여기에 임시로 API 키를 설정하세요
        let apiKey = "sk-ant-api03-your-actual-api-key-here"
        
        // UserDefaults에 저장
        UserDefaults.standard.set(apiKey, forKey: "claude_api_key")
        
        print("🔑 [APIKeyHelper] 개발자 API 키 설정 완료")
    }
    
    static func clearAPIKey() {
        UserDefaults.standard.removeObject(forKey: "claude_api_key")
        print("🔑 [APIKeyHelper] API 키 제거 완료")
    }
}