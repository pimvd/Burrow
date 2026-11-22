import SwiftData
import SwiftUI

/// What a parent sees after opening a playlist link and passing the gate: the
/// playlist the link carries, the profiles it should go to, and one button that
/// turns it into a tile. Nothing is added until that button is pressed.
///
/// With more than one profile chosen, the tile belongs to the first and is
/// shared with the others, the same as sharing it from a profile's settings:
/// one playlist to keep up to date, seen by every child it was added for.
struct PlaylistLinkImportView: View {
    /// `nil` when the link could not be read.
    let link: PlaylistLink?

    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var store

    @Query(sort: \ChildProfile.sortOrder) private var profiles: [ChildProfile]
    @Query private var tiles: [Tile]

    /// `nil` until the parent changes it: then the first profile is chosen.
    @State private var chosenProfileIDs: Set<UUID>?
    @State private var addedForProfileNames: String?
    @State private var limitMessage: String?
    @State private var errorMessage: String?

    private var selectedProfileIDs: Set<UUID> {
        chosenProfileIDs ?? Set(profiles.prefix(1).map(\.id))
    }

    /// The chosen profiles, in the order the parent sees them.
    private var selectedProfiles: [ChildProfile] {
        profiles.filter { selectedProfileIDs.contains($0.id) }
    }

    /// The link's official picture, once downloaded.
    @State private var downloadedArtwork: Data?

    /// The tile's picture: the link's own image when it could be downloaded,
    /// otherwise drawn from the icon and colour the link names.
    private var artwork: Data? {
        downloadedArtwork ?? link.flatMap { TileArtwork.render(linkIcon: $0.icon, color: $0.color) }
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
        .task {
            if let image = link?.image {
                downloadedArtwork = await TileArtwork.download(image)
            }
        }
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
                if let artwork, let image = UIImage(data: artwork) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
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
                        ForEach(profiles) { profile in
                            Toggle(isOn: Binding(
                                get: { selectedProfileIDs.contains(profile.id) },
                                set: { isOn in
                                    var ids = selectedProfileIDs
                                    if isOn { ids.insert(profile.id) } else { ids.remove(profile.id) }
                                    chosenProfileIDs = ids
                                }
                            )) {
                                Text(profile.name)
                            }
                            .disabled(addedForProfileNames != nil)
                        }
                    }

                    if let addedForProfileNames {
                        Label {
                            Text("Added for \(addedForProfileNames).", comment: "Playlist link added")
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
                        .disabled(selectedProfiles.isEmpty)
                    }
                } header: {
                    if profiles.count > 1 {
                        Text("Profiles", comment: "Profile list title")
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
        let chosen = selectedProfiles
        guard let owner = chosen.first else { return }

        let ownedTiles = tiles.filter { $0.ownerProfileID == owner.id && !$0.isTrashed }
        guard ProGate.canAdd(.tilesPerProfile, currentCount: ownedTiles.count, hasFullAccess: store.hasFullAccess) else {
            limitMessage = ProGate.limitMessage(for: .tilesPerProfile, hasFullAccess: store.hasFullAccess)
            return
        }

        let tile = Tile(
            title: link.title,
            imageData: artwork ?? Data(),
            category: link.category,
            ownerProfileID: owner.id
        )
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

        // The other children see the same tile, shared with them.
        for profile in chosen.dropFirst() {
            profile.setSharedTile(tile.id, visible: true)
        }

        if let error = ModelSaver.save(modelContext, describing: "adding a tile from a link") {
            errorMessage = error.localizedDescription
            return
        }
        addedForProfileNames = chosen.map(\.name).formatted(.list(type: .and))
    }
}
