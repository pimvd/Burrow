import SwiftUI

/// Shown on a completely fresh install, before any profile exists. Creating the
/// first profile is a deliberate step the parent takes; nothing is created
/// automatically.
struct WelcomeView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(spacing: CalmStyle.sectionSpacing) {
            Spacer(minLength: 0)

            Image(systemName: "square.grid.2x2")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("Welcome to Burrow", comment: "First launch title")
                    .font(.largeTitle.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(
                    "Set up a profile for your child, then add tiles with their own music or videos.",
                    comment: "First launch explanation"
                )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            Button {
                router.openParentArea(at: .profiles)
            } label: {
                Text("Set up the first profile", comment: "First launch call to action")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer(minLength: 0)
        }
        .padding(32)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    WelcomeView()
        .environment(AppRouter())
}
