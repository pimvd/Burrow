import SwiftUI

/// The strip that shows what is still playing after the player has been closed.
///
/// Only music reaches this point — a video tile stops when its player goes away
/// — so the bar is the one place a child can put the music down again without
/// hunting for the tile it came from.
struct NowPlayingBar: View {
    let tileTitle: String
    let entryTitle: String?
    let tint: Color
    let onOpen: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(tint)
                        .frame(width: 36, height: 36)
                        .background(tint.opacity(0.15), in: Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(entryTitle ?? tileTitle)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                        if entryTitle != nil {
                            Text(tileTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.calm)
            .accessibilityLabel(Text("Open what is playing", comment: "Now playing bar"))

            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.calm)
            .accessibilityLabel(Text("Stop the music", comment: "Now playing bar"))
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
}
