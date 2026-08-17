import SwiftUI

/// Four in a row. A whole column is one big button, so a child does not have
/// to aim at a single circle to drop a disc.
struct ConnectFourGame: View {
    let profile: ChildProfile

    private static let thinkingPause = Duration.milliseconds(700)
    private static let boardWidth: CGFloat = 420
    private static let slotSpacing: CGFloat = 6
    private static let boardCornerRadius: CGFloat = 24

    @State private var board = ConnectFourBoard()
    @State private var isThinking = false
    @State private var thinkingToken = 0

    var body: some View {
        VStack(spacing: 20) {
            GameStatusLine(text: statusText)

            HStack(spacing: Self.slotSpacing) {
                ForEach(0 ..< ConnectFourBoard.columns, id: \.self) { column in
                    Button {
                        play(in: column)
                    } label: {
                        VStack(spacing: Self.slotSpacing) {
                            ForEach(0 ..< ConnectFourBoard.rows, id: \.self) { row in
                                slot(row: row, column: column)
                            }
                        }
                    }
                    .buttonStyle(.calm)
                    .disabled(board.landingRow(in: column) == nil || board.isFinished || isThinking)
                    .accessibilityLabel(
                        Text("Column \(column + 1)", comment: "A column of the Four in a Row board")
                    )
                    .accessibilityHint(Text("Drops a disc", comment: "Four in a Row hint"))
                }
            }
            .padding(Self.slotSpacing * 2)
            .background(
                profile.theme.wash,
                in: RoundedRectangle(cornerRadius: Self.boardCornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Self.boardCornerRadius, style: .continuous)
                    .strokeBorder(profile.theme.tint.opacity(0.3), lineWidth: 2)
            }
            .frame(maxWidth: Self.boardWidth)
            .padding(.horizontal, 16)

            if board.isFinished {
                PlayAgainButton(action: startRound)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(CalmStyle.transition, value: board)
        .task(id: thinkingToken) {
            guard isThinking else { return }
            try? await Task.sleep(for: Self.thinkingPause)
            guard !Task.isCancelled else { return }

            var generator = SystemRandomNumberGenerator()
            board.playComputerMove(using: &generator)
            isThinking = false
        }
    }

    @ViewBuilder
    private func slot(row: Int, column: Int) -> some View {
        let index = ConnectFourBoard.index(row: row, column: column)
        let isWinning = board.winningSlots.contains(index)

        Circle()
            .fill(colour(for: board.disc(row: row, column: column)))
            .overlay {
                Circle().strokeBorder(
                    profile.theme.tint.opacity(isWinning ? 0.7 : 0),
                    lineWidth: 3
                )
            }
            .aspectRatio(1, contentMode: .fit)
    }

    private func colour(for disc: ConnectFourBoard.Disc?) -> Color {
        switch disc {
        case .child: return profile.theme.tint
        case .computer: return Color(.systemGray3)
        case nil: return Color(.systemBackground)
        }
    }

    private var statusText: Text {
        switch board.result {
        case .childWon:
            return Text("You won!", comment: "The child won a game")
        case .computerWon:
            return Text("I won this one.", comment: "The computer won a game")
        case .draw:
            return Text("The board is full. Try again?", comment: "Four in a Row ended full")
        case nil:
            return isThinking
                ? Text("My turn…", comment: "The computer is about to play")
                : Text("Your turn", comment: "The child is about to play")
        }
    }

    private func startRound() {
        board = ConnectFourBoard()
        isThinking = false
    }

    private func play(in column: Int) {
        guard board.drop(.child, in: column), !board.isFinished else { return }
        isThinking = true
        thinkingToken += 1
    }
}
