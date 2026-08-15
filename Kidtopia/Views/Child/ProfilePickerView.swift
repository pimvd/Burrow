import SwiftData
import SwiftUI

/// The child-facing picker: large avatars and names, nothing else to read.
struct ProfilePickerView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ScreenTimeCoordinator.self) private var screenTime
    @Environment(MediaPlaybackService.self) private var playback
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query(sort: \ChildProfile.sortOrder) private var profiles: [ChildProfile]

    private var columns: [GridItem] {
        let minimum: CGFloat = horizontalSizeClass == .regular ? 200 : 150
        return [GridItem(.adaptive(minimum: minimum), spacing: 28)]
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 28) {
                    ForEach(profiles) { profile in
                        Button {
                            open(profile)
                        } label: {
                            ProfileCard(profile: profile)
                        }
                        .buttonStyle(.calm)
                        .accessibilityLabel(Text(profile.name))
                    }
                }
                .padding(28)
            }
            .scrollBounceBehavior(.basedOnSize)

            ParentEntryButton()
                .padding(20)
        }
        .background(Color(.systemBackground))
        .onAppear {
            // Leaving a profile always ends its session and its playback.
            screenTime.stop()
            playback.stop()
        }
    }

    private func open(_ profile: ChildProfile) {
        screenTime.startSession(limitMinutes: profile.dailyScreenTimeLimitMinutes)
        router.showChild(profileID: profile.id)
    }
}

private struct ProfileCard: View {
    let profile: ChildProfile

    var body: some View {
        VStack(spacing: 14) {
            ProfileAvatarView(profile: profile, diameter: 112)

            Text(profile.name)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(profile.theme.wash)
        .calmCard(cornerRadius: 28)
    }
}

/// A small, deliberately understated way into the parent area. It sits in a
/// corner and uses a neutral icon so it does not invite tapping.
struct ParentEntryButton: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        Button {
            router.openParentArea()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.calm)
        .accessibilityLabel(Text("For grown-ups", comment: "Parent area entry button"))
    }
}
