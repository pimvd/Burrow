import Foundation

/// Turns whatever the parent pastes — a full watch URL, a share link, a
/// `youtu.be` short link or a bare ID — into a YouTube video identifier.
enum YouTubeLink {
    /// YouTube identifiers are 11 characters from an unreserved alphabet.
    private static let allowedCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
    )

    static func videoID(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if isValidIdentifier(trimmed) {
            return trimmed
        }

        guard let components = URLComponents(string: trimmed) else { return nil }

        if let queryID = components.queryItems?.first(where: { $0.name == "v" })?.value,
           isValidIdentifier(queryID) {
            return queryID
        }

        // youtu.be/<id>, youtube.com/embed/<id>, youtube.com/shorts/<id>, /live/<id>
        let pathComponents = components.path.split(separator: "/").map(String.init)
        if let last = pathComponents.last, isValidIdentifier(last) {
            return last
        }

        return nil
    }

    static func isValidIdentifier(_ candidate: String) -> Bool {
        guard candidate.count == 11 else { return false }
        return candidate.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
    }

    // MARK: - The hosted player page

    /// Where the player shell lives. It is served from Burrow's own domain
    /// rather than built inside the app because YouTube's embedded player
    /// identifies its host through the HTTP `Referer` header, and only a page
    /// loaded from a real origin sends one.
    ///
    /// Source: `website/player.html`. Republish after editing, and raise
    /// ``playerPageVersion`` so devices do not keep serving a cached copy.
    static let playerPageURL = "https://vandijkcloud.nl/burrow/player.html"

    /// Bumped whenever `website/player.html` changes.
    static let playerPageVersion = 1

    /// The address to load for one video.
    ///
    /// The identifier goes in the fragment, which is never sent to the server,
    /// so no web server log records which video a child watched.
    static func playerURL(videoID: String) -> URL? {
        guard isValidIdentifier(videoID) else { return nil }
        var components = URLComponents(string: playerPageURL)
        components?.queryItems = [URLQueryItem(name: "v", value: String(playerPageVersion))]
        components?.fragment = videoID
        return components?.url
    }
}
