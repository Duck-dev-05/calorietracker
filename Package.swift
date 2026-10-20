// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "NourishCore",
    platforms: [.macOS(.v12)],
    products: [.library(name: "DiaryCore", targets: ["DiaryCore"])],
    targets: [
        .target(name: "DiaryCore", path: "CalorieTracker", exclude: ["DeviceAccountProvider.swift","KeychainAccessProbe.swift","GoogleAccountProvider.swift", "GoogleSignInView.swift","Assets.xcassets","AccessViews.swift","NutritionViews.swift","AdaptiveInterface.swift", "BackupViews.swift", "CalorieTrackerApp.swift", "ContentView.swift", "DesignSystem.swift", "HealthService.swift", "MealAndProgressViews.swift", "NumberDraftField.swift", "ProfileViews.swift", "PersonalizationViews.swift", "CriticalViews.swift", "AccountViews.swift", "CalorieTracker.entitlements"], sources: ["NutritionEditing.swift","GoogleConfiguration.swift","Nutrition.swift", "Models.swift", "Diary.swift", "HealthState.swift", "AccountState.swift"]),
        .testTarget(name: "DiaryCoreTests", dependencies: ["DiaryCore"], path: "Tests/DiaryCoreTests")
    ]
)
