import SwiftUI

/// One large tappable card in the child grid.
struct TileCardView: View {
    let tile: Tile
    let profile: ChildProfile

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

            Text(tile.title)
                .font(CalmStyle.tileTitleFont)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemBackground))
        .calmCard(cornerRadius: CalmStyle.tileCornerRadius)
        .contentShape(RoundedRectangle(cornerRadius: CalmStyle.tileCornerRadius, style: .continuous))
    }
}
