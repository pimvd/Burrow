import SwiftData
import SwiftUI

/// Deleted tiles, recoverable for 14 days. After that they are removed for good
/// together with their statistics and their media files.
struct TrashView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Tile.trashedAt, order: .reverse) private var allTiles: [Tile]

    @State private var isConfirmingEmpty = false

    private var trashedTiles: [Tile] {
        allTiles.filter(\.isTrashed)
    }

    var body: some View {
        List {
            ForEach(trashedTiles) { tile in
                HStack(spacing: 12) {
                    TileImageView(
                        tileID: tile.id,
                        imageData: tile.imageData,
                        category: tile.category,
                        tint: .accentColor
                    )
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .saturation(0.2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tile.title)
                            .font(.headline)

                        Text(
                            "\(TrashService.daysRemaining(for: tile)) days left",
                            comment: "Trash retention countdown"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Button {
                        restore(tile)
                    } label: {
                        Text("Restore", comment: "Restore a tile from the trash")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 2)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        deleteForGood(tile)
                    } label: {
                        Label(
                            String(localized: "Delete now", comment: "Permanently delete a tile"),
                            systemImage: "trash"
                        )
                    }
                }
            }
        }
        .navigationTitle(Text("Trash", comment: "Trash title"))
        .toolbar {
            if !trashedTiles.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        isConfirmingEmpty = true
                    } label: {
                        Text("Empty", comment: "Empty the trash")
                    }
                }
            }
        }
        .overlay {
            if trashedTiles.isEmpty {
                ContentUnavailableView {
                    Label(
                        String(localized: "The trash is empty", comment: "Empty trash"),
                        systemImage: "trash"
                    )
                } description: {
                    Text(
                        "Deleted tiles stay here for 14 days, together with their statistics.",
                        comment: "Empty trash description"
                    )
                }
            }
        }
        .confirmationDialog(
            Text("Empty the trash?", comment: "Empty trash confirmation"),
            isPresented: $isConfirmingEmpty,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                emptyTrash()
            } label: {
                Text("Delete everything", comment: "Confirm emptying the trash")
            }
            Button(role: .cancel) {
                isConfirmingEmpty = false
            } label: {
                Text("Cancel", comment: "Cancel emptying the trash")
            }
        } message: {
            Text(
                "The tiles, their files and their statistics are removed for good.",
                comment: "Empty trash explanation"
            )
        }
        .task {
            TrashService.purgeExpiredTiles(in: modelContext)
        }
    }

    private func restore(_ tile: Tile) {
        tile.restoreFromTrash()
        ModelSaver.save(modelContext, describing: "restoring a tile")
    }

    private func deleteForGood(_ tile: Tile) {
        TrashService.permanentlyDelete(tile, in: modelContext)
        ModelSaver.save(modelContext, describing: "deleting a tile for good")
    }

    private func emptyTrash() {
        for tile in trashedTiles {
            TrashService.permanentlyDelete(tile, in: modelContext)
        }
        ModelSaver.save(modelContext, describing: "emptying the trash")
        isConfirmingEmpty = false
    }
}
