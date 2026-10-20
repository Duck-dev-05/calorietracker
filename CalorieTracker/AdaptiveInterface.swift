import SwiftUI

/// All newer presentation APIs live here so every screen retains its iOS 15 fallback.
struct AdaptiveNavigation<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    @ViewBuilder var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack { content }.modifier(NourishScreenChrome())
        } else {
            NavigationView { content }.navigationViewStyle(.stack).modifier(NourishScreenChrome())
        }
    }
}
struct AdaptiveTabs: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewBuilder func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            // Native system tabs provide Liquid Glass; don't place a second glass layer behind them.
            content.tabBarMinimizeBehavior(.never)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
struct AdaptiveEntrySheet: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // Keep the latest system sheet material and corner treatment.
            content.presentationDetents([.large]).presentationDragIndicator(.visible)
        } else if #available(iOS 16.4, *) {
            content.presentationDetents([.large]).presentationDragIndicator(.visible).presentationCornerRadius(28)
        } else if #available(iOS 16.0, *) {
            content.presentationDetents([.large]).presentationDragIndicator(.visible)
        } else {
            content
        }
    }
}
struct AdaptiveScroll: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.scrollBounceBehavior(.basedOnSize).scrollDismissesKeyboard(.interactively)
        } else if #available(iOS 16.0, *) {
            content.scrollDismissesKeyboard(.interactively)
        } else {
            content
        }
    }
}
enum InterfaceGeneration {
    static var cardRadius: CGFloat {
        if #available(iOS 26.0, *) { return 28 }
        if #available(iOS 16.0, *) { return 24 }
        return 20
    }
    static var name: String {
        if #available(iOS 26.0, *) { return "Liquid Glass" }
        if #available(iOS 16.0, *) { return "Modern" }
        return "Classic"
    }
    static var explanation: String {
        if #available(iOS 26.0, *) { return "Native glass tabs and toolbars, modern navigation, and system sheets." }
        if #available(iOS 16.0, *) { return "Modern navigation and rounded entry sheets, with this iOS version's native controls." }
        return "Classic navigation and sheets, with the same diary and tracking features."
    }
}
extension View {
    func adaptiveEntrySheet() -> some View { modifier(AdaptiveEntrySheet()) }
}

/// Follow the current day only while the user is actually viewing today.
struct FollowCurrentDay: ViewModifier {
    @EnvironmentObject var diary: Diary
    @Binding var selection: Date
    @State private var previousNow = Date()
    func body(content: Content) -> some View {
        content.onAppear {
            if Calendar.current.isDate(selection, inSameDayAs: previousNow) { selection = diary.now }
            previousNow = diary.now
        }.onChange(of: diary.now) { newNow in
            let following = Calendar.current.isDate(selection, inSameDayAs: previousNow)
            previousNow = newNow
            if following { selection = newNow }
        }
    }
}


/// Shared Form/List canvas; newer APIs stay guarded for the iOS 15 build.
struct NourishScreenChrome: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden).background(NourishStyle.canvas.ignoresSafeArea())
        } else {
            content.background(NourishStyle.canvas.ignoresSafeArea())
        }
    }
}
