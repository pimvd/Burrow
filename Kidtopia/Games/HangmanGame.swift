import SwiftUI

/// Hangman, without the gallows. The six chances are hearts, a picture says
/// which word is being spelled, and a lost round just shows the answer.
struct HangmanGame: View {
    let profile: ChildProfile

    private static let letterWidth: CGFloat = 34
    private static let letterHeight: CGFloat = 46
    private static let keyMinimumWidth: CGFloat = 44
    private static let keySpacing: CGFloat = 8

    @State private var round: HangmanRound?
    @State private var lastWordID: String?

    var body: some View {
        VStack(spacing: 20) {
            if let round {
                GameStatusLine(text: statusText(round))

                Text(round.emoji)
                    .font(.system(size: 72))
                    .accessibilityHidden(true)

                word(round)

                hearts(round)

                if round.isFinished {
                    PlayAgainButton(action: startRound)
                } else {
                    keyboard(round)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(CalmStyle.transition, value: round)
        .onAppear {
            if round == nil { startRound() }
        }
    }

    private func word(_ round: HangmanRound) -> some View {
        let revealed = round.revealed

        return HStack(spacing: 8) {
            ForEach(revealed.indices, id: \.self) { position in
                letterSlot(revealed[position], position: position)
            }
        }
        .padding(.horizontal, 20)
    }

    private func letterSlot(_ letter: Character?, position: Int) -> some View {
        VStack(spacing: 4) {
            Text(letter.map { String($0) } ?? " ")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(profile.theme.tint)
                .frame(height: Self.letterHeight - 6)

            Capsule()
                .fill(profile.theme.tint.opacity(0.4))
                .frame(height: 3)
        }
        .frame(width: Self.letterWidth)
        .accessibilityLabel(
            letter.map { Text(String($0)) }
                ?? Text("Hidden letter", comment: "A letter not yet guessed")
        )
        .accessibilityHint(Text("Letter \(position + 1)", comment: "Position in the word"))
    }

    private func hearts(_ round: HangmanRound) -> some View {
        HStack(spacing: 8) {
            ForEach(0 ..< HangmanRound.allowedMistakes, id: \.self) { index in
                Image(systemName: index < round.mistakesRemaining ? "heart.fill" : "heart")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        index < round.mistakesRemaining
                            ? profile.theme.tint
                            : Color.secondary.opacity(0.35)
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text("\(round.mistakesRemaining) tries left", comment: "Remaining Hangman guesses")
        )
    }

    private func keyboard(_ round: HangmanRound) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: Self.keyMinimumWidth), spacing: Self.keySpacing)],
            spacing: Self.keySpacing
        ) {
            ForEach(HangmanRound.alphabet, id: \.self) { letter in
                Button {
                    guess(letter)
                } label: {
                    key(letter, round: round)
                }
                .buttonStyle(.calm)
                .disabled(round.hasGuessed(letter))
                .accessibilityLabel(Text(String(letter)))
            }
        }
        .padding(.horizontal, 20)
    }

    private func key(_ letter: Character, round: HangmanRound) -> some View {
        let isUsed = round.hasGuessed(letter)
        let isInWord = round.word.contains(letter)

        return Text(String(letter))
            .font(.system(size: 20, weight: .medium, design: .rounded))
            .foregroundStyle(isUsed && isInWord ? profile.theme.tint : Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                isUsed ? profile.theme.wash : Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .opacity(isUsed ? 0.45 : 1)
    }

    private func statusText(_ round: HangmanRound) -> Text {
        if round.isWon {
            return Text("You did it!", comment: "The child solved the word")
        }
        if round.isLost {
            return Text(
                "The word was \(String(round.word))",
                comment: "Revealing the answer after a lost round"
            )
        }
        return Text("Guess the word", comment: "Hangman instruction")
    }

    private func guess(_ letter: Character) {
        guard var current = round else { return }
        current.guess(letter)
        round = current
    }

    private func startRound() {
        var generator = SystemRandomNumberGenerator()
        let previous = HangmanWords.all.first { $0.id == lastWordID }
        let word = HangmanWords.next(after: previous, using: &generator)

        lastWordID = word.id
        round = HangmanRound(word: word.localized, emoji: word.emoji)
    }
}
