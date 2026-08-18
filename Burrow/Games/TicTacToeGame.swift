import SwiftUI

/// Three in a row against a computer that plays badly on purpose. The child
/// always starts, and always plays the circle.
struct TicTacToeGame: View {
    let profile: ChildProfile

    /// Long enough that the computer's move reads as a reply rather than an
    /// echo of the child's own tap.
    private static let thinkingPause = Duration.milliseconds(700)

    private static let boardWidth: CGFloat = 330
    private static let cellSpacing: CGFloat = 12
    private static let cellCornerRadius: CGFloat = 20
    private static let cellBorderWidth: CGFloat = 2

    @State private var board = TicTacToeBoard()
    @State private var isThinking = false
    @State private var thinkingToken = 0

    var body: some View {
        VStack(spacing: 24) {
            GameStatusLine(text: statusText)

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: Self.cellSpacing),
                    count: TicTacToeBoard.side
                ),
                spacing: Self.cellSpacing
            ) {
                ForEach(0 ..< TicTacToeBoard.cellCount, id: \.self) { index in
                    Button {
                        play(at: index)
                    } label: {
                        cell(index)
                    }
                    .buttonStyle(.calm)
                    .disabled(board.cells[index] != nil || board.isFinished || isThinking)
                    .accessibilityLabel(label(for: index))
                }
            }
            .frame(maxWidth: Self.boardWidth)
            .padding(.horizontal, 20)

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
    private func cell(_ index: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: Self.cellCornerRadius, style: .continuous)
        let isWinning = board.winningLine?.contains(index) ?? false

        ZStack {
            shape.fill(isWinning ? profile.theme.wash : Color(.secondarySystemBackground))

            switch board.cells[index] {
            case .child:
                Image(systemName: "circle")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(profile.theme.tint)
            case .computer:
                Image(systemName: "xmark")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.secondary)
            case nil:
                EmptyView()
            }
        }
        .overlay {
            shape.strokeBorder(
                profile.theme.tint.opacity(isWinning ? 0.55 : 0.3),
                lineWidth: Self.cellBorderWidth
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var statusText: Text {
        switch board.result {
        case .childWon:
            return Text("You won!", comment: "The child won a game")
        case .computerWon:
            return Text("I won this one.", comment: "The computer won a game")
        case .draw:
            return Text("Nobody won. Try again?", comment: "A game ended in a draw")
        case nil:
            return isThinking
                ? Text("My turn…", comment: "The computer is about to play")
                : Text("Your turn", comment: "The child is about to play")
        }
    }

    private func label(for index: Int) -> Text {
        switch board.cells[index] {
        case .child:
            return Text("Your circle", comment: "Occupied Tic Tac Toe square")
        case .computer:
            return Text("My cross", comment: "Occupied Tic Tac Toe square")
        case nil:
            return Text("Empty square", comment: "Free Tic Tac Toe square")
        }
    }

    private func startRound() {
        board = TicTacToeBoard()
        isThinking = false
    }

    private func play(at index: Int) {
        guard board.place(.child, at: index), !board.isFinished else { return }
        isThinking = true
        thinkingToken += 1
    }
}
