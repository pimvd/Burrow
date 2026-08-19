import Foundation
import Testing
@testable import Burrow

@Suite("Hosted player address")
struct YouTubePlayerURLTests {
    @Test("A valid identifier produces an address on Burrow's own domain")
    func buildsHostedURL() throws {
        let url = try #require(YouTubeLink.playerURL(videoID: "dQw4w9WgXcQ"))
        let hosted = try #require(URL(string: YouTubeLink.playerPageURL))
        #expect(url.scheme == "https")
        #expect(url.host == hosted.host)
        #expect(url.path == hosted.path)
    }

    @Test("The identifier travels in the fragment, never in the path or query")
    func identifierStaysInTheFragment() throws {
        let url = try #require(YouTubeLink.playerURL(videoID: "dQw4w9WgXcQ"))
        #expect(url.fragment == "dQw4w9WgXcQ")
        #expect(!url.path.contains("dQw4w9WgXcQ"))
        #expect(url.query?.contains("dQw4w9WgXcQ") != true)
    }

    @Test("The address carries the page version, so a cached shell is replaced")
    func carriesVersion() throws {
        let url = try #require(YouTubeLink.playerURL(videoID: "dQw4w9WgXcQ"))
        let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(query.contains(URLQueryItem(name: "v", value: String(YouTubeLink.playerPageVersion))))
    }

    @Test("Anything that is not a YouTube identifier gets no address at all")
    func rejectsNonIdentifiers() {
        #expect(YouTubeLink.playerURL(videoID: "") == nil)
        #expect(YouTubeLink.playerURL(videoID: "short") == nil)
        #expect(YouTubeLink.playerURL(videoID: "waytoolongtobeanid") == nil)
        // Eleven characters, but not from the identifier alphabet.
        #expect(YouTubeLink.playerURL(videoID: "abc#def/ghi") == nil)
        #expect(YouTubeLink.playerURL(videoID: "../../etc/p") == nil)
    }

    @Test("The page version is a positive number that can be raised")
    func versionIsUsable() {
        #expect(YouTubeLink.playerPageVersion >= 1)
    }
}
