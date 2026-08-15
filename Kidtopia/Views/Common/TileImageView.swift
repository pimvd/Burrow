import SwiftUI
import UIKit

/// Decoded tile artwork, cached so scrolling the grid does not decode the same
/// image again on every frame. `NSCache` is thread safe, so the cache can be
/// invalidated from wherever a tile changes.
final class TileImageCache {
    static let shared = TileImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 120
    }

    func image(for tileID: UUID, data: Data) -> UIImage? {
        let key = tileID.uuidString as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard !data.isEmpty, let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    func invalidate(tileID: UUID) {
        cache.removeObject(forKey: tileID.uuidString as NSString)
    }
}

/// Shows a tile's artwork, or a calm placeholder when there is none yet.
struct TileImageView: View {
    let tileID: UUID
    let imageData: Data
    let category: TileCategory
    let tint: Color

    var body: some View {
        if let image = TileImageCache.shared.image(for: tileID, data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                tint.opacity(0.16)
                Image(systemName: category.symbolName)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(tint)
            }
        }
    }
}
