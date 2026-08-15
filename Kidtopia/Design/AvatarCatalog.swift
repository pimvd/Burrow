import Foundation

/// The fixed set of kid friendly avatars. Custom photo avatars are deliberately
/// not supported: nothing personal about the child ever enters the app.
enum AvatarCatalog {
    struct Avatar: Identifiable, Hashable, Sendable {
        /// Stored on `ChildProfile.avatarIconName`; also the SF Symbol name.
        let id: String
        let displayName: String

        var symbolName: String { id }
    }

    static let fallbackIdentifier = "hare.fill"

    static let all: [Avatar] = [
        Avatar(id: "hare.fill", displayName: String(localized: "Hare", comment: "Avatar name")),
        Avatar(id: "tortoise.fill", displayName: String(localized: "Tortoise", comment: "Avatar name")),
        Avatar(id: "bird.fill", displayName: String(localized: "Bird", comment: "Avatar name")),
        Avatar(id: "fish.fill", displayName: String(localized: "Fish", comment: "Avatar name")),
        Avatar(id: "ladybug.fill", displayName: String(localized: "Ladybug", comment: "Avatar name")),
        Avatar(id: "ant.fill", displayName: String(localized: "Ant", comment: "Avatar name")),
        Avatar(id: "pawprint.fill", displayName: String(localized: "Paw print", comment: "Avatar name")),
        Avatar(id: "teddybear.fill", displayName: String(localized: "Teddy bear", comment: "Avatar name")),
        Avatar(id: "leaf.fill", displayName: String(localized: "Leaf", comment: "Avatar name")),
        Avatar(id: "star.fill", displayName: String(localized: "Star", comment: "Avatar name")),
        Avatar(id: "moon.stars.fill", displayName: String(localized: "Moon", comment: "Avatar name")),
        Avatar(id: "sun.max.fill", displayName: String(localized: "Sun", comment: "Avatar name")),
        Avatar(id: "cloud.fill", displayName: String(localized: "Cloud", comment: "Avatar name")),
        Avatar(id: "balloon.fill", displayName: String(localized: "Balloon", comment: "Avatar name")),
        Avatar(id: "heart.fill", displayName: String(localized: "Heart", comment: "Avatar name")),
        Avatar(id: "crown.fill", displayName: String(localized: "Crown", comment: "Avatar name"))
    ]

    static func avatar(named identifier: String) -> Avatar {
        all.first { $0.id == identifier }
            ?? all.first { $0.id == fallbackIdentifier }
            ?? Avatar(id: fallbackIdentifier, displayName: "Hare")
    }
}
