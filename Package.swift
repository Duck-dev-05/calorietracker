// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "NourishCore",
    platforms: [.macOS(.v12)],
    products: [.library(name: "DiaryCore", targets: ["DiaryCore"])],
    targets: [
        .target(name: "DiaryCore", path: "CalorieTracker", exclude: ["AdaptiveInterface.swift", "BackupViews.swift", "CalorieTrackerApp.swift", "ContentView.swift", "DesignSystem.swift", "HealthService.swift", "MealAndProgressViews.swift", "NumberDraftField.swift", "ProfileViews.swift", "PersonalizationViews.swift", "CalorieTracker.entitlements"], sources: ["Models.swift", "Diary.swift"]),
        .testTarget(name: "DiaryCoreTests", dependencies: ["DiaryCore"], path: "Tests/DiaryCoreTests")
    ]
)
