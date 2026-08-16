import SwiftUI

/// Turn cards over two at a time and find the pairs. No sound, no score and
/// no timer — it simply finishes and offers another round.
struct MatchingPairsGame: View {
    let profile: ChildProfile

    private static let symbols = [
        "sun.max", "cloud", "leaf", "star", "moon", "drop"
    ]

    private static let mismatchLinger = Duration.milliseconds(900)

    @State private var board = MatchingPairsBoard(symbols: [])
    @State private var mismatchToken = 0

    private var scale: AgeLayoutScale { profile.layoutScale }

    /// Four pairs for the youngest, six for everyone else, so a board stays
    /// finishable. Layout comfort only — it is not an availability rule.
    private var pairCount: Int { scale.ageYears <= 4 ? 4 : 6 }

    var body: some View {
        VStack(spacing: 24) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 90), spacing: 16)],
                spacing: 16
            ) {
                ForEach(board.cards) { card in
                    Button {
                        reveal(card)
                    } label: {
                        cardFace(card)
                    }
                    .buttonStyle(.calm)
                    .disabled(card.isMatched || board.isResolvingMismatch)
                    .accessibilityLabel(
                        card.isFaceUp
                            ? Text("Card showing \(card.symbolName)", comment: "Face up game card")
                            : Text("Face down card", comment: "Face down game card")
                    )
                }
            }
            .padding(.horizontal, 20)

            if board.isComplete {
                Button {
                    startRound()
                } label: {
                    Text("Play again", comment: "Restart a game")
                        .font(.title3.weight(.semibold))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(.thinMaterial, in: Capsule())
                }
                .buttonStyle(.calm)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(CalmStyle.transition, value: board)
        .onAppear(perform: startRound)
        .task(id: mismatchToken) {
            guard board.isResolvingMismatch else { return }
            try? await Task.sleep(for: Self.mismatchLinger)
            guard !Task.isCancelled else { return }
            board.hideMismatched()
        }
    }

    @ViewBuilder
    private func cardFace(_ card: MatchingPairsBoard.Card) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(card.isFaceUp ? profile.theme.wash : Color(.secondarySystemBackground))

            if card.isFaceUp {
                Image(systemName: card.symbolName)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(profile.theme.tint)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .opacity(card.isMatched ? 0.45 : 1)
    }

    private func startRound() {
        var fresh = MatchingPairsBoard(symbols: Array(Self.symbols.prefix(pairCount)))
        fresh.shuffle()
        board = fresh
    }

    private func reveal(_ card: MatchingPairsBoard.Card) {
        if board.choose(card.id) == .mismatched {
            mismatchToken += 1
        }
    }
}
