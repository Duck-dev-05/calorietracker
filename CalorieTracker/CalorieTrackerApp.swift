import SwiftUI

@main struct CalorieTrackerApp: App {
    @StateObject private var diary = Diary()
    @StateObject private var health = HealthService()
    var body: some Scene {
        WindowGroup { ContentView().environmentObject(diary).environmentObject(health) }
    }
}
