import SwiftUI

/// Translates a profile's age (2...12) into concrete layout decisions for the
/// child interface: how big tiles are, whether captions are shown and whether
/// explicit next/previous buttons appear during playback.
struct AgeLayoutScale: Equatable, Sendable {
    static let minimumAge = 2
    static let maximumAge = 12

    let ageYears: Int

    init(ageYears: Int) {
        self.ageYears = min(max(ageYears, Self.minimumAge), Self.maximumAge)
    }

    /// Youngest children get very large tiles; older children get a denser grid.
    var minimumTileWidth: CGFloat {
        switch ageYears {
        case 2...3: return 260
        case 4...5: return 210
        case 6...8: return 175
        default: return 145
        }
    }

    var tileCornerRadius: CGFloat {
        switch ageYears {
        case 2...3: return 32
        case 4...5: return 28
        case 6...8: return 24
        default: return 20
        }
    }

    var gridSpacing: CGFloat {
        switch ageYears {
        case 2...3: return 28
        case 4...5: return 24
        default: return 18
        }
    }

    /// Text labels under tiles are hidden for pre-readers.
    var showsTileLabels: Bool { ageYears >= 4 }

    /// Younger children get large, always visible next/previous buttons; older
    /// children navigate the playlist by swiping in the now playing view.
    var showsTransportButtons: Bool { ageYears <= 7 }

    var tileTitleFont: Font {
        switch ageYears {
        case 2...5: return .title3.weight(.semibold)
        case 6...8: return .headline
        default: return .subheadline.weight(.semibold)
        }
    }

    /// Extra padding around the grid for the youngest children, so a mis-tap is
    /// less likely to land on a neighbouring tile.
    var gridPadding: CGFloat {
        ageYears <= 3 ? 28 : 20
    }

    /// Tiles are laid out with an adaptive grid, so a wider window (iPad, or an
    /// iPhone in landscape) simply fits more columns of the same size.
    func gridItem(forRegularWidth isRegularWidth: Bool) -> GridItem {
        let minimum = isRegularWidth ? minimumTileWidth * 1.1 : minimumTileWidth
        return GridItem(.adaptive(minimum: minimum), spacing: gridSpacing)
    }
}
