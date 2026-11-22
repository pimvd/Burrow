import Foundation

/// A whole playlist carried inside a link, the way a magnet link carries a
/// download: nothing is fetched from anywhere, the link itself is the content.
///
///     burrow://playlist?name=Bedtime&type=music
///         &item=yt:dQw4w9WgXcQ:Twinkle%20Twinkle
///         &item=am:1440833098
///
/// Each `item` is `kind:id`, optionally followed by `:title`. The kinds are
/// `yt` for a YouTube video and `am` for an Apple Music song. Files from the
/// device cannot travel this way, so a link only ever holds streamed items.
///
/// A link may also name the tile's picture: `icon` is one of the icons a
/// parent can pick in the app (`TileArtwork.icons`) and `color` one of the
/// colour themes (`ThemePalette`), e.g. `&icon=moon.stars.fill&color=sage`.
/// Anything else is ignored, and the tile gets the plain picture.
///
/// The format is meant to be writable by hand, so parsing is forgiving: an item
/// it cannot read, or one that does not fit the tile type, is left out rather
/// than failing the whole link.
struct PlaylistLink: Hashable, Sendable {
    struct Item: Hashable, Sendable {
        var type: MediaSourceType
        /// A YouTube video ID or an Apple Music catalog ID.
        var identifier: String
        var title: String?
    }

    static let scheme = "burrow"
    private static let host = "playlist"

    /// The most a link may carry: a full playlist, and no more.
    static let maximumItems = ProGate.Limit.mediaItemsPerTile.maximum(hasFullAccess: true)
    private static let maximumTitleLength = 100

    var title: String
    var category: TileCategory
    var items: [Item]
    /// One of `TileArtwork.icons`, by its symbol name.
    var icon: String?
    /// One of `ThemePalette.all`, by its identifier.
    var color: String?

    init(title: String, category: TileCategory, items: [Item], icon: String? = nil, color: String? = nil) {
        self.title = title
        self.category = category
        self.items = items
        self.icon = icon.flatMap { name in TileArtwork.icons.contains { $0.id == name } ? name : nil }
        self.color = color.flatMap { name in ThemePalette.all.contains { $0.id == name } ? name : nil }
    }

    /// The shareable part of a tile. `nil` when nothing in it can travel in a
    /// link, which is the case for a tile of device files only.
    init?(title: String, category: TileCategory, mediaItems: [MediaItem]) {
        let items: [Item] = mediaItems.compactMap { mediaItem in
            switch mediaItem.type {
            case .youtube:
                guard let id = mediaItem.youtubeVideoID, !id.isEmpty else { return nil }
                return Item(type: .youtube, identifier: id, title: mediaItem.title)
            case .appleMusic:
                guard let id = mediaItem.appleMusicItemID, !id.isEmpty else { return nil }
                return Item(type: .appleMusic, identifier: id, title: mediaItem.title)
            case .localAudio, .localVideo:
                return nil
            }
        }
        guard !items.isEmpty else { return nil }
        self.init(title: title, category: category, items: items)
    }

    /// Reads a link. `nil` when it is not a Burrow playlist link at all, or when
    /// not a single item in it could be used.
    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme,
              url.host()?.lowercased() == Self.host,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let query = components.queryItems ?? []

        guard let typeValue = query.first(where: { $0.name == "type" })?.value,
              let category = TileCategory(rawValue: typeValue.lowercased()) else {
            return nil
        }

        let items = query
            .filter { $0.name == "item" }
            .compactMap { $0.value.flatMap(Self.item(from:)) }
            .filter { category.allows($0.type) }
            .prefix(Self.maximumItems)
        guard !items.isEmpty else { return nil }

        let name = query.first(where: { $0.name == "name" })?.value ?? ""
        self.init(
            title: Self.clean(name) ?? category.localizedTitle,
            category: category,
            items: Array(items),
            icon: query.first(where: { $0.name == "icon" })?.value,
            color: query.first(where: { $0.name == "color" })?.value?.lowercased()
        )
    }

    /// The link to share.
    var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.host
        var pairs = [("name", title), ("type", category.rawValue)]
        if let icon { pairs.append(("icon", icon)) }
        if let color { pairs.append(("color", color)) }
        pairs += items.map { item in
            var value = "\(Self.code(for: item.type)):\(item.identifier)"
            if let title = item.title, !title.isEmpty {
                value += ":\(title)"
            }
            return ("item", value)
        }
        // Escaped by hand: `URLComponents` leaves `&`, `=` and `+` in a value
        // alone, and each of those would change what the link means.
        components.percentEncodedQueryItems = pairs.map { name, value in
            URLQueryItem(
                name: name,
                value: value.addingPercentEncoding(withAllowedCharacters: Self.unescapedCharacters)
            )
        }
        // Every component is set from known-good values, so this cannot fail.
        return components.url!
    }

    /// Letters, digits, the four unreserved marks, and the colon that
    /// separates an item's parts.
    private static let unescapedCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~:"
    )

    /// The title an item gets in the playlist: its own, or the playlist title
    /// and its position when the link did not name it.
    func displayTitle(of item: Item, at index: Int) -> String {
        item.title ?? "\(title) \(index + 1)"
    }

    // MARK: - Items

    private static func code(for type: MediaSourceType) -> String {
        type == .youtube ? "yt" : "am"
    }

    private static func item(from value: String) -> Item? {
        // The title may itself contain colons, so only the first two split.
        let parts = value.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return nil }
        let identifier = String(parts[1])
        let title = parts.count == 3 ? clean(String(parts[2])) : nil

        switch parts[0].lowercased() {
        case "yt":
            guard YouTubeLink.isValidIdentifier(identifier) else { return nil }
            return Item(type: .youtube, identifier: identifier, title: title)
        case "am":
            guard isValidAppleMusicIdentifier(identifier) else { return nil }
            return Item(type: .appleMusic, identifier: identifier, title: title)
        default:
            return nil
        }
    }

    /// Apple Music catalog IDs are plain numbers.
    private static func isValidAppleMusicIdentifier(_ candidate: String) -> Bool {
        !candidate.isEmpty && candidate.count <= 20 && candidate.allSatisfy(\.isASCII) && candidate.allSatisfy(\.isNumber)
    }

    /// Trims a title and keeps it to a sensible length. `nil` when nothing is
    /// left.
    private static func clean(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maximumTitleLength))
    }
}
