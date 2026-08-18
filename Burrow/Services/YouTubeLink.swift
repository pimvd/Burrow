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
}
