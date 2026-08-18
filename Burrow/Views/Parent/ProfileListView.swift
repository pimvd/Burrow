import SwiftData
import SwiftUI

/// Lists the child profiles, and lets the parent add, reorder and remove them.
struct ProfileListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var store

    @Query(sort: \ChildProfile.sortOrder) private var profiles: [ChildProfile]
    @Query private var tiles: [Tile]

    @State private var editingProfile: ChildProfile?
    @State private var isCreatingProfile = false
    @State private var limitMessage: String?
    @State private var profilePendingDeletion: ChildProfile?

    var body: some View {
        List {
            Section {
                ForEach(profiles) { profile in
                    Button {
                        editingProfile = profile
                    } label: {
                        ProfileRow(profile: profile, tileCount: tileCount(for: profile))
                    }
                    .buttonStyle(.plain)
                }
                .onMove(perform: moveProfiles)
                .onDelete(perform: requestDeletion)
            } footer: {
                if let remaining = ProGate.remaining(.profiles, currentCount: profiles.count, isPro: store.isPro) {
                    Text(
                        "\(remaining) of \(ProGate.Limit.profiles.maximum(isPro: store.isPro)) profiles left in the free version.",
                        comment: "Free tier profile counter"
                    )
                }
            }
        }
        .navigationTitle(Text("Profiles", comment: "Profile list title"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    addProfile()
                } label: {
                    Label(
                        String(localized: "Add profile", comment: "Toolbar button"),
                        systemImage: "plus"
                    )
                }
            }
        }
        .overlay {
            if profiles.isEmpty {
                ContentUnavailableView {
                    Label(
                        String(localized: "No profiles yet", comment: "Empty profile list"),
                        systemImage: "person.crop.circle.badge.plus"
                    )
                } description: {
                    Text(
                        "Add a profile for each child. Every profile has its own tiles, colours and screen time.",
                        comment: "Empty profile list description"
                    )
                }
            }
        }
        .sheet(item: $editingProfile) { profile in
            NavigationStack {
                ProfileEditorView(profile: profile)
            }
        }
        .sheet(isPresented: $isCreatingProfile) {
            NavigationStack {
                ProfileEditorView(profile: nil)
            }
        }
        .proLimitPrompt($limitMessage)
        .confirmationDialog(
            Text("Delete this profile?", comment: "Profile deletion confirmation"),
            isPresented: Binding(
                get: { profilePendingDeletion != nil },
                set: { if !$0 { profilePendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                if let profile = profilePendingDeletion {
                    delete(profile)
                }
                profilePendingDeletion = nil
            } label: {
                Text("Delete", comment: "Confirm deletion")
            }
            Button(role: .cancel) {
                profilePendingDeletion = nil
            } label: {
                Text("Cancel", comment: "Cancel deletion")
            }
        } message: {
            Text(
                "The tiles of this profile move to the trash and can be restored for 14 days.",
                comment: "Profile deletion explanation"
            )
        }
    }

    private func tileCount(for profile: ChildProfile) -> Int {
        tiles.filter { $0.ownerProfileID == profile.id && !$0.isTrashed }.count
    }

    private func addProfile() {
        guard ProGate.canAdd(.profiles, currentCount: profiles.count, isPro: store.isPro) else {
            limitMessage = ProGate.limitMessage(for: .profiles, isPro: store.isPro)
            return
        }
        isCreatingProfile = true
    }

    private func moveProfiles(from source: IndexSet, to destination: Int) {
        var reordered = profiles
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, profile) in reordered.enumerated() where profile.sortOrder != index {
            profile.sortOrder = index
            profile.lastModified = Date()
        }
        ModelSaver.save(modelContext, describing: "reordering profiles")
    }

    private func requestDeletion(at offsets: IndexSet) {
        guard let index = offsets.first, profiles.indices.contains(index) else { return }
        profilePendingDeletion = profiles[index]
    }

    private func delete(_ profile: ChildProfile) {
        // The profile's tiles go to the trash rather than disappearing at once,
        // so the parent has the same 14-day safety net as for a single tile.
        for tile in tiles where tile.ownerProfileID == profile.id && !tile.isTrashed {
            tile.moveToTrash()
        }
        // Stop other profiles from pointing at tiles that are now in the trash.
        for other in profiles where other.id != profile.id {
            let removed = other.visibleSharedTileIDs.filter { sharedID in
                !tiles.contains { $0.id == sharedID && $0.ownerProfileID == profile.id }
            }
            if removed.count != other.visibleSharedTileIDs.count {
                other.visibleSharedTileIDs = removed
                other.lastModified = Date()
            }
        }
        modelContext.delete(profile)
        ModelSaver.save(modelContext, describing: "deleting a profile")
    }
}

private struct ProfileRow: View {
    let profile: ChildProfile
    let tileCount: Int

    var body: some View {
        HStack(spacing: 14) {
            ProfileAvatarView(profile: profile, diameter: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(
                    "\(tileCount) tiles",
                    comment: "Profile row subtitle: tile count"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
