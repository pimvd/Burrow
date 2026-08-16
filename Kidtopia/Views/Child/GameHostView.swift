import SwiftData
import SwiftUI

/// Full screen presentation of one game, mirroring `NowPlayingView`'s shape:
/// the same close affordance in the same place, and the same
/// onAppear/onDisappear pair driving the usage recorder.
struct GameHostView: View {
    let game: GameCatalog.Game
    let profile: ChildProfile

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var recorder = UsageRecorder()

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .background(profile.theme.wash.ignoresSafeArea())
            .background(Color(.systemBackground).ignoresSafeArea())
            .statusBarHidden()
            .onAppear {
                recorder.beginGame(profileID: profile.id, game: game, in: modelContext)
            }
            .onDisappear {
                recorder.endGame(in: modelContext)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch game.identifier {
        case GameCatalog.matchingPairs:
            MatchingPairsGame(profile: profile)
        default:
            // Unreachable: every catalog entry is handled above, and the
            // catalog is the only source of games.
            Color.clear
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: 48)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.calm)
            .accessibilityLabel(Text("Close", comment: "Close the player"))

            Spacer(minLength: 0)

            ScreenTimeIndicator()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}
