import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Makes a full backup package, or reads one back in.
struct ExportImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CloudSyncStatus.self) private var cloudSync

    @Query(sort: \ChildProfile.sortOrder) private var profiles: [ChildProfile]
    @Query private var tiles: [Tile]

    @State private var exportEverything = true
    @State private var selectedProfileID: UUID?
    @State private var exportedArchiveURL: URL?
    @State private var isExporting = false

    @State private var isShowingFileImporter = false
    @State private var pendingImport: PendingImport?
    @State private var isChoosingStrategy = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    private struct PendingImport {
        let package: ExportPackage
        let unpackedRoot: URL
        let preview: ExportImportService.ImportPreview
    }

    private var hasExistingContent: Bool {
        !profiles.isEmpty || tiles.contains { !$0.isTrashed }
    }

    var body: some View {
        List {
            Section {
                LabeledContent {
                    Text(cloudSyncDescription)
                        .foregroundStyle(.secondary)
                } label: {
                    Label(
                        String(localized: "iCloud sync", comment: "Cloud status row"),
                        systemImage: cloudSyncSymbol
                    )
                }

                if let lastSyncDate = cloudSync.lastSyncDate {
                    LabeledContent {
                        Text(lastSyncDate, format: .relative(presentation: .named))
                            .foregroundStyle(.secondary)
                    } label: {
                        Text("Last change synced", comment: "Cloud last sync row")
                    }
                }
            } header: {
                Text("iCloud", comment: "Cloud section")
            } footer: {
                Text(
                    "Profiles, tiles and playlists sync to your own iCloud automatically. The audio, video and pictures you added yourself do not: those travel in the iPhone's own iCloud backup, or in a Burrow backup file.",
                    comment: "Cloud explanation"
                )
            }

            Section {
                Toggle(isOn: $exportEverything) {
                    Text("Everything", comment: "Export scope toggle")
                }

                if !exportEverything {
                    Picker(selection: $selectedProfileID) {
                        ForEach(profiles) { profile in
                            Text(profile.name).tag(Optional(profile.id))
                        }
                    } label: {
                        Text("Profile", comment: "Export scope profile picker")
                    }
                }

                Button {
                    runExport()
                } label: {
                    HStack {
                        Label(
                            String(localized: "Create backup", comment: "Export button"),
                            systemImage: "square.and.arrow.up"
                        )
                        if isExporting {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isExporting || (!exportEverything && selectedProfileID == nil))

                if let exportedArchiveURL {
                    ShareLink(item: exportedArchiveURL) {
                        Label(
                            String(localized: "Share backup", comment: "Share the exported archive"),
                            systemImage: "square.and.arrow.up.on.square"
                        )
                    }
                }
            } header: {
                Text("Export", comment: "Export section")
            } footer: {
                Text(
                    "A backup is a zip file with all details plus the audio, video and pictures you added yourself. Every export is a complete copy.",
                    comment: "Export explanation"
                )
            }

            Section {
                Button {
                    isShowingFileImporter = true
                } label: {
                    Label(
                        String(localized: "Read a backup", comment: "Import button"),
                        systemImage: "square.and.arrow.down"
                    )
                }
            } header: {
                Text("Import", comment: "Import section")
            } footer: {
                Text(
                    "On a new iPhone, sign in with the same Apple Account and open Burrow: profiles, tiles and playlists come back on their own. Read a backup file to bring back the audio, video and pictures too, or to move everything to a different Apple Account. If profiles or tiles already exist, you choose whether to merge them or replace everything.",
                    comment: "Import explanation"
                )
            }

            if let statusMessage {
                Section {
                    Label(statusMessage, systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(Text("Export and import", comment: "Export/import title"))
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.zip],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .confirmationDialog(
            Text("There is already content on this device", comment: "Import conflict title"),
            isPresented: $isChoosingStrategy,
            titleVisibility: .visible
        ) {
            Button {
                apply(.merge)
            } label: {
                Text("Merge", comment: "Import strategy")
            }

            Button(role: .destructive) {
                apply(.replace)
            } label: {
                Text("Replace everything", comment: "Import strategy")
            }

            Button(role: .cancel) {
                cancelImport()
            } label: {
                Text("Cancel", comment: "Import strategy")
            }
        } message: {
            if let pendingImport {
                Text(
                    "This backup holds \(pendingImport.preview.profileCount) profiles and \(pendingImport.preview.tileCount) tiles. Merging adds what is missing; replacing removes everything that is here now.",
                    comment: "Import conflict explanation"
                )
            }
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
        .onAppear {
            if selectedProfileID == nil {
                selectedProfileID = profiles.first?.id
            }
        }
        .task {
            await cloudSync.refresh()
        }
    }

    // MARK: - iCloud

    private var cloudSyncDescription: String {
        switch cloudSync.state {
        case .synced:
            return String(localized: "On", comment: "Cloud state")
        case .waiting:
            return String(localized: "Starting up", comment: "Cloud state")
        case .failed:
            return String(localized: "Last attempt failed", comment: "Cloud state")
        case .noAccount:
            return String(localized: "Not signed in to iCloud", comment: "Cloud state")
        case .localOnly:
            return String(localized: "Off, this iPhone only", comment: "Cloud state")
        }
    }

    private var cloudSyncSymbol: String {
        switch cloudSync.state {
        case .synced:
            return "checkmark.icloud"
        case .waiting:
            return "arrow.triangle.2.circlepath.icloud"
        case .failed:
            return "exclamationmark.icloud"
        case .noAccount, .localOnly:
            return "icloud.slash"
        }
    }

    // MARK: - Export

    private func runExport() {
        isExporting = true
        statusMessage = nil
        exportedArchiveURL = nil

        let scope: ExportImportService.Scope
        if exportEverything {
            scope = .everything
        } else if let selectedProfileID {
            scope = .profile(selectedProfileID)
        } else {
            isExporting = false
            return
        }

        do {
            let url = try ExportImportService.export(scope: scope, context: modelContext)
            exportedArchiveURL = url
            statusMessage = String(
                localized: "Backup created.",
                comment: "Export success"
            )
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isExporting = false
    }

    // MARK: - Import

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let inspected = try ExportImportService.inspect(archiveAt: url)
                pendingImport = PendingImport(
                    package: inspected.package,
                    unpackedRoot: inspected.unpackedRoot,
                    preview: inspected.preview
                )
                if hasExistingContent {
                    isChoosingStrategy = true
                } else {
                    apply(.merge)
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ strategy: ExportImportService.ImportStrategy) {
        guard let pendingImport else { return }
        self.pendingImport = nil
        isChoosingStrategy = false

        do {
            try ExportImportService.apply(
                package: pendingImport.package,
                unpackedRoot: pendingImport.unpackedRoot,
                strategy: strategy,
                context: modelContext
            )
            statusMessage = String(
                localized: "Backup read successfully.",
                comment: "Import success"
            )
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func cancelImport() {
        if let pendingImport {
            try? FileManager.default.removeItem(at: pendingImport.unpackedRoot)
        }
        pendingImport = nil
        isChoosingStrategy = false
    }
}
