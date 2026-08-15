import SwiftUI

/// One large tappable card in the child grid.
struct TileCardView: View {
    let tile: Tile
    let profile: ChildProfile

    private var scale: AgeLayoutScale { profile.layoutScale }

    var body: some View {
        VStack(spacing: 0) {
            TileImageView(
                tileID: tile.id,
                imageData: tile.imageData,
                category: tile.category,
                tint: profile.theme.tint
            )
            .aspectRatio(1, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipped()

            if scale.showsTileLabels {
                Text(tile.title)
                    .font(scale.tileTitleFont)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 12)
            }
        }
        .background(Color(.secondarySystemBackground))
        .calmCard(cornerRadius: scale.tileCornerRadius)
        .contentShape(RoundedRectangle(cornerRadius: scale.tileCornerRadius, style: .continuous))
    }
}
