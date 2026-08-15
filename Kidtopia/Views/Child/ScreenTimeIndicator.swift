import SwiftUI

/// A small, quiet ring that fills up as the session runs out. No countdown
/// numbers and no colour alarm: it is information, not pressure.
struct ScreenTimeIndicator: View {
    @Environment(ScreenTimeCoordinator.self) private var screenTime

    var body: some View {
        if let progress = screenTime.progress {
            Circle()
                .stroke(Color.secondary.opacity(0.25), lineWidth: 4)
                .overlay {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.secondary.opacity(0.7), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 26, height: 26)
                .padding(9)
                .background(.thinMaterial, in: Circle())
                .animation(CalmStyle.transition, value: progress)
                .accessibilityLabel(Text("Time left in this session", comment: "Screen time indicator"))
                .accessibilityValue(Text("\(Int((1 - progress) * 100)) percent", comment: "Screen time remaining"))
        }
    }
}
