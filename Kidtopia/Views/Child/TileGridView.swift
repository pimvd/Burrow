import SwiftUI

/// The grid of tiles inside one child tab. Tiles are opened by tapping; there is
/// no swipe navigation and no drag-and-drop on the child side.
struct TileGridView: View {
    let tiles: [Tile]
    let profile: ChildProfile
    let onSelect: (Tile) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var scale: AgeLayoutScale { profile.layoutScale }

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [scale.gridItem(forRegularWidth: horizontalSizeClass == .regular)],
                spacing: scale.gridSpacing
            ) {
                ForEach(tiles) { tile in
                    Button {
                        onSelect(tile)
                    } label: {
                        TileCardView(tile: tile, profile: profile)
                    }
                    .buttonStyle(.calm)
                    .accessibilityLabel(Text(tile.title))
                    .accessibilityHint(Text("Opens this playlist", comment: "Tile accessibility hint"))
                }
            }
            .padding(.horizontal, scale.gridPadding)
            .padding(.bottom, scale.gridPadding)
            // Leaves room for the small controls floating at the top.
            .padding(.top, 64)
            .animation(CalmStyle.transition, value: tiles.map(\.id))
        }
        .scrollBounceBehavior(.basedOnSize)
        // An empty profile simply shows a calm, empty screen for the child. The
        // "add your first tile" prompt lives in the parent area only.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
