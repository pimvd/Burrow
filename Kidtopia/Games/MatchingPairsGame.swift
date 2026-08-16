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

    private static let pairCount = 6

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

    private static let cardCornerRadius: CGFloat = 20
    private static let cardBorderWidth: CGFloat = 2

    @ViewBuilder
    private func cardFace(_ card: MatchingPairsBoard.Card) -> some View {
        let shape = RoundedRectangle(cornerRadius: Self.cardCornerRadius, style: .continuous)

        ZStack {
            shape.fill(card.isFaceUp ? profile.theme.wash : Color(.secondarySystemBackground))

            if card.isFaceUp {
                Image(systemName: card.symbolName)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(profile.theme.tint)
            }
        }
        // Every card needs an edge of its own. A face-up card is filled with
        // the profile's wash, which is exactly the colour behind the board, so
        // without this it has no visible outline at all.
        .overlay {
            shape.strokeBorder(
                profile.theme.tint.opacity(card.isFaceUp ? 0.55 : 0.3),
                lineWidth: Self.cardBorderWidth
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .opacity(card.isMatched ? 0.45 : 1)
    }

    private func startRound() {
        var fresh = MatchingPairsBoard(symbols: Array(Self.symbols.prefix(Self.pairCount)))
        fresh.shuffle()
        board = fresh
    }

    private func reveal(_ card: MatchingPairsBoard.Card) {
        if board.choose(card.id) == .mismatched {
            mismatchToken += 1
        }
    }
}
