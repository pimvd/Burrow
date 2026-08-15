import SwiftUI
import UIKit

/// The fixed set of tile pictures a parent can choose instead of a photo, plus
/// the helpers that turn a choice into the image data stored on the tile.
enum TileArtwork {
    struct Icon: Identifiable, Hashable, Sendable {
        /// Also the SF Symbol name.
        let id: String
        let displayName: String

        var symbolName: String { id }
    }

    static let icons: [Icon] = [
        Icon(id: "music.note", displayName: String(localized: "Music note", comment: "Tile icon")),
        Icon(id: "guitars.fill", displayName: String(localized: "Guitars", comment: "Tile icon")),
        Icon(id: "pianokeys", displayName: String(localized: "Piano", comment: "Tile icon")),
        Icon(id: "film", displayName: String(localized: "Film", comment: "Tile icon")),
        Icon(id: "play.rectangle.fill", displayName: String(localized: "Play", comment: "Tile icon")),
        Icon(id: "book.fill", displayName: String(localized: "Book", comment: "Tile icon")),
        Icon(id: "car.fill", displayName: String(localized: "Car", comment: "Tile icon")),
        Icon(id: "airplane", displayName: String(localized: "Aeroplane", comment: "Tile icon")),
        Icon(id: "tram.fill", displayName: String(localized: "Tram", comment: "Tile icon")),
        Icon(id: "pawprint.fill", displayName: String(localized: "Paw print", comment: "Tile icon")),
        Icon(id: "leaf.fill", displayName: String(localized: "Leaf", comment: "Tile icon")),
        Icon(id: "sun.max.fill", displayName: String(localized: "Sun", comment: "Tile icon")),
        Icon(id: "moon.stars.fill", displayName: String(localized: "Moon", comment: "Tile icon")),
        Icon(id: "star.fill", displayName: String(localized: "Star", comment: "Tile icon")),
        Icon(id: "balloon.fill", displayName: String(localized: "Balloon", comment: "Tile icon")),
        Icon(id: "teddybear.fill", displayName: String(localized: "Teddy bear", comment: "Tile icon")),
        Icon(id: "soccerball", displayName: String(localized: "Ball", comment: "Tile icon")),
        Icon(id: "paintpalette.fill", displayName: String(localized: "Paint", comment: "Tile icon"))
    ]

    /// Side length of the square artwork that gets stored.
    static let renderSize: CGFloat = 600

    /// Draws one of the predefined icons into square PNG data, so a tile always
    /// stores plain image data no matter where the picture came from.
    static func renderIcon(_ icon: Icon, tint: UIColor, background: UIColor) -> Data? {
        let size = CGSize(width: renderSize, height: renderSize)
        let configuration = UIImage.SymbolConfiguration(
            pointSize: renderSize * 0.42,
            weight: .regular
        )
        guard let symbol = UIImage(systemName: icon.symbolName, withConfiguration: configuration) else {
            return nil
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            background.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let tinted = symbol.withTintColor(tint, renderingMode: .alwaysOriginal)
            let target = CGRect(
                x: (size.width - tinted.size.width) / 2,
                y: (size.height - tinted.size.height) / 2,
                width: tinted.size.width,
                height: tinted.size.height
            )
            tinted.draw(in: target)
        }
        return image.pngData()
    }

    /// Scales a photo down to the stored artwork size and encodes it as JPEG, so
    /// a full resolution picture never ends up in the synced store.
    static func prepare(photoData: Data) -> Data? {
        guard let image = UIImage(data: photoData) else { return nil }

        let side = min(image.size.width, image.size.height)
        let cropRect = CGRect(
            x: (image.size.width - side) / 2,
            y: (image.size.height - side) / 2,
            width: side,
            height: side
        )

        let cropped: UIImage
        if let cgImage = image.cgImage?.cropping(to: cropRect.applying(
            CGAffineTransform(scaleX: image.scale, y: image.scale)
        )) {
            cropped = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        } else {
            cropped = image
        }

        let targetSize = CGSize(width: renderSize, height: renderSize)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            cropped.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.85)
    }
}
