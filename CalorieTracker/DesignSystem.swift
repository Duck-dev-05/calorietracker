import SwiftUI

/// Shared visual vocabulary with version-aware presentation and an iOS 15 baseline.
enum NourishStyle {
    static let canvas = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.065, green: 0.085, blue: 0.075, alpha: 1) : UIColor(red: 0.96, green: 0.965, blue: 0.94, alpha: 1) })
    static let surface = Color(UIColor.secondarySystemGroupedBackground)
    static let accent = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.61, green: 0.83, blue: 0.62, alpha: 1) : UIColor(red: 0.16, green: 0.37, blue: 0.25, alpha: 1) })
    static let peach = Color(red: 0.93, green: 0.65, blue: 0.43)
    static let blue = Color(red: 0.35, green: 0.63, blue: 0.78)
}
struct PageCanvas<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 24) { content }.padding(20).frame(maxWidth: 680).frame(maxWidth: .infinity) }
            .background(NourishStyle.canvas.ignoresSafeArea()).modifier(AdaptiveScroll())
    }
}
struct Surface<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(NourishStyle.surface, in: RoundedRectangle(cornerRadius: InterfaceGeneration.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: InterfaceGeneration.cardRadius, style: .continuous).stroke(Color.primary.opacity(0.045), lineWidth: 1))
    }
}
struct PageIntro: View {
    let eyebrow: String
    let title: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased()).font(.caption.weight(.bold)).tracking(2).foregroundStyle(NourishStyle.accent)
            Text(title).font(.system(.largeTitle, design: .rounded).weight(.bold)).fixedSize(horizontal: false, vertical: true)
            Text(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
struct SectionHeading: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(.title3, design: .rounded).weight(.bold))
            if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
        }
    }
}
struct IconTile: View {
    let icon: String
    var color: Color = NourishStyle.accent
    var body: some View {
        Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(color)
            .frame(width: 48, height: 48).background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16)).accessibilityHidden(true)
    }
}
struct RouteRow: View {
    let title: String
    let subtitle: String
    let icon: String
    var color: Color = NourishStyle.accent
    var body: some View {
        HStack(spacing: 14) {
            IconTile(icon: icon, color: color)
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline).foregroundStyle(.primary); Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary).accessibilityHidden(true)
        }.frame(minHeight: 52).contentShape(Rectangle())
    }
}
struct Pill: View {
    let text: String
    var color: Color = NourishStyle.accent
    var body: some View { Text(text).font(.caption.weight(.semibold)).foregroundStyle(color).padding(.horizontal, 12).padding(.vertical, 7).background(color.opacity(0.12), in: Capsule()) }
}
struct PrimaryAction: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).padding(.vertical, 17).frame(maxWidth: .infinity)
            .foregroundStyle(.white).background(Color(red: 0.16, green: 0.37, blue: 0.25), in: RoundedRectangle(cornerRadius: 18))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
struct CalorieRing: View {
    let eaten: Int
    let target: Double?
    private var progress: Double { target.map { min(max(Double(eaten) / max($0, 1), 0), 1) } ?? 0 }
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.14), lineWidth: 13)
            Circle().trim(from: 0, to: progress).stroke(Color(red: 0.78, green: 0.9, blue: 0.57), style: StrokeStyle(lineWidth: 13, lineCap: .round)).rotationEffect(.degrees(-90))
            VStack(spacing: 6) {
                Image(systemName: "leaf.fill").font(.title3).foregroundStyle(Color(red: 0.78, green: 0.9, blue: 0.57))
                Text(target.map { "\(max(0, Int($0) - eaten))" } ?? "—").font(.system(size: 46, weight: .semibold, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
                Text(target == nil ? "Set a daily target" : "kcal remaining").font(.caption).foregroundStyle(.white.opacity(0.8))
            }.padding(20)
        }.frame(width: 200, height: 200).padding(8)
        .accessibilityElement(children: .ignore).accessibilityLabel(target.map { "\(max(0, Int($0) - eaten)) kilocalories remaining. \(eaten) eaten. Target \(Int($0))." } ?? "Daily target not set. \(eaten) kilocalories logged.")
    }
}
struct MealArtwork: View {
    let meal: Meal
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20).fill((meal.vegetarian ? NourishStyle.accent : NourishStyle.peach).opacity(0.13))
            Circle().fill(NourishStyle.surface).frame(width: 78, height: 78)
            Image(systemName: meal.vegetarian ? "leaf.fill" : "fork.knife").font(.system(size: 32, weight: .light)).foregroundStyle(meal.vegetarian ? NourishStyle.accent : NourishStyle.peach)
        }.frame(height: 124).accessibilityHidden(true)
    }
}
