import SwiftUI

/// Shared visual constants for the calm, low-stimulation look: soft transitions,
/// generous spacing and no bouncy or flashy animation anywhere.
enum CalmStyle {
    /// The only animation used for state changes in the child interface.
    static let transition: Animation = .easeInOut(duration: 0.28)

    /// Slightly slower, for full screen changes such as entering playback.
    static let screenTransition: Animation = .easeInOut(duration: 0.35)

    static let cardShadowRadius: CGFloat = 6
    static let cardShadowOpacity: Double = 0.08
    static let sectionSpacing: CGFloat = 24

    // MARK: - Tile grid
    //
    // One layout for every child. These were previously derived from a
    // profile's age; the values here are the ones a five-year-old got, which
    // was the default, so no profile set up with the default age changes.

    static let tileMinimumWidth: CGFloat = 210
    static let tileCornerRadius: CGFloat = 28
    static let gridSpacing: CGFloat = 24
    static let gridPadding: CGFloat = 20
    static let tileTitleFont: Font = .title3.weight(.semibold)

    /// Two cards side by side on an iPhone, and as many as fit on anything
    /// wider.
    ///
    /// A compact width asks for two columns outright rather than going through
    /// `.adaptive`: two cards at `tileMinimumWidth` plus the spacing come to
    /// more than any iPhone is wide, so an adaptive grid always resolved to a
    /// single column there. Regular width keeps the adaptive grid, where the
    /// minimum is a real floor rather than a column count in disguise.
    static func gridColumns(forRegularWidth isRegularWidth: Bool) -> [GridItem] {
        guard isRegularWidth else {
            return Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: 2)
        }
        return [GridItem(.adaptive(minimum: tileMinimumWidth * 1.1), spacing: gridSpacing)]
    }
}

extension View {
    /// A soft card treatment used for tiles and profile cards.
    func calmCard(cornerRadius: CGFloat) -> some View {
        clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: .black.opacity(CalmStyle.cardShadowOpacity),
                radius: CalmStyle.cardShadowRadius,
                x: 0,
                y: 3
            )
    }
}

/// A button style with no bounce, no scale-up and no haptic flourish — just a
/// gentle opacity change so a tap still feels acknowledged.
struct CalmButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(CalmStyle.transition, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CalmButtonStyle {
    static var calm: CalmButtonStyle { CalmButtonStyle() }
}
