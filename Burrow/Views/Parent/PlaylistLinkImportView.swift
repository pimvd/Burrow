import SwiftData
import SwiftUI

/// What a parent sees after opening a playlist link and passing the gate: the
/// playlist the link carries, the profile it should go to, and one button that
/// turns it into a tile. Nothing is added until that button is pressed.
struct PlaylistLinkImportView: View {
    /// `nil` when the link could not be read.
    let link: PlaylistLink?

    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var store

    @Query(sort: \ChildProfile.sortOrder) private var profiles: [ChildProfile]
    @Query private var tiles: [Tile]

    @State private var selectedProfileID: UUID?
    @State private var addedForProfileName: String?
    @State private var limitMessage: String?
    @State private var errorMessage: String?

    private var selectedProfile: ChildProfile? {
        profiles.first { $0.id == selectedProfileID } ?? profiles.first
    }

    /// How many of the link's items fit in one playlist right now. The rest is
    /// left out, and the footer says so.
    private var itemsThatFit: Int {
        guard let link else { return 0 }
        return min(link.items.count, ProGate.Limit.mediaItemsPerTile.maximum(hasFullAccess: store.hasFullAccess))
    }

    var body: some View {
        Group {
            if let link {
                form(for: link)
            } else {
                ContentUnavailableView {
                    Label(
                        String(localized: "This link cannot be read", comment: "Playlist link unreadable"),
                        systemImage: "link.badge.plus"
                    )
                } description: {
                    Text(
                        "It may have been cut off when it was copied. Ask for the link again.",
                        comment: "Playlist link unreadable description"
                    )
                }
            }
        }
        .navigationTitle(Text("Add a playlist", comment: "Playlist link import title"))
        .navigationBarTitleDisplayMode(.inline)
        .proLimitPrompt($limitMessage)
        .alert(
            Text("Something went wrong", comment: "Generic error alert title"),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button(role: .cancel) {
                errorMessage = nil
            } label: {
                Text("OK", comment: "Alert dismiss")
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func form(for link: PlaylistLink) -> some View {
        Form {
            Section {
                LabeledContent {
                    Text(link.title)
                } label: {
                    Text("Title", comment: "Tile editor section")
                }
                LabeledContent {
                    Label(link.category.localizedTitle, systemImage: link.category.symbolName)
                } label: {
                    Text("Type", comment: "Tile category row")
                }
            }

            Section {
                ForEach(Array(link.items.enumerated()), id: \.offset) { index, item in
                    Label(link.displayTitle(of: item, at: index), systemImage: item.type.symbolName)
                        .foregroundStyle(index < itemsThatFit ? .primary : .tertiary)
                }
            } header: {
                Text("Playlist", comment: "Tile editor section")
            } footer: {
                if itemsThatFit < link.items.count {
                    Text(ProGate.limitMessage(for: .mediaItemsPerTile, hasFullAccess: store.hasFullAccess))
                }
            }

            if profiles.isEmpty {
                Section {
                    Text(
                        "Create a profile first, then you can add tiles for it.",
                        comment: "Empty tile list description"
                    )
                    .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    if profiles.count > 1 {
                        Picker(selection: Binding(
                            get: { selectedProfile?.id },
                            set: { selectedProfileID = $0 }
                        )) {
                            ForEach(profiles) { profile in
                                Text(profile.name).tag(Optional(profile.id))
                            }
                        } label: {
                            Text("Profile", comment: "Tile list profile picker")
                        }
                        .disabled(addedForProfileName != nil)
                    }

                    if let addedForProfileName {
                        Label {
                            Text("Added for \(addedForProfileName).", comment: "Playlist link added")
                        } icon: {
                            Image(systemName: "checkmark.circle")
                        }
                        .foregroundStyle(.secondary)
                    } else {
                        Button {
                            add(link)
                        } label: {
                            Label(
                                String(localized: "Add tile", comment: "Playlist link import button"),
                                systemImage: "plus.circle"
                            )
                        }
                    }
                } footer: {
                    if link.items.contains(where: { $0.type == .youtube }) {
                        Text(YouTubeSupportNotice.full)
                    }
                }
            }
        }
    }

    private func add(_ link: PlaylistLink) {
        guard let profile = selectedProfile else { return }

        let ownedTiles = tiles.filter { $0.ownerProfileID == profile.id && !$0.isTrashed }
        guard ProGate.canAdd(.tilesPerProfile, currentCount: ownedTiles.count, hasFullAccess: store.hasFullAccess) else {
            limitMessage = ProGate.limitMessage(for: .tilesPerProfile, hasFullAccess: store.hasFullAccess)
            return
        }

        let tile = Tile(title: link.title, category: link.category, ownerProfileID: profile.id)
        tile.sortOrder = (ownedTiles.map(\.sortOrder).max() ?? -1) + 1
        modelContext.insert(tile)

        for (index, entry) in link.items.prefix(itemsThatFit).enumerated() {
            let item = MediaItem(
                type: entry.type,
                title: link.displayTitle(of: entry, at: index),
                youtubeVideoID: entry.type == .youtube ? entry.identifier : nil,
                appleMusicItemID: entry.type == .appleMusic ? entry.identifier : nil
            )
            modelContext.insert(item)
            tile.append(item)
        }

        if let error = ModelSaver.save(modelContext, describing: "adding a tile from a link") {
            errorMessage = error.localizedDescription
            return
        }
        addedForProfileName = profile.name
    }
}
