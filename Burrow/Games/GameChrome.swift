import SwiftUI

/// The two pieces of furniture every game shares: the line that says what is
/// going on, and the button that starts another round.
///
/// Keeping them here is what stops six games from drifting into six slightly
/// different looking captions and buttons.
struct GameStatusLine: View {
    let text: Text

    var body: some View {
        text
            .font(.title3.weight(.medium))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            // A fixed height so the board does not shift up and down as the
            // caption changes between one line and two.
            .frame(height: 44)
            .padding(.horizontal, 20)
    }
}

struct PlayAgainButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
