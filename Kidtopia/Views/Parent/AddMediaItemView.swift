import SwiftUI
import UniformTypeIdentifiers

/// Adds one playlist entry. Only the source types that fit the tile's category
/// are offered, so a music tile can never end up with a video in it.
struct AddMediaItemView: View {
    let category: TileCategory
    let onAdd: (MediaItem) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var sourceType: MediaSourceType
    @State private var title = ""
    @State private var youtubeInput = ""
    @State private var importedFileName: String?
    @State private var isShowingFileImporter = false
    @State private var appleMusicSelection: AppleMusicService.SongSearchResult?
    @State private var errorMessage: String?

    init(category: TileCategory, onAdd: @escaping (MediaItem) -> Void) {
        self.category = category
        self.onAdd = onAdd
        _sourceType = State(initialValue: category.allowedSourceTypes[0])
    }

    private var allowedContentTypes: [UTType] {
        switch sourceType {
        case .localAudio: return [.audio, .mp3, .mpeg4Audio]
        case .localVideo: return [.movie, .mpeg4Movie, .video]
        case .appleMusic, .youtube: return []
        }
    }

    private var canAdd: Bool {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        switch sourceType {
        case .localAudio, .localVideo:
            return importedFileName != nil
        case .youtube:
            return YouTubeLink.videoID(from: youtubeInput) != nil
        case .appleMusic:
            return appleMusicSelection != nil
        }
    }

    var body: some View {
        Form {
            Section {
                Picker(selection: $sourceType) {
                    ForEach(category.allowedSourceTypes) { type in
                        Label(type.localizedTitle, systemImage: type.symbolName)
                            .tag(type)
                    }
                } label: {
                    Text("Source", comment: "Media item source picker")
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Where does it come from?", comment: "Media item section")
            }

            switch sourceType {
            case .localAudio, .localVideo:
                localFileSection
            case .youtube:
                youtubeSection
            case .appleMusic:
                appleMusicSection
            }

            Section {
                TextField(
                    String(localized: "Title", comment: "Media item title field"),
                    text: $title
                )
                .textInputAutocapitalization(.sentences)
            } header: {
                Text("Title", comment: "Media item section")
            } footer: {
                Text(
                    "This title is only shown to you and during playback.",
                    comment: "Media item title explanation"
                )
            }
        }
        .navigationTitle(Text("Add item", comment: "Add media item title"))
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
                    add()
                } label: {
                    Text("Add", comment: "Confirm adding a media item")
                }
                .disabled(!canAdd)
            }
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
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
        .onChange(of: sourceType) { _, _ in
            resetSourceSpecificState()
        }
    }

    // MARK: - Sections

    private var localFileSection: some View {
        Section {
            Button {
                isShowingFileImporter = true
            } label: {
                Label(
                    importedFileName == nil
                        ? String(localized: "Choose a file", comment: "File picker button")
                        : String(localized: "Choose another file", comment: "File picker button"),
                    systemImage: "folder"
                )
            }

            if importedFileName != nil {
                Label(
                    String(localized: "File added", comment: "File import confirmation"),
                    systemImage: "checkmark.circle"
                )
                .foregroundStyle(.secondary)
            }
        } header: {
            Text("File", comment: "Media item section")
        } footer: {
            Text(
                "The file is copied into Kidtopia, so it keeps playing without an internet connection.",
                comment: "Local file explanation"
            )
        }
    }

    private var youtubeSection: some View {
        Section {
            TextField(
                String(localized: "YouTube link", comment: "YouTube link field"),
                text: $youtubeInput
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)

            if !youtubeInput.isEmpty && YouTubeLink.videoID(from: youtubeInput) == nil {
                Label(
                    String(localized: "This does not look like a YouTube link.", comment: "YouTube link validation"),
                    systemImage: "exclamationmark.triangle"
                )
                .foregroundStyle(.orange)
                .font(.callout)
            }
        } header: {
            Text("Link", comment: "Media item section")
        } footer: {
            Text(
                "Paste the link to the video. Kidtopia plays it without recommendations or comments around it.",
                comment: "YouTube explanation"
            )
        }
    }

    private var appleMusicSection: some View {
        Section {
            AppleMusicSearchView(selection: $appleMusicSelection) { result in
                if title.trimmingCharacters(in: .whitespaces).isEmpty {
                    title = result.title
                }
            }
        } header: {
            Text("Apple Music", comment: "Media item section")
        } footer: {
            Text(
                "Playing Apple Music needs an active subscription on this device.",
                comment: "Apple Music explanation"
            )
        }
    }

    // MARK: - Actions

    private func resetSourceSpecificState() {
        if let importedFileName {
            MediaLibrary.shared.deleteFile(named: importedFileName)
        }
        importedFileName = nil
        youtubeInput = ""
        appleMusicSelection = nil
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                if let previous = importedFileName {
                    MediaLibrary.shared.deleteFile(named: previous)
                }
                let storedName = try MediaLibrary.shared.importFile(from: url)
                importedFileName = storedName
                if title.trimmingCharacters(in: .whitespaces).isEmpty {
                    title = url.deletingPathExtension().lastPathComponent
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func add() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let item: MediaItem

        switch sourceType {
        case .localAudio, .localVideo:
            guard let fileName = importedFileName else { return }
            item = MediaItem(type: sourceType, title: trimmedTitle, localFileName: fileName)
        case .youtube:
            guard let videoID = YouTubeLink.videoID(from: youtubeInput) else { return }
            item = MediaItem(type: .youtube, title: trimmedTitle, youtubeVideoID: videoID)
        case .appleMusic:
            guard let selection = appleMusicSelection else { return }
            item = MediaItem(type: .appleMusic, title: trimmedTitle, appleMusicItemID: selection.id)
        }

        // Hand over ownership of the imported file to the new item.
        importedFileName = nil
        onAdd(item)
        dismiss()
    }

    private func cancel() {
        // A file that was imported but never confirmed should not linger.
        if let importedFileName {
            MediaLibrary.shared.deleteFile(named: importedFileName)
        }
        importedFileName = nil
        dismiss()
    }
}

// MARK: - Apple Music search

private struct AppleMusicSearchView: View {
    @Binding var selection: AppleMusicService.SongSearchResult?
    let onSelect: (AppleMusicService.SongSearchResult) -> Void

    @State private var searchTerm = ""
    @State private var results: [AppleMusicService.SongSearchResult] = []
    @State private var isSearching = false
    @State private var message: String?

    var body: some View {
        TextField(
            String(localized: "Search for a song", comment: "Apple Music search field"),
            text: $searchTerm
        )
        .textInputAutocapitalization(.words)
        .onSubmit { search() }

        Button {
            search()
        } label: {
            Label(
                String(localized: "Search", comment: "Apple Music search button"),
                systemImage: "magnifyingglass"
            )
        }
        .disabled(searchTerm.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)

        if isSearching {
            ProgressView()
                .frame(maxWidth: .infinity)
        }

        if let message {
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
        }

        ForEach(results) { result in
            Button {
                selection = result
                onSelect(result)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.title)
                            .foregroundStyle(.primary)
                        Text(result.artistName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if selection?.id == result.id {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func search() {
        let term = searchTerm
        isSearching = true
        message = nil

        Task {
            defer { isSearching = false }
            do {
                let found = try await AppleMusicService.shared.searchSongs(term: term)
                results = found
                if found.isEmpty {
                    message = String(
                        localized: "Nothing found.",
                        comment: "Apple Music empty search result"
                    )
                }
            } catch {
                results = []
                message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
