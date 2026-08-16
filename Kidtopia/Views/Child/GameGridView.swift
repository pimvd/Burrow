import SwiftUI

/// The grid of games inside the child's Games tab. Mirrors `TileGridView` so
/// games sit beside music and video without looking bolted on.
struct GameGridView: View {
    let games: [GameCatalog.Game]
    let profile: ChildProfile
    let onSelect: (GameCatalog.Game) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [CalmStyle.gridItem(forRegularWidth: horizontalSizeClass == .regular)],
                spacing: CalmStyle.gridSpacing
            ) {
                ForEach(games) { game in
                    Button {
                        onSelect(game)
                    } label: {
                        GameCardView(game: game, profile: profile)
                    }
                    .buttonStyle(.calm)
                    .accessibilityLabel(Text(game.localizedTitle))
                    .accessibilityHint(Text("Opens this game", comment: "Game accessibility hint"))
                }
            }
            .padding(.horizontal, CalmStyle.gridPadding)
            .padding(.bottom, CalmStyle.gridPadding)
            // Leaves room for the small controls floating at the top.
            .padding(.top, 64)
            .animation(CalmStyle.transition, value: games.map(\.id))
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
