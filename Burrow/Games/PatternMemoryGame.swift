import SwiftUI

/// Copy the Pattern: four pads light up in turn and the child taps them back.
/// The pattern grows by one pad every round and there is no way to lose — a
/// wrong tap simply shows the same pattern again.
struct PatternMemoryGame: View {
    let profile: ChildProfile

    private struct Pad: Identifiable {
        let id: Int
        let colour: Color
        let symbolName: String
        let name: LocalizedStringResource
    }

    /// The pads carry a symbol as well as a colour, so they stay tellable
    /// apart without relying on colour alone.
    private static let pads: [Pad] = [
        Pad(
            id: 0,
            colour: Color(red: 0.404, green: 0.529, blue: 0.639),
            symbolName: "drop.fill",
            name: LocalizedStringResource("Blue", comment: "Colour of a pattern pad")
        ),
        Pad(
            id: 1,
            colour: Color(red: 0.741, green: 0.529, blue: 0.451),
            symbolName: "star.fill",
            name: LocalizedStringResource("Orange", comment: "Colour of a pattern pad")
        ),
        Pad(
            id: 2,
            colour: Color(red: 0.482, green: 0.588, blue: 0.475),
            symbolName: "leaf.fill",
            name: LocalizedStringResource("Green", comment: "Colour of a pattern pad")
        ),
        Pad(
            id: 3,
            colour: Color(red: 0.596, green: 0.549, blue: 0.686),
            symbolName: "moon.fill",
            name: LocalizedStringResource("Purple", comment: "Colour of a pattern pad")
        )
    ]

    private enum Phase: Equatable {
        /// The pads are playing the pattern back; taps are ignored.
        case showing
        /// The child's turn.
        case waiting
        /// A wrong tap, waiting to show the same pattern again.
        case wrong
    }

    private static let leadIn = Duration.milliseconds(600)
    private static let padLit = Duration.milliseconds(450)
    private static let padDark = Duration.milliseconds(250)
    private static let wrongPause = Duration.milliseconds(1_200)

    private static let padSpacing: CGFloat = 16
    private static let padCornerRadius: CGFloat = 28
    private static let boardWidth: CGFloat = 340

    @State private var round = PatternMemoryRound()
    @State private var phase: Phase = .showing
    @State private var litPad: Int?
    @State private var playbackToken = 0

    var body: some View {
        VStack(spacing: 20) {
            GameStatusLine(text: statusText)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Self.padSpacing), count: 2),
                spacing: Self.padSpacing
            ) {
                ForEach(Self.pads) { pad in
                    Button {
                        tap(pad.id)
                    } label: {
                        padFace(pad)
                    }
                    .buttonStyle(.calm)
                    .disabled(phase != .waiting)
                    .accessibilityLabel(Text(pad.name))
                }
            }
            .frame(maxWidth: Self.boardWidth)
            .padding(.horizontal, 20)

            Text("Round \(max(1, round.round))", comment: "How far the child has got")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(CalmStyle.transition, value: litPad)
        .animation(CalmStyle.transition, value: phase)
        .onAppear {
            if round.pattern.isEmpty { startGame() }
        }
        .task(id: playbackToken) {
            switch phase {
            case .showing:
                await playBack()
            case .wrong:
                try? await Task.sleep(for: Self.wrongPause)
                guard !Task.isCancelled else { return }
                round.replay()
                show()
            case .waiting:
                break
            }
        }
    }

    private func padFace(_ pad: Pad) -> some View {
        let isLit = litPad == pad.id

        return ZStack {
            RoundedRectangle(cornerRadius: Self.padCornerRadius, style: .continuous)
                .fill(pad.colour.opacity(isLit ? 1 : 0.35))

            Image(systemName: pad.symbolName)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.white.opacity(isLit ? 1 : 0.75))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var statusText: Text {
        switch phase {
        case .showing:
            return Text("Watch carefully…", comment: "The pattern is playing")
        case .waiting:
            return Text("Your turn", comment: "The child is about to play")
        case .wrong:
            return Text("Not quite. Watch again.", comment: "A wrong tap in Copy the Pattern")
        }
    }

    private func startGame() {
        var generator = SystemRandomNumberGenerator()
        round.reset()
        round.extend(using: &generator)
        show()
    }

    /// Plays the pattern back, one pad at a time, then hands over.
    private func playBack() async {
        litPad = nil
        try? await Task.sleep(for: Self.leadIn)

        for pad in round.pattern {
            guard !Task.isCancelled else { return }
            litPad = pad
            try? await Task.sleep(for: Self.padLit)
            litPad = nil
            try? await Task.sleep(for: Self.padDark)
        }

        guard !Task.isCancelled else { return }
        phase = .waiting
    }

    private func tap(_ pad: Int) {
        guard phase == .waiting else { return }

        switch round.tap(pad) {
        case .completed:
            var generator = SystemRandomNumberGenerator()
            round.extend(using: &generator)
            show()
        case .wrong:
            phase = .wrong
            playbackToken += 1
        case .correct, .ignored:
            break
        }
    }

    /// Restarts the playback task, whatever it was doing.
    private func show() {
        litPad = nil
        phase = .showing
        playbackToken += 1
    }
}
