import Foundation
import Testing
@testable import Burrow

@Suite("Playlist links")
struct PlaylistLinkTests {
    private func link(_ string: String) -> PlaylistLink? {
        URL(string: string).flatMap(PlaylistLink.init(url:))
    }

    @Test("A hand-written link reads")
    func handWritten() throws {
        let parsed = try #require(link(
            "burrow://playlist?name=Bedtime&type=music&item=yt:dQw4w9WgXcQ:Twinkle%20Twinkle&item=am:1440833098"
        ))
        #expect(parsed.title == "Bedtime")
        #expect(parsed.category == .music)
        #expect(parsed.items == [
            .init(type: .youtube, identifier: "dQw4w9WgXcQ", title: "Twinkle Twinkle"),
            .init(type: .appleMusic, identifier: "1440833098", title: nil)
        ])
    }

    @Test("A shared link reads back exactly, whatever is in the titles")
    func roundTrip() throws {
        let original = PlaylistLink(
            title: "Rock & Roll = fun + songs?",
            category: .music,
            items: [
                .init(type: .youtube, identifier: "dQw4w9WgXcQ", title: "Part 1: the start & 50% more"),
                .init(type: .appleMusic, identifier: "1440833098", title: "Ünïcødé 🎵")
            ]
        )
        let parsed = try #require(PlaylistLink(url: original.url))
        #expect(parsed == original)
    }

    @Test("Other links are not playlist links")
    func otherLinks() {
        #expect(link("https://playlist?type=music&item=yt:dQw4w9WgXcQ") == nil)
        #expect(link("burrow://settings?type=music&item=yt:dQw4w9WgXcQ") == nil)
        #expect(link("burrow://playlist?item=yt:dQw4w9WgXcQ") == nil)
    }

    @Test("Unreadable items are left out, and a link of only those is refused")
    func badItems() throws {
        let parsed = try #require(link(
            "burrow://playlist?type=music&item=yt:short&item=xx:dQw4w9WgXcQ&item=am:12ab&item=yt:dQw4w9WgXcQ"
        ))
        #expect(parsed.items.map(\.identifier) == ["dQw4w9WgXcQ"])
        #expect(link("burrow://playlist?type=music&item=yt:short") == nil)
    }

    @Test("A video tile does not take Apple Music songs")
    func categoryFilter() throws {
        let parsed = try #require(link(
            "burrow://playlist?type=video&item=am:1440833098&item=yt:dQw4w9WgXcQ"
        ))
        #expect(parsed.items.map(\.type) == [.youtube])
    }

    @Test("A link carries one full playlist at most")
    func cappedLength() throws {
        let items = Array(repeating: "item=yt:dQw4w9WgXcQ", count: PlaylistLink.maximumItems + 10)
        let parsed = try #require(link("burrow://playlist?type=video&" + items.joined(separator: "&")))
        #expect(parsed.items.count == PlaylistLink.maximumItems)
    }

    @Test("Items without a title are named after the playlist")
    func fallbackTitles() throws {
        let parsed = try #require(link("burrow://playlist?name=Car&type=video&item=yt:dQw4w9WgXcQ"))
        #expect(parsed.displayTitle(of: parsed.items[0], at: 0) == "Car 1")
    }
}
