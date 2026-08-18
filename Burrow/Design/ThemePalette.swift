import SwiftUI

/// A fixed set of muted, low-stimulation colour themes. Parents pick one per
/// child profile; there is no free colour picker, which keeps the whole app
/// visually calm.
struct ThemePalette: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String

    /// Base tint used for accents, selection and the profile avatar ring.
    let tint: Color

    /// Very soft background wash used behind tile grids for this profile.
    let wash: Color

    static let fallbackIdentifier = "sage"

    static let all: [ThemePalette] = [
        ThemePalette(
            id: "sage",
            displayName: String(localized: "Sage", comment: "Colour theme name"),
            tint: Color(red: 0.404, green: 0.529, blue: 0.639),
            wash: Color(red: 0.404, green: 0.529, blue: 0.639).opacity(0.10)
        ),
        ThemePalette(
            id: "clay",
            displayName: String(localized: "Clay", comment: "Colour theme name"),
            tint: Color(red: 0.741, green: 0.529, blue: 0.451),
            wash: Color(red: 0.741, green: 0.529, blue: 0.451).opacity(0.10)
        ),
        ThemePalette(
            id: "moss",
            displayName: String(localized: "Moss", comment: "Colour theme name"),
            tint: Color(red: 0.482, green: 0.588, blue: 0.475),
            wash: Color(red: 0.482, green: 0.588, blue: 0.475).opacity(0.10)
        ),
        ThemePalette(
            id: "lavender",
            displayName: String(localized: "Lavender", comment: "Colour theme name"),
            tint: Color(red: 0.596, green: 0.549, blue: 0.686),
            wash: Color(red: 0.596, green: 0.549, blue: 0.686).opacity(0.10)
        ),
        ThemePalette(
            id: "sand",
            displayName: String(localized: "Sand", comment: "Colour theme name"),
            tint: Color(red: 0.749, green: 0.686, blue: 0.529),
            wash: Color(red: 0.749, green: 0.686, blue: 0.529).opacity(0.10)
        ),
        ThemePalette(
            id: "slate",
            displayName: String(localized: "Slate", comment: "Colour theme name"),
            tint: Color(red: 0.471, green: 0.510, blue: 0.557),
            wash: Color(red: 0.471, green: 0.510, blue: 0.557).opacity(0.10)
        )
    ]

    static func palette(named identifier: String) -> ThemePalette {
        all.first { $0.id == identifier }
            ?? all.first { $0.id == fallbackIdentifier }
            ?? ThemePalette(
                id: fallbackIdentifier,
                displayName: "Sage",
                tint: .accentColor,
                wash: Color.accentColor.opacity(0.10)
            )
    }
}
