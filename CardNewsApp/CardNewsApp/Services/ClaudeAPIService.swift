    init() {
        // 🗑️ 임시: 잘못된 UserDefaults API 키 제거
        UserDefaults.standard.removeObject(forKey: "claude_api_key")
        print("🗑️ [DEBUG] UserDefaults API 키 제거됨")
        
        setupJSONCoders()
        loadDeveloperAPIKey()
    }