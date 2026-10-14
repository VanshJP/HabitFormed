import SwiftUI

// MARK: - Header Chrome

extension View {
    /// A one-icon header control: exactly `AppLayout.minHitTarget` square on
    /// the header glass, so the glass is the hit target.
    func headerIconChrome() -> some View {
        self
            .font(.body.weight(.semibold))
            .frame(width: AppLayout.minHitTarget, height: AppLayout.minHitTarget)
            .headerGlass()
    }

    /// The glass every page-header control wears: Today's streak-and-actions
    /// capsule and every `headerIconChrome()` button. Follows Settings → App
    /// look → Glass.
    func headerGlass() -> some View {
        modifier(HeaderGlassChrome())
    }

    /// Brings the navigation bar back on a page pushed from a bar-less root.
    func restoresNavigationBar() -> some View {
        toolbar(.visible, for: .navigationBar)
    }
}

/// Interactive capsule glass tinted by the App look glass setting, with the
/// header's shadow. A capsule 44pt tall and 44pt wide is a circle, so a
/// one-icon control and a multi-door capsule share it.
private struct HeaderGlassChrome: ViewModifier {
    @Environment(\.glassAppearance) private var glassAppearance

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular.tint(glassAppearance.glassTint).interactive(), in: .capsule)
            .contentShape(.capsule)
            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }
}

// MARK: - Page Title

/// The name a root tab opens on: a title2 name, an optional kicker above it
/// (data only, such as today's date), an optional line under it, and one
/// accessory at the trailing edge wearing `headerGlass()`.
struct PageTitle<Detail: View, Accessory: View>: View {
    var kicker: String?
    let title: String
    @ViewBuilder var detail: Detail
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                if let kicker {
                    Text(kicker)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(0.8)
                }

                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)

                detail
            }

            Spacer(minLength: 8)

            accessory
        }
        .frame(minHeight: AppLayout.minHitTarget)
        .padding(.top, 4)
    }
}

extension PageTitle where Detail == EmptyView {
    init(kicker: String? = nil, title: String, @ViewBuilder accessory: () -> Accessory) {
        self.init(kicker: kicker, title: title, detail: { EmptyView() }, accessory: accessory)
    }
}

extension PageTitle where Detail == EmptyView, Accessory == EmptyView {
    init(kicker: String? = nil, title: String) {
        self.init(kicker: kicker, title: title, detail: { EmptyView() }, accessory: { EmptyView() })
    }
}
