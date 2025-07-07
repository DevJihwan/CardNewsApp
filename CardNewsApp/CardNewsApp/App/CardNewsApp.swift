import SwiftUI

@main
struct CardNewsApp: App {
    //let persistenceController = PersistenceController.shared

    var body: some Scene {\n        WindowGroup {\n            MainView()  // ContentView → MainView로 변경\n                //.environment(\\.managedObjectContext, persistenceController.container.viewContext)\n                .onAppear {\n                    // 🔑 개발 중에만 사용: API 키 자동 설정\n                    APIKeyHelper.setupDeveloperAPIKey()\n                }\n        }\n    }\n}