import Foundation
import SwiftData
import UIKit

/// The App Store screenshots, taken by `Scripts/screenshots.sh` in the simulator.
///
/// The script launches the app with `-screenshotScene <scene>`, which iOS hands
/// to the app as a user default. The app then opens an in-memory store filled
/// with made-up children, tiles and play history, and goes straight to that
/// scene. Nothing is read from or written to the parent's real data or iCloud,
/// and without the argument none of this runs.
///
/// The language comes from `-AppleLanguages`, so the same scenes are taken once
/// per App Store locale, with the demo titles below in that language.
enum ScreenshotMode {
    enum Scene: String, CaseIterable {
        case profiles
        case music
        case video
        case games
        case game
        case tiles
        case statistics
    }

    static let scene: Scene? = UserDefaults.standard.string(forKey: "screenshotScene").flatMap(Scene.init)

    static var isActive: Bool { scene != nil }

    /// An in-memory store with the demo content already saved.
    @MainActor
    static func makeContainer() -> ModelContainer {
        let container = ModelContainerFactory.makeContainer(inMemory: true)
        seed(container.mainContext)
        return container
    }

    // MARK: - Demo content

    /// The child every child-facing scene opens.
    static let firstChildID = UUID(uuidString: "5C9E2B4A-1D3F-4E8A-9B7C-0A1B2C3D4E5F")!

    private struct DemoTile {
        let titles: [String: String]
        let symbol: String
        let category: TileCategory
        let source: MediaSourceType
        let items: Int
    }

    private static let music: [DemoTile] = [
        DemoTile(titles: ["en": "Bedtime songs", "nl": "Slaapliedjes", "de": "Schlaflieder", "fr": "Berceuses", "es": "Canciones de cuna"],
                 symbol: "moon.stars.fill", category: .music, source: .appleMusic, items: 12),
        DemoTile(titles: ["en": "In the car", "nl": "In de auto", "de": "Im Auto", "fr": "En voiture", "es": "En el coche"],
                 symbol: "car.fill", category: .music, source: .localAudio, items: 18),
        DemoTile(titles: ["en": "Sing along", "nl": "Meezingen", "de": "Mitsingen", "fr": "On chante", "es": "A cantar"],
                 symbol: "music.note", category: .music, source: .appleMusic, items: 9),
        DemoTile(titles: ["en": "Piano", "nl": "Piano", "de": "Klavier", "fr": "Piano", "es": "Piano"],
                 symbol: "pianokeys", category: .music, source: .localAudio, items: 6),
        DemoTile(titles: ["en": "Dancing", "nl": "Dansen", "de": "Tanzen", "fr": "On danse", "es": "A bailar"],
                 symbol: "balloon.fill", category: .music, source: .youtube, items: 7),
        DemoTile(titles: ["en": "Stories", "nl": "Verhaaltjes", "de": "Geschichten", "fr": "Histoires", "es": "Cuentos"],
                 symbol: "book.fill", category: .music, source: .localAudio, items: 5),
    ]

    private static let video: [DemoTile] = [
        DemoTile(titles: ["en": "Animals", "nl": "Dieren", "de": "Tiere", "fr": "Les animaux", "es": "Animales"],
                 symbol: "pawprint.fill", category: .video, source: .youtube, items: 8),
        DemoTile(titles: ["en": "Trains", "nl": "Treinen", "de": "Züge", "fr": "Les trains", "es": "Trenes"],
                 symbol: "tram.fill", category: .video, source: .youtube, items: 11),
        DemoTile(titles: ["en": "Painting", "nl": "Schilderen", "de": "Malen", "fr": "Peinture", "es": "Pintar"],
                 symbol: "paintpalette.fill", category: .video, source: .localVideo, items: 4),
        DemoTile(titles: ["en": "Aeroplanes", "nl": "Vliegtuigen", "de": "Flugzeuge", "fr": "Les avions", "es": "Aviones"],
                 symbol: "airplane", category: .video, source: .youtube, items: 6),
        DemoTile(titles: ["en": "Holiday", "nl": "Vakantie", "de": "Urlaub", "fr": "Vacances", "es": "Vacaciones"],
                 symbol: "sun.max.fill", category: .video, source: .localVideo, items: 10),
        DemoTile(titles: ["en": "Football", "nl": "Voetbal", "de": "Fußball", "fr": "Le foot", "es": "Fútbol"],
                 symbol: "soccerball", category: .video, source: .youtube, items: 5),
    ]

    /// Colours chosen per tile so the grid reads as a calm set, not a rainbow.
    private static let tileColours: [(tint: UIColor, background: UIColor)] = [
        (UIColor(red: 0.98, green: 0.96, blue: 0.88, alpha: 1), UIColor(red: 0.33, green: 0.38, blue: 0.55, alpha: 1)),
        (UIColor(red: 0.99, green: 0.97, blue: 0.93, alpha: 1), UIColor(red: 0.74, green: 0.53, blue: 0.45, alpha: 1)),
        (UIColor(red: 0.98, green: 0.98, blue: 0.95, alpha: 1), UIColor(red: 0.48, green: 0.59, blue: 0.48, alpha: 1)),
        (UIColor(red: 0.30, green: 0.27, blue: 0.24, alpha: 1), UIColor(red: 0.91, green: 0.86, blue: 0.76, alpha: 1)),
        (UIColor(red: 0.98, green: 0.97, blue: 0.99, alpha: 1), UIColor(red: 0.58, green: 0.53, blue: 0.70, alpha: 1)),
        (UIColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 1), UIColor(red: 0.40, green: 0.53, blue: 0.64, alpha: 1)),
    ]

    private static var language: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }

    private static func title(_ titles: [String: String]) -> String {
        titles[language] ?? titles["en"] ?? ""
    }

    @MainActor
    private static func seed(_ context: ModelContext) {
        let children = [
            ChildProfile(id: firstChildID, name: "Noor", avatarIconName: "hare.fill", colorThemeName: "sage",
                         sortOrder: 0, dailyScreenTimeLimitMinutes: 45,
                         enabledGameIDs: GameCatalog.all.map(\.identifier)),
            ChildProfile(name: "Sam", avatarIconName: "tortoise.fill", colorThemeName: "clay", sortOrder: 1,
                         enabledGameIDs: [GameCatalog.matchingPairs, GameCatalog.patternMemory]),
            ChildProfile(name: "Mila", avatarIconName: "bird.fill", colorThemeName: "lavender", sortOrder: 2,
                         enabledGameIDs: [GameCatalog.matchingPairs]),
        ]
        children.forEach(context.insert)

        var tiles: [Tile] = []
        for (index, demo) in (music + video).enumerated() {
            let colours = tileColours[index % tileColours.count]
            let icon = TileArtwork.Icon(id: demo.symbol, displayName: "")
            let tile = Tile(
                title: title(demo.titles),
                imageData: TileArtwork.renderIcon(icon, tint: colours.tint, background: colours.background) ?? Data(),
                category: demo.category,
                ownerProfileID: firstChildID,
                sortOrder: index
            )
            context.insert(tile)
            for number in 1...demo.items {
                let item = MediaItem(type: demo.source, title: "\(tile.title) \(number)")
                switch demo.source {
                case .youtube: item.youtubeVideoID = "demo\(index)x\(number)"
                case .appleMusic: item.appleMusicItemID = "\(1_000_000 + index * 100 + number)"
                case .localAudio, .localVideo: item.localFileName = "demo-\(index)-\(number)"
                }
                tile.append(item)
            }
            tiles.append(tile)
        }

        // A week of listening, watching and playing, for the statistics scene.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var generator = SeededGenerator(seed: 7)
        for day in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -day, to: today) else { continue }
            // As UsageRecorder writes them: an "opened" marker without an
            // item, then one timed row per song, video or game played.
            for slot in 0..<4 {
                let tile = tiles[Int.random(in: 0..<tiles.count, using: &generator)]
                let items = tile.orderedMediaItems
                let item = items[Int.random(in: 0..<items.count, using: &generator)]
                let start = date.addingTimeInterval(TimeInterval((8 + slot * 3) * 3600))
                context.insert(UsageSession(profileID: firstChildID, tileID: tile.id, startTime: start))
                context.insert(UsageSession(
                    profileID: firstChildID,
                    tileID: tile.id,
                    mediaItemID: item.id,
                    startTime: start,
                    durationSeconds: Int.random(in: 300...1500, using: &generator)
                ))
            }
            let game = GameCatalog.all[day % GameCatalog.all.count]
            let start = date.addingTimeInterval(17 * 3600)
            context.insert(UsageSession(
                profileID: firstChildID, tileID: game.id, gameIdentifier: game.identifier, startTime: start))
            context.insert(UsageSession(
                profileID: firstChildID,
                tileID: game.id,
                mediaItemID: game.id,
                gameIdentifier: game.identifier,
                startTime: start,
                durationSeconds: Int.random(in: 240...900, using: &generator)
            ))
        }

        try? context.save()
    }
}

/// Same pictures on every run, so a new set of screenshots only differs where
/// the app did.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
