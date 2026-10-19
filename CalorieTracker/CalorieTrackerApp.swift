import SwiftUI

@main struct CalorieTrackerApp: App {
    @StateObject private var diary: Diary
    @StateObject private var health: HealthService
    @StateObject private var account: AccountStore
    init() {
        if #unavailable(iOS 16.0) { UITableView.appearance().backgroundColor = UIColor(NourishStyle.canvas) }
        let account = AccountStore(provider: UnconfiguredAccountProvider())
        _account = StateObject(wrappedValue: account)
        let diary = Diary(account: account)
        _diary = StateObject(wrappedValue: diary)
        _health = StateObject(wrappedValue: HealthService(authorized: { diary.can(.readHealth) }))
    }
    var body: some Scene {
        WindowGroup { ContentView().environmentObject(diary).environmentObject(health).environmentObject(account) }
    }
}
