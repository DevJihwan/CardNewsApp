import SwiftUI

@main
struct CardNewsApp: App {
    //let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            MainView()  // ContentView → MainView로 변경
                //.environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
