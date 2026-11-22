import PhotosUI
import SwiftData
import SwiftUI

/// Creates or edits a tile.
///
/// The tile's scalar settings (title, picture, shuffle, loop, …) are kept in
/// local state and written on Save, which is what makes the iCloud conflict
/// check possible. The playlist below is edited straight away, the way a
/// sub-list normally behaves.
struct TileEditorView: View {
    enum Mode {
        case create(category: TileCategory, ownerProfileID: UUID)
        case edit(Tile)
    }

    let mode: Mode

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreManager.self) private var store

    @State private var tile: Tile?
    @State private var title = ""
    @State private var imageData = Data()
    @State private var loopPlaylist = true
    @State private var isHidden = false

    @State private var photoSelection: PhotosPickerItem?
    @State private var isShowingIconPicker = false
    @State private var isAddingMediaItem = false
    @State private var conflictGuard: EditConflictGuard?
    @State private var isShowingConflict = false
    @State private var errorMessage: String?
    @State private var limitMessage: String?

    private var category: TileCategory {
        switch mode {
        case .create(let category, _): return category
        case .edit(let tile): return tile.category
        }
    }

    private var isCreating: Bool {
        if case .create = mode { return true }
        return false
    }

    private var mediaItems: [MediaItem] { tile?.orderedMediaItems ?? [] }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Type", comment: "Tile category row")

                    Spacer(minLength: 12)

                    Label(category.localizedTitle, systemImage: category.symbolName)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
            } footer: {
                Text(
                    "The type is set when the tile is created and cannot be changed later. To switch, delete this tile and make a new one.",
                    comment: "Tile category is permanent"
                )
            }

            Section {
                TextField(
                    String(localized: "Title", comment: "Tile title field"),
                    text: $title
                )
                .textInputAutocapitalization(.sentences)
            } header: {
                Text("Title", comment: "Tile editor section")
            }

            Section {
                HStack(spacing: 16) {
                    TileImageView(
                        tileID: tile?.id ?? UUID(),
                        imageData: imageData,
                        category: category,
                        tint: .accentColor
                    )
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 10) {
                        // Both controls share one Form row. Without an explicit
                        // button style the row is a single tap target and fires
                        // both actions, so choosing a photo also opened the icon
                        // sheet and the two presentations cancelled each other.
                        PhotosPicker(selection: $photoSelection, matching: .images) {
                            Label(
                                String(localized: "Choose a photo", comment: "Tile image option"),
                                systemImage: "photo"
                            )
                        }
                        .buttonStyle(.borderless)

                        Button {
                            isShowingIconPicker = true
                        } label: {
                            Label(
                                String(localized: "Choose an icon", comment: "Tile image option"),
                                systemImage: "square.grid.2x2"
                            )
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Picture", comment: "Tile editor section")
            }

            Section {
                Toggle(isOn: $loopPlaylist) {
                    Text("Repeat", comment: "Tile playback setting")
                }
                Toggle(isOn: $isHidden) {
                    Text("Hide from the child", comment: "Tile visibility setting")
                }
            } header: {
                Text("Playback", comment: "Tile editor section")
            } footer: {
                if category == .music {
                    Text(
                        "A YouTube item in a music tile plays sound only; its picture stays hidden. Its sound also stops when Burrow is minimised, where the rest of the playlist plays on.",
                        comment: "YouTube audio-only explanation"
                    )
                }
            }

            playlistSection

            if !isCreating {
                shareSection
            }

            if case .edit(let existing) = mode {
                Section {
                    // Shortcut straight to this tile's own numbers.
                    NavigationLink {
                        TileStatisticsView(tileID: existing.id)
                    } label: {
                        Label(
                            String(localized: "Statistics for this tile", comment: "Tile editor row"),
                            systemImage: "chart.bar"
                        )
                    }

                    Button(role: .destructive) {
                        moveToTrash(existing)
                    } label: {
                        Label(
                            String(localized: "Move to trash", comment: "Tile editor row"),
                            systemImage: "trash"
                        )
                    }
                }
            }
        }
        .navigationTitle(
            isCreating
                ? Text("New tile", comment: "Tile editor title, creating")
                : Text("Edit tile", comment: "Tile editor title, editing")
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    cancel()
                } label: {
                    Text("Cancel", comment: "Dismiss the editor")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    attemptSave()
                } label: {
                    Text("Save", comment: "Save the editor")
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .sheet(isPresented: $isShowingIconPicker) {
            NavigationStack {
                TileIconPickerView { data in
                    imageData = data
                    isShowingIconPicker = false
                }
            }
        }
        .sheet(isPresented: $isAddingMediaItem) {
            NavigationStack {
                AddMediaItemView(category: category) { item in
                    add(item)
                }
            }
        }
        .conflictResolutionDialog(isPresented: $isShowingConflict, recordName: title) { resolution in
            resolve(resolution)
        }
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
        .proLimitPrompt($limitMessage)
        .task(id: photoSelection) {
            await loadSelectedPhoto()
        }
        .onAppear(perform: prepare)
    }

    // MARK: - Playlist

    @ViewBuilder
    private var playlistSection: some View {
        Section {
            if mediaItems.isEmpty {
                Text("Nothing added yet.", comment: "Empty playlist")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(mediaItems) { item in
                    MediaItemRow(item: item)
                }
                .onMove(perform: moveMediaItems)
                .onDelete(perform: deleteMediaItems)
            }

            Button {
                addMediaItem()
            } label: {
                Label(
                    String(localized: "Add item", comment: "Playlist button"),
                    systemImage: "plus.circle"
                )
            }
        } header: {
            Text("Playlist", comment: "Tile editor section")
        } footer: {
            if let remaining = ProGate.remaining(
                .mediaItemsPerTile,
                currentCount: mediaItems.count,
                hasFullAccess: store.hasFullAccess
            ) {
                Text(
                    "\(remaining) of \(ProGate.Limit.mediaItemsPerTile.maximum(hasFullAccess: store.hasFullAccess)) items left.",
                    comment: "Media item counter"
                )
            }
        }
    }

    // MARK: - Sharing

    @ViewBuilder
    private var shareSection: some View {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let link = PlaylistLink(
            title: trimmedTitle.isEmpty ? category.localizedTitle : trimmedTitle,
            category: category,
            mediaItems: mediaItems
        )
        Section {
            if let link {
                ShareLink(item: link.url) {
                    Label(
                        String(localized: "Share as link", comment: "Tile editor row"),
                        systemImage: "link"
                    )
                }
            } else {
                Label(
                    String(localized: "Share as link", comment: "Tile editor row"),
                    systemImage: "link"
                )
                .foregroundStyle(.tertiary)
            }
        } footer: {
            Text(
                "A link carries the YouTube and Apple Music items in this tile, not files from this device. Whoever opens it in Burrow can add their own copy.",
                comment: "Share as link explanation"
            )
        }
    }

    // MARK: - Lifecycle

    private func prepare() {
        switch mode {
        case .create(let category, let ownerProfileID):
            guard tile == nil else { return }
            // The tile has to exist in the context before playlist items can be
            // attached to it. Cancelling removes it again.
            let created = Tile(title: "", category: category, ownerProfileID: ownerProfileID)
            created.sortOrder = nextSortOrder(for: ownerProfileID)
            modelContext.insert(created)
            tile = created
            loopPlaylist = created.loopPlaylist

        case .edit(let existing):
            guard tile == nil else { return }
            tile = existing
            title = existing.title
            imageData = existing.imageData
            loopPlaylist = existing.loopPlaylist
            isHidden = existing.isHidden
            conflictGuard = EditConflictGuard(expectedLastModified: existing.lastModified)
        }
    }

    private func nextSortOrder(for ownerProfileID: UUID) -> Int {
        let descriptor = FetchDescriptor<Tile>(
            predicate: #Predicate { $0.ownerProfileID == ownerProfileID }
        )
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        return (existing.map(\.sortOrder).max() ?? -1) + 1
    }

    private func loadSelectedPhoto() async {
        guard let photoSelection else { return }
        do {
            guard let data = try await photoSelection.loadTransferable(type: Data.self) else { return }
            guard let prepared = TileArtwork.prepare(photoData: data) else {
                errorMessage = String(
                    localized: "That picture could not be used.",
                    comment: "Photo import failure"
                )
                return
            }
            imageData = prepared
        } catch {
            errorMessage = error.localizedDescription
        }
        self.photoSelection = nil
    }

    // MARK: - Playlist actions

    private func addMediaItem() {
        guard ProGate.canAdd(.mediaItemsPerTile, currentCount: mediaItems.count, hasFullAccess: store.hasFullAccess) else {
            limitMessage = ProGate.limitMessage(for: .mediaItemsPerTile, hasFullAccess: store.hasFullAccess)
            return
        }
        isAddingMediaItem = true
    }

    private func add(_ item: MediaItem) {
        guard let tile else { return }
        modelContext.insert(item)
        guard tile.append(item) else {
            modelContext.delete(item)
            errorMessage = String(
                localized: "This kind of item does not fit in this tile.",
                comment: "Category mismatch when adding a media item"
            )
            return
        }
        ModelSaver.save(modelContext, describing: "adding a playlist item")
        conflictGuard?.recordLocalWrite(at: tile.lastModified)
    }

    private func moveMediaItems(from source: IndexSet, to destination: Int) {
        guard let tile else { return }
        var reordered = tile.orderedMediaItems
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in reordered.enumerated() where item.sortOrder != index {
            item.sortOrder = index
            item.lastModified = Date()
        }
        tile.lastModified = Date()
        ModelSaver.save(modelContext, describing: "reordering playlist items")
        conflictGuard?.recordLocalWrite(at: tile.lastModified)
    }

    private func deleteMediaItems(at offsets: IndexSet) {
        guard let tile else { return }
        let items = tile.orderedMediaItems
        for index in offsets where items.indices.contains(index) {
            let item = items[index]
            if let fileName = item.localFileName, !fileName.isEmpty {
                MediaLibrary.shared.deleteFile(named: fileName)
            }
            modelContext.delete(item)
        }
        tile.normalizeMediaItemOrder()
        tile.lastModified = Date()
        ModelSaver.save(modelContext, describing: "removing playlist items")
        conflictGuard?.recordLocalWrite(at: tile.lastModified)
    }

    // MARK: - Saving

    private func attemptSave() {
        if case .edit(let existing) = mode,
           let conflictGuard,
           conflictGuard.hasConflict(currentLastModified: existing.lastModified) {
            isShowingConflict = true
            return
        }
        commit()
    }

    private func resolve(_ resolution: ConflictResolution) {
        switch resolution {
        case .keepMine:
            commit()
        case .keepServer:
            guard case .edit(let existing) = mode else { return }
            title = existing.title
            imageData = existing.imageData
            loopPlaylist = existing.loopPlaylist
            isHidden = existing.isHidden
            conflictGuard = EditConflictGuard(expectedLastModified: existing.lastModified)
        case .cancel:
            break
        }
    }

    private func commit() {
        guard let tile else { return }
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        tile.title = trimmed
        tile.imageData = imageData
        tile.loopPlaylist = loopPlaylist
        tile.isHidden = isHidden
        tile.lastModified = Date()

        TileImageCache.shared.invalidate(tileID: tile.id)

        if let error = ModelSaver.save(modelContext, describing: "saving a tile") {
            errorMessage = error.localizedDescription
            return
        }
        dismiss()
    }

    private func cancel() {
        if isCreating, let tile {
            // Remove the placeholder tile and anything already attached to it.
            TrashService.permanentlyDelete(tile, in: modelContext)
            ModelSaver.save(modelContext, describing: "discarding a new tile")
        }
        dismiss()
    }

    private func moveToTrash(_ tile: Tile) {
        tile.moveToTrash()
        ModelSaver.save(modelContext, describing: "moving a tile to the trash")
        dismiss()
    }
}

// MARK: - Rows and pickers

private struct MediaItemRow: View {
    let item: MediaItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.type.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .lineLimit(1)

                Text(item.type.localizedTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Parent-only badge: the child never sees this.
                if let error = item.lastKnownErrorMessage, !error.isEmpty {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}

private struct TileIconPickerView: View {
    let onPick: (Data) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 84), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(TileArtwork.icons) { icon in
                    Button {
                        pick(icon)
                    } label: {
                        Image(systemName: icon.symbolName)
                            .font(.system(size: 30))
                            .frame(width: 80, height: 80)
                            .foregroundStyle(Color.accentColor)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.14))
                            )
                    }
                    .buttonStyle(.calm)
                    .accessibilityLabel(Text(icon.displayName))
                }
            }
            .padding(20)
        }
        .navigationTitle(Text("Choose an icon", comment: "Icon picker title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel", comment: "Dismiss the picker")
                }
            }
        }
    }

    private func pick(_ icon: TileArtwork.Icon) {
        let tint = UIColor(Color.accentColor)
        let background = UIColor.secondarySystemBackground
        guard let data = TileArtwork.renderIcon(icon, tint: tint, background: background) else { return }
        onPick(data)
    }
}
