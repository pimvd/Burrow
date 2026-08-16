import SwiftData
import SwiftUI

/// Switches games on and off for one profile. Availability is the parent's
/// decision alone — there is no age rule and no recommendation.
struct ParentGamesView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ChildProfile.sortOrder) private var profiles: [ChildProfile]

    @State private var selectedProfileID: UUID?
    @State private var limitMessage: String?

    private var selectedProfile: ChildProfile? {
        profiles.first { $0.id == selectedProfileID } ?? profiles.first
    }

    var body: some View {
        Form {
            if profiles.count > 1 {
                Section {
                    Picker(selection: $selectedProfileID) {
                        ForEach(profiles) { profile in
                            Text(profile.name).tag(Optional(profile.id))
                        }
                    } label: {
                        Text("Profile", comment: "Profile picker label")
                    }
                }
            }

            if let profile = selectedProfile {
                Section {
                    ForEach(GameCatalog.all) { game in
                        Toggle(isOn: binding(for: game, profile: profile)) {
                            Label {
                                Text(game.localizedTitle)
                            } icon: {
                                Image(systemName: game.symbolName)
                            }
                        }
                    }
                } header: {
                    Text("Games", comment: "Parent games section")
                } footer: {
                    if let remaining = ProGate.remaining(
                        .gamesPerProfile,
                        currentCount: profile.enabledGameIDs.count,
                        isPro: store.isPro
                    ) {
                        Text("\(remaining) of 2 games left", comment: "Remaining free games")
                    }
                }
            } else {
                Text("Add a child profile first.", comment: "No profiles yet")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(Text("Games", comment: "Parent games title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { selectedProfileID = selectedProfile?.id }
        .alert(
            Text("Unlock Kidtopia", comment: "Purchase prompt title"),
            isPresented: Binding(
                get: { limitMessage != nil },
                set: { if !$0 { limitMessage = nil } }
            )
        ) {
            Button(role: .cancel) {
                limitMessage = nil
            } label: {
                Text("Not now", comment: "Dismiss the purchase prompt")
            }
        } message: {
            Text(limitMessage ?? "")
        }
    }

    private func binding(for game: GameCatalog.Game, profile: ChildProfile) -> Binding<Bool> {
        Binding(
            get: { profile.enabledGameIDs.contains(game.identifier) },
            set: { isOn in
                if isOn {
                    guard ProGate.canAdd(
                        .gamesPerProfile,
                        currentCount: profile.enabledGameIDs.count,
                        isPro: store.isPro
                    ) else {
                        limitMessage = ProGate.limitMessage(
                            for: .gamesPerProfile,
                            isPro: store.isPro
                        )
                        return
                    }
                }
                profile.setGame(game.identifier, enabled: isOn)
                ModelSaver.save(modelContext, describing: "switching a game")
            }
        )
    }
}
