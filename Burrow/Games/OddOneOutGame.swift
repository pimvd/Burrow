import SwiftUI

/// Odd One Out: a handful of pictures, one of which does not belong. Tapping
/// a wrong picture costs nothing — it dims and the child keeps looking.
struct OddOneOutGame: View {
    let profile: ChildProfile

    private static let solvedPause = Duration.milliseconds(1_100)
    private static let tileMinimumWidth: CGFloat = 96
    private static let tileSpacing: CGFloat = 16
    private static let tileCornerRadius: CGFloat = 24
    private static let boardWidth: CGFloat = 420

    @State private var level = 1
    @State private var round: OddOneOutRound?
    @State private var hasFinishedEveryLevel = false
    @State private var advanceToken = 0

    var body: some View {
        VStack(spacing: 20) {
            GameStatusLine(text: statusText)

            if hasFinishedEveryLevel {
                Text(verbatim: "🎉")
                    .font(.system(size: 96))
                    .accessibilityHidden(true)

                PlayAgainButton(action: startOver)
            } else if let round {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: Self.tileMinimumWidth), spacing: Self.tileSpacing)
                    ],
                    spacing: Self.tileSpacing
                ) {
                    ForEach(round.options) { option in
                        Button {
                            pick(option.id)
                        } label: {
                            tile(option, in: round)
                        }
                        .buttonStyle(.calm)
                        .disabled(round.isSolved || round.isWrong(option.id))
                        .accessibilityLabel(Text("Picture \(option.id + 1)", comment: "A picture to choose"))
                    }
                }
                .frame(maxWidth: Self.boardWidth)
                .padding(.horizontal, 20)

                Text("Level \(round.level)", comment: "How far the child has got")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(CalmStyle.transition, value: round)
        .animation(CalmStyle.transition, value: hasFinishedEveryLevel)
        .onAppear {
            if round == nil { makeRound() }
        }
        .task(id: advanceToken) {
            guard round?.isSolved == true else { return }
            try? await Task.sleep(for: Self.solvedPause)
            guard !Task.isCancelled else { return }
            advance()
        }
    }

    private func tile(_ option: OddOneOutRound.Option, in round: OddOneOutRound) -> some View {
        let isAnswer = round.isSolved && option.id == round.oddID
        let isRejected = round.isWrong(option.id)
        let shape = RoundedRectangle(cornerRadius: Self.tileCornerRadius, style: .continuous)

        return ZStack {
            shape.fill(isAnswer ? profile.theme.wash : Color(.secondarySystemBackground))

            Text(option.emoji)
                .font(.system(size: 52))
        }
        .overlay {
            shape.strokeBorder(
                profile.theme.tint.opacity(isAnswer ? 0.7 : 0.15),
                lineWidth: isAnswer ? 3 : 2
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .opacity(isRejected ? 0.3 : 1)
    }

    private var statusText: Text {
        if hasFinishedEveryLevel {
            return Text("You found them all!", comment: "Every Odd One Out level is done")
        }
        if round?.isSolved == true {
            return Text("That's the one!", comment: "The child found the odd picture")
        }
        return Text("Which one does not belong?", comment: "Odd One Out instruction")
    }

    private func pick(_ id: Int) {
        guard var current = round else { return }
        guard current.pick(id) == .right else {
            round = current
            return
        }

        round = current
        advanceToken += 1
    }

    private func advance() {
        guard level < OddOneOutCatalog.levelCount else {
            hasFinishedEveryLevel = true
            round = nil
            return
        }

        level += 1
        makeRound()
    }

    private func startOver() {
        level = 1
        hasFinishedEveryLevel = false
        makeRound()
    }

    private func makeRound() {
        var generator = SystemRandomNumberGenerator()
        round = OddOneOutRound.make(level: level, using: &generator)
    }
}
