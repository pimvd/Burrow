import SwiftData
import SwiftUI

/// The parent's list of tiles, grouped per profile. Reordering happens here with
/// drag-to-reorder in edit mode; the child grid is never rearrangeable.
struct TileListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var store

    @Query(sort: \ChildProfile.sortOrder) private var profiles: [ChildProfile]
    @Query(sort: \Tile.sortOrder) private var allTiles: [Tile]

    @State private var selectedProfileID: UUID?
    @State private var editingTile: Tile?
    @State private var newTileCategory: TileCategory?
    @State private var limitMessage: String?

    private var selectedProfile: ChildProfile? {
        profiles.first { $0.id == selectedProfileID } ?? profiles.first
    }

    private var ownedTiles: [Tile] {
        guard let selectedProfile else { return [] }
        return allTiles
            .filter { $0.ownerProfileID == selectedProfile.id && !$0.isTrashed }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var sharedTiles: [Tile] {
        guard let selectedProfile else { return [] }
        return allTiles
            .filter {
                !$0.isTrashed
                    && $0.ownerProfileID != selectedProfile.id
                    && selectedProfile.visibleSharedTileIDs.contains($0.id)
            }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        List {
            if profiles.count > 1 {
                Section {
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
                    .pickerStyle(.menu)
                }
            }

            Section {
                ForEach(ownedTiles) { tile in
                    Button {
                        editingTile = tile
                    } label: {
                        TileRow(tile: tile)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            moveToTrash(tile)
                        } label: {
                            Label(
                                String(localized: "Delete", comment: "Swipe action"),
                                systemImage: "trash"
                            )
                        }

                        Button {
                            toggleHidden(tile)
                        } label: {
                            Label(
                                tile.isHidden
                                    ? String(localized: "Show", comment: "Swipe action")
                                    : String(localized: "Hide", comment: "Swipe action"),
                                systemImage: tile.isHidden ? "eye" : "eye.slash"
                            )
                        }
                        .tint(.orange)
                    }
                }
                .onMove(perform: moveTiles)
            } header: {
                Text("Own tiles", comment: "Tile list section")
            } footer: {
                if let remaining = ProGate.remaining(
                    .tilesPerProfile,
                    currentCount: ownedTiles.count,
                    isPro: store.isPro
                ) {
                    Text(
                        "\(remaining) of \(ProGate.Limit.tilesPerProfile.maximum(isPro: store.isPro)) tiles left in the free version.",
                        comment: "Free tier tile counter"
                    )
                }
            }

            if !sharedTiles.isEmpty {
                Section {
                    ForEach(sharedTiles) { tile in
                        Button {
                            editingTile = tile
                        } label: {
                            TileRow(tile: tile, ownerName: ownerName(of: tile))
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Shared with this profile", comment: "Tile list section")
                } footer: {
                    Text(
                        "A shared tile has the same settings everywhere. Change who can see it in the profile settings.",
                        comment: "Shared tile explanation"
                    )
                }
            }
        }
        .navigationTitle(Text("Tiles", comment: "Tile list title"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(TileCategory.allCases) { category in
                        Button {
                            addTile(category: category)
                        } label: {
                            Label(category.localizedTitle, systemImage: category.symbolName)
                        }
                    }
                } label: {
                    Label(
                        String(localized: "New tile", comment: "Toolbar button"),
                        systemImage: "plus"
                    )
                }
                .disabled(selectedProfile == nil)
            }
        }
        .overlay {
            if profiles.isEmpty {
                ContentUnavailableView {
                    Label(
                        String(localized: "No profiles yet", comment: "Empty tile list"),
                        systemImage: "person.crop.circle.badge.plus"
                    )
                } description: {
                    Text(
                        "Create a profile first, then you can add tiles for it.",
                        comment: "Empty tile list description"
                    )
                }
            } else if ownedTiles.isEmpty && sharedTiles.isEmpty {
                // This prompt lives on the parent side only. A child opening an
                // empty profile just sees a calm, empty grid.
                ContentUnavailableView {
                    Label(
                        String(localized: "Add your first tile", comment: "Empty tile list"),
                        systemImage: "square.grid.2x2"
                    )
                } description: {
                    Text(
                        "A tile is a big picture your child taps. Choose music or video, then add the songs or videos.",
                        comment: "Empty tile list description"
                    )
                }
            }
        }
        .sheet(item: $editingTile) { tile in
            NavigationStack {
                TileEditorView(mode: .edit(tile))
            }
        }
        .sheet(item: $newTileCategory) { category in
            NavigationStack {
                if let profile = selectedProfile {
                    TileEditorView(mode: .create(category: category, ownerProfileID: profile.id))
                }
            }
        }
        .alert(
            Text("Not available yet", comment: "Freemium limit alert title"),
            isPresented: Binding(
                get: { limitMessage != nil },
                set: { if !$0 { limitMessage = nil } }
            )
        ) {
            Button(role: .cancel) {
                limitMessage = nil
            } label: {
                Text("OK", comment: "Alert dismiss")
            }
        } message: {
            Text(limitMessage ?? "")
        }
        .onAppear {
            if selectedProfileID == nil {
                selectedProfileID = profiles.first?.id
            }
        }
    }

    private func ownerName(of tile: Tile) -> String? {
        profiles.first { $0.id == tile.ownerProfileID }?.name
    }

    private func addTile(category: TileCategory) {
        guard ProGate.canAdd(.tilesPerProfile, currentCount: ownedTiles.count, isPro: store.isPro) else {
            limitMessage = ProGate.limitMessage(for: .tilesPerProfile, isPro: store.isPro)
            return
        }
        newTileCategory = category
    }

    private func toggleHidden(_ tile: Tile) {
        tile.isHidden.toggle()
        tile.lastModified = Date()
        ModelSaver.save(modelContext, describing: "hiding a tile")
    }

    private func moveToTrash(_ tile: Tile) {
        tile.moveToTrash()
        ModelSaver.save(modelContext, describing: "moving a tile to the trash")
    }

    private func moveTiles(from source: IndexSet, to destination: Int) {
        var reordered = ownedTiles
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, tile) in reordered.enumerated() where tile.sortOrder != index {
            tile.sortOrder = index
            tile.lastModified = Date()
        }
        ModelSaver.save(modelContext, describing: "reordering tiles")
    }
}

// MARK: - Row

private struct TileRow: View {
    let tile: Tile
    var ownerName: String?

    var body: some View {
        HStack(spacing: 12) {
            TileImageView(
                tileID: tile.id,
                imageData: tile.imageData,
                category: tile.category,
                tint: .accentColor
            )
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(tile.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Label(
                        tile.category.localizedTitle,
                        systemImage: tile.category.symbolName
                    )
                    .labelStyle(.titleAndIcon)

                    Text("· \(tile.mediaItemCount)", comment: "Tile row item count")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let ownerName {
                    Text("From \(ownerName)", comment: "Shared tile owner")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)

            if tile.isHidden {
                Image(systemName: "eye.slash")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Hidden", comment: "Tile is hidden from the child"))
            }

            // Playback problems are only ever shown here, never to the child.
            if !tile.itemsWithErrors.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityLabel(Text("Has a problem", comment: "Tile has a media error"))
            }
        }
        .padding(.vertical, 4)
    }
}
