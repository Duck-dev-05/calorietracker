import SwiftUI

/// Shared visual vocabulary with version-aware presentation and an iOS 15 baseline.
enum NourishStyle {
    static let forest = Color(red: 0.10, green: 0.24, blue: 0.19)
    static let lime = Color(red: 0.81, green: 0.91, blue: 0.63)
    static let canvas = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.055, green: 0.075, blue: 0.065, alpha: 1) : UIColor(red: 0.97, green: 0.965, blue: 0.94, alpha: 1) })
    static let surface = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.095, green: 0.12, blue: 0.105, alpha: 1) : .white })
    static let accent = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.72, green: 0.88, blue: 0.64, alpha: 1) : UIColor(red: 0.14, green: 0.34, blue: 0.25, alpha: 1) })
    static let peach = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.96, green: 0.70, blue: 0.48, alpha: 1) : UIColor(red: 0.65, green: 0.32, blue: 0.13, alpha: 1) })
    static let blue = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.55, green: 0.77, blue: 0.91, alpha: 1) : UIColor(red: 0.18, green: 0.42, blue: 0.57, alpha: 1) })
}
struct BrandMark: View {
    var size: CGFloat = 44
    var body: some View {
        Image("NourishMark").resizable().scaledToFit().frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)).accessibilityHidden(true)
    }
}
struct BrandLockup: View {
    var body: some View {
        HStack(spacing: 10) {
            BrandMark(size: 34)
            Text("nourish").font(.system(.title3, design: .rounded).weight(.bold)).tracking(-0.5)
        }.accessibilityElement(children: .ignore).accessibilityLabel("Nourish")
    }
}
struct PageCanvas<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) { content }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 32)
                .frame(maxWidth: 680).frame(maxWidth: .infinity)
        }.background(NourishStyle.canvas.ignoresSafeArea()).modifier(AdaptiveScroll())
    }
}
struct Surface<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) { content }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(NourishStyle.surface, in: RoundedRectangle(cornerRadius: InterfaceGeneration.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: InterfaceGeneration.cardRadius, style: .continuous).stroke(NourishStyle.accent.opacity(0.08), lineWidth: 1))
            .shadow(color: .black.opacity(0.025), radius: 14, x: 0, y: 5)
    }
}
struct PageIntro: View {
    let eyebrow: String
    let title: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(eyebrow.uppercased()).font(.caption.weight(.semibold)).tracking(1.6).foregroundStyle(NourishStyle.accent)
            Text(title).font(.system(.largeTitle, design: .rounded).weight(.bold)).tracking(-0.8).fixedSize(horizontal: false, vertical: true)
            Text(detail).font(.subheadline).foregroundStyle(.secondary).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 8)
    }
}
struct SectionHeading: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(.title3, design: .rounded).weight(.bold))
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
        }
    }
}
struct IconTile: View {
    let icon: String
    var color: Color = NourishStyle.accent
    var body: some View {
        Image(systemName: icon).font(.system(size: 20, weight: .medium)).foregroundStyle(color)
            .frame(width: 46, height: 46).background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 15)).accessibilityHidden(true)
    }
}
struct RouteRow: View {
    let title: String
    let subtitle: String
    let icon: String
    var color: Color = NourishStyle.accent
    var showsChevron = true
    var body: some View {
        HStack(spacing: 14) {
            IconTile(icon: icon, color: color)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            if showsChevron { Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true) }
        }.frame(minHeight: 58).contentShape(Rectangle())
    }
}
struct Pill: View {
    let text: String
    var color: Color = NourishStyle.accent
    var body: some View { Text(text).font(.caption.weight(.medium)).foregroundStyle(color).padding(.horizontal, 11).padding(.vertical, 7).background(color.opacity(0.10), in: Capsule()) }
}
struct PrimaryAction: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).padding(.vertical, 17).frame(maxWidth: .infinity).frame(minHeight: 52)
            .foregroundStyle(Color.white).background(NourishStyle.forest, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(enabled ? (configuration.isPressed ? 0.82 : 1) : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
    }
}
struct SecondaryAction: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.semibold)).padding(.vertical, 16).frame(maxWidth: .infinity).frame(minHeight: 50)
            .foregroundStyle(NourishStyle.accent).background(NourishStyle.accent.opacity(configuration.isPressed ? 0.16 : 0.08), in: RoundedRectangle(cornerRadius: 18))
    }
}
struct CalorieRing: View {
    let eaten: Int
    let target: Double?
    private var progress: Double { target.map { min(max(Double(eaten) / max($0, 1), 0), 1) } ?? 0 }
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.14), lineWidth: 13)
            Circle().trim(from: 0, to: progress).stroke(NourishStyle.lime, style: StrokeStyle(lineWidth: 13, lineCap: .round)).rotationEffect(.degrees(-90))
            VStack(spacing: 6) {
                Image(systemName: "leaf.fill").font(.title3).foregroundStyle(NourishStyle.lime)
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
