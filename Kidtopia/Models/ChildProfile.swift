import Foundation
import SwiftData

/// A single child that the parent set up. Every profile has its own theme,
/// avatar, age setting and screen time limit.
///
/// All stored properties carry a default value and no uniqueness constraints are
/// used, because the store is mirrored to CloudKit (see `ModelContainerFactory`).
@Model
final class ChildProfile {
    var id: UUID = UUID()
    var name: String = ""

    /// Identifier from `AvatarCatalog` — a fixed set of kid friendly icons.
    var avatarIconName: String = AvatarCatalog.fallbackIdentifier

    /// Identifier from `ThemePalette` — a fixed, muted colour palette.
    var colorThemeName: String = ThemePalette.fallbackIdentifier

    var sortOrder: Int = 0

    /// Drives tile size, label visibility and playback controls. Range 2...12.
    var ageYears: Int = 5

    /// `nil` means no screen time limit for this profile.
    var dailyScreenTimeLimitMinutes: Int?

    /// Controls Now Playing / remote command centre behaviour for this profile.
    var lockScreenPlaybackEnabled: Bool = true

    /// Tiles owned by *other* profiles that the parent made visible here.
    var visibleSharedTileIDs: [UUID] = []

    /// Bumped on every parent-side edit, used for the manual conflict check.
    var lastModified: Date = Date()

    init(
        id: UUID = UUID(),
        name: String,
        avatarIconName: String = AvatarCatalog.fallbackIdentifier,
        colorThemeName: String = ThemePalette.fallbackIdentifier,
        sortOrder: Int = 0,
        ageYears: Int = 5,
        dailyScreenTimeLimitMinutes: Int? = nil,
        lockScreenPlaybackEnabled: Bool = true,
        visibleSharedTileIDs: [UUID] = [],
        lastModified: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.avatarIconName = avatarIconName
        self.colorThemeName = colorThemeName
        self.sortOrder = sortOrder
        self.ageYears = ageYears
        self.dailyScreenTimeLimitMinutes = dailyScreenTimeLimitMinutes
        self.lockScreenPlaybackEnabled = lockScreenPlaybackEnabled
        self.visibleSharedTileIDs = visibleSharedTileIDs
        self.lastModified = lastModified
    }
}

extension ChildProfile {
    var theme: ThemePalette { ThemePalette.palette(named: colorThemeName) }
    var avatar: AvatarCatalog.Avatar { AvatarCatalog.avatar(named: avatarIconName) }
    var layoutScale: AgeLayoutScale { AgeLayoutScale(ageYears: ageYears) }

    func canSee(tile: Tile) -> Bool {
        guard !tile.isTrashed, !tile.isHidden else { return false }
        return tile.ownerProfileID == id || visibleSharedTileIDs.contains(tile.id)
    }

    func setSharedTile(_ tileID: UUID, visible: Bool) {
        var ids = Set(visibleSharedTileIDs)
        if visible {
            ids.insert(tileID)
        } else {
            ids.remove(tileID)
        }
        visibleSharedTileIDs = Array(ids)
        lastModified = Date()
    }
}
