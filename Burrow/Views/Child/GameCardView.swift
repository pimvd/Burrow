import SwiftUI

/// One game card in the child grid. Games have no artwork to store, so the
/// card shows its symbol on the profile's theme colour instead.
struct GameCardView: View {
    let game: GameCatalog.Game
    let profile: ChildProfile

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                profile.theme.wash
                Image(systemName: game.symbolName)
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(profile.theme.tint)
            }
            .aspectRatio(1, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipped()

            Text(game.localizedTitle)
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
