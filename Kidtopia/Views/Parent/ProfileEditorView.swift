import SwiftData
import SwiftUI

/// Creates a new profile or edits an existing one.
///
/// Edits are kept in local state until the parent taps Save, which makes it
/// possible to detect an iCloud change that arrived while the sheet was open.
struct ProfileEditorView: View {
    /// `nil` creates a new profile.
    let profile: ChildProfile?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ChildProfile.sortOrder) private var allProfiles: [ChildProfile]
    @Query private var allTiles: [Tile]

    @State private var name = ""
    @State private var avatarIconName = AvatarCatalog.fallbackIdentifier
    @State private var colorThemeName = ThemePalette.fallbackIdentifier
    @State private var ageYears = 5.0
    @State private var hasScreenTimeLimit = false
    @State private var screenTimeLimitMinutes = 30
    @State private var lockScreenPlaybackEnabled = true
    @State private var visibleSharedTileIDs: Set<UUID> = []

    @State private var conflictGuard: EditConflictGuard?
    @State private var isShowingConflict = false
    @State private var saveErrorMessage: String?

    private var isNew: Bool { profile == nil }

    private var screenTimeOptions: [Int] { [15, 30, 45, 60, 90] }

    /// Tiles owned by other profiles, which this profile may be given access to.
    private var shareableTiles: [Tile] {
        allTiles
            .filter { !$0.isTrashed && $0.ownerProfileID != profile?.id }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        Form {
            Section {
                TextField(
                    String(localized: "Name", comment: "Profile name field"),
                    text: $name
                )
                .textInputAutocapitalization(.words)
            } header: {
                Text("Name", comment: "Profile editor section")
            }

            Section {
                AvatarPickerGrid(selection: $avatarIconName, tint: ThemePalette.palette(named: colorThemeName).tint)
            } header: {
                Text("Avatar", comment: "Profile editor section")
            }

            Section {
                ThemePickerRow(selection: $colorThemeName)
            } header: {
                Text("Colour", comment: "Profile editor section")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent {
                        Text("\(Int(ageYears))")
                            .monospacedDigit()
                    } label: {
                        Text("Age", comment: "Profile age slider label")
                    }

                    Slider(
                        value: $ageYears,
                        in: Double(AgeLayoutScale.minimumAge)...Double(AgeLayoutScale.maximumAge),
                        step: 1
                    ) {
                        Text("Age", comment: "Profile age slider accessibility label")
                    }
                }
            } header: {
                Text("Age", comment: "Profile editor section")
            } footer: {
                Text(
                    "The age sets how large the tiles are, whether captions are shown and whether there are next and previous buttons during playback.",
                    comment: "Age slider explanation"
                )
            }

            Section {
                Toggle(isOn: $hasScreenTimeLimit) {
                    Text("Limit session length", comment: "Screen time toggle")
                }

                if hasScreenTimeLimit {
                    Picker(selection: $screenTimeLimitMinutes) {
                        ForEach(screenTimeOptions, id: \.self) { minutes in
                            Text("\(minutes) minutes", comment: "Screen time option").tag(minutes)
                        }
                    } label: {
                        Text("Session length", comment: "Screen time picker label")
                    }
                }

                Toggle(isOn: $lockScreenPlaybackEnabled) {
                    Text("Keep playing on the lock screen", comment: "Lock screen playback toggle")
                }
            } header: {
                Text("Screen time and playback", comment: "Profile editor section")
            } footer: {
                Text(
                    "When the session is over, playback stops and Kidtopia returns to the profile picker.",
                    comment: "Screen time explanation"
                )
            }

            if !shareableTiles.isEmpty {
                Section {
                    ForEach(shareableTiles) { tile in
                        Toggle(isOn: sharingBinding(for: tile)) {
                            HStack(spacing: 10) {
                                Image(systemName: tile.category.symbolName)
                                    .foregroundStyle(.secondary)
                                Text(tile.title)
                            }
                        }
                    }
                } header: {
                    Text("Shared tiles", comment: "Profile editor section")
                } footer: {
                    Text(
                        "Pick which tiles from other profiles this child can see. Their settings stay the same everywhere.",
                        comment: "Tile sharing explanation"
                    )
                }
            }
        }
        .navigationTitle(
            isNew
                ? Text("New profile", comment: "Profile editor title, creating")
                : Text("Edit profile", comment: "Profile editor title, editing")
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
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
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .conflictResolutionDialog(
            isPresented: $isShowingConflict,
            recordName: profile?.name ?? name
        ) { resolution in
            resolve(resolution)
        }
        .alert(
            Text("Could not save", comment: "Save failure alert title"),
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )
        ) {
            Button(role: .cancel) {
                saveErrorMessage = nil
            } label: {
                Text("OK", comment: "Alert dismiss")
            }
        } message: {
            Text(saveErrorMessage ?? "")
        }
        .onAppear(perform: loadInitialValues)
    }

    private func sharingBinding(for tile: Tile) -> Binding<Bool> {
        Binding(
            get: { visibleSharedTileIDs.contains(tile.id) },
            set: { isOn in
                if isOn {
                    visibleSharedTileIDs.insert(tile.id)
                } else {
                    visibleSharedTileIDs.remove(tile.id)
                }
            }
        )
    }

    private func loadInitialValues() {
        guard let profile else {
            conflictGuard = nil
            return
        }
        name = profile.name
        avatarIconName = profile.avatarIconName
        colorThemeName = profile.colorThemeName
        ageYears = Double(profile.ageYears)
        hasScreenTimeLimit = profile.dailyScreenTimeLimitMinutes != nil
        screenTimeLimitMinutes = profile.dailyScreenTimeLimitMinutes ?? 30
        lockScreenPlaybackEnabled = profile.lockScreenPlaybackEnabled
        visibleSharedTileIDs = Set(profile.visibleSharedTileIDs)
        conflictGuard = EditConflictGuard(expectedLastModified: profile.lastModified)
    }

    private func attemptSave() {
        if let profile,
           let conflictGuard,
           conflictGuard.hasConflict(currentLastModified: profile.lastModified) {
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
            // Drop the local edits and show what the other device stored.
            loadInitialValues()
        case .cancel:
            break
        }
    }

    private func commit() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let target: ChildProfile
        if let profile {
            target = profile
        } else {
            let nextOrder = (allProfiles.map(\.sortOrder).max() ?? -1) + 1
            let created = ChildProfile(name: trimmedName, sortOrder: nextOrder)
            modelContext.insert(created)
            target = created
        }

        target.name = trimmedName
        target.avatarIconName = avatarIconName
        target.colorThemeName = colorThemeName
        target.ageYears = Int(ageYears)
        target.dailyScreenTimeLimitMinutes = hasScreenTimeLimit ? screenTimeLimitMinutes : nil
        target.lockScreenPlaybackEnabled = lockScreenPlaybackEnabled
        target.visibleSharedTileIDs = Array(visibleSharedTileIDs)
        target.lastModified = Date()

        if let error = ModelSaver.save(modelContext, describing: "saving a profile") {
            saveErrorMessage = error.localizedDescription
            return
        }
        dismiss()
    }
}

// MARK: - Pickers

private struct AvatarPickerGrid: View {
    @Binding var selection: String
    let tint: Color

    private let columns = [GridItem(.adaptive(minimum: 56), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(AvatarCatalog.all) { avatar in
                Button {
                    selection = avatar.id
                } label: {
                    Image(systemName: avatar.symbolName)
                        .font(.system(size: 24))
                        .frame(width: 52, height: 52)
                        .foregroundStyle(selection == avatar.id ? Color.white : tint)
                        .background(
                            Circle().fill(selection == avatar.id ? tint : tint.opacity(0.15))
                        )
                }
                .buttonStyle(.calm)
                .accessibilityLabel(Text(avatar.displayName))
                .accessibilityAddTraits(selection == avatar.id ? [.isSelected] : [])
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ThemePickerRow: View {
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(ThemePalette.all) { palette in
                    Button {
                        selection = palette.id
                    } label: {
                        Circle()
                            .fill(palette.tint)
                            .frame(width: 40, height: 40)
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.primary.opacity(selection == palette.id ? 0.6 : 0), lineWidth: 3)
                                    .padding(-4)
                            }
                    }
                    .buttonStyle(.calm)
                    .accessibilityLabel(Text(palette.displayName))
                    .accessibilityAddTraits(selection == palette.id ? [.isSelected] : [])
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 2)
        }
    }
}
