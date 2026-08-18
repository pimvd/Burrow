import SwiftUI

/// Shown when the session timer runs out. Friendly, quiet, and the only way on
/// is back to the profile picker.
struct TimesUpView: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: CalmStyle.sectionSpacing) {
            Spacer(minLength: 0)

            Image(systemName: "moon.zzz")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Time's up!", comment: "Screen time expired title")
                .font(.largeTitle.weight(.semibold))

            Text("See you next time.", comment: "Screen time expired subtitle")
                .font(.title3)
                .foregroundStyle(.secondary)

            Button {
                onFinish()
            } label: {
                Text("Done", comment: "Screen time expired button")
                    .frame(maxWidth: 240)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer(minLength: 0)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .interactiveDismissDisabled()
    }
}

#Preview {
    TimesUpView {}
}
