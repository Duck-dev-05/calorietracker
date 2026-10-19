import SwiftUI

/// Shared visual vocabulary with version-aware presentation and an iOS 15 baseline.
enum NourishStyle {
    static let forest = Color(red: 0.08, green: 0.20, blue: 0.23)
    static let lime = Color(red: 0.64, green: 0.94, blue: 0.81)
    static let canvas = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.045, green: 0.065, blue: 0.08, alpha: 1) : UIColor(red: 0.95, green: 0.965, blue: 0.97, alpha: 1) })
    static let surface = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.075, green: 0.105, blue: 0.125, alpha: 1) : .white })
    static let accent = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.57, green: 0.89, blue: 0.78, alpha: 1) : UIColor(red: 0.06, green: 0.36, blue: 0.36, alpha: 1) })
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
            VStack(alignment: .leading, spacing: 24) { content }
                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 40)
                .frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(NourishStyle.canvas.ignoresSafeArea()).modifier(AdaptiveScroll())
    }
}
struct Surface<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(NourishStyle.surface, in: RoundedRectangle(cornerRadius: InterfaceGeneration.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: InterfaceGeneration.cardRadius, style: .continuous).stroke(NourishStyle.accent.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.035), radius: 18, x: 0, y: 6)
    }
}
struct PageIntro: View {
    let eyebrow: String
    let title: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) { Capsule().fill(NourishStyle.accent).frame(width: 20, height: 3); Text(eyebrow.uppercased()).font(.caption2.weight(.bold)).tracking(1.8).foregroundStyle(NourishStyle.accent) }
            Text(title).font(.system(.largeTitle, design: .default).weight(.bold)).tracking(-1).fixedSize(horizontal: false, vertical: true)
            Text(detail).font(.subheadline).foregroundStyle(.secondary).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 8)
    }
}
struct SectionHeading: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(.headline, design: .default).weight(.bold))
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
        }
    }
}
struct IconTile: View {
    let icon: String
    var color: Color = NourishStyle.accent
    var body: some View {
        Image(systemName: icon).font(.system(size: 20, weight: .medium)).foregroundStyle(color)
            .frame(width: 44, height: 44).background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14)).accessibilityHidden(true)
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
            if showsChevron { Image(systemName: "arrow.up.right").font(.caption.weight(.semibold)).foregroundStyle(color).frame(width: 28, height: 28).background(color.opacity(0.07), in: Circle()).accessibilityHidden(true) }
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
            .foregroundStyle(Color.white).background(NourishStyle.forest, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(enabled ? (configuration.isPressed ? 0.82 : 1) : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
    }
}
struct SecondaryAction: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.semibold)).padding(.vertical, 16).frame(maxWidth: .infinity).frame(minHeight: 50)
            .foregroundStyle(NourishStyle.accent).background(NourishStyle.accent.opacity(configuration.isPressed ? 0.16 : 0.08), in: RoundedRectangle(cornerRadius: 16))
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

/// Compact destinations used by the dashboard; labels wrap with Dynamic Type.
struct QuickActionTile: View {
    let title: String
    let subtitle: String
    let icon: String
    var color: Color = NourishStyle.accent
    var body: some View {
        Surface {
            HStack { IconTile(icon: icon, color: color); Spacer(); Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary) }
            Text(title).font(.headline).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
            Text(subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxHeight: .infinity, alignment: .top)
    }
}
