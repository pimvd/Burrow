import SwiftUI

/// The circular avatar used in the profile picker and the parent lists.
struct ProfileAvatarView: View {
    let profile: ChildProfile
    var diameter: CGFloat = 96

    var body: some View {
        let theme = profile.theme

        Circle()
            .fill(theme.tint.opacity(0.18))
            .overlay {
                Image(systemName: profile.avatar.symbolName)
                    .font(.system(size: diameter * 0.44, weight: .regular))
                    .foregroundStyle(theme.tint)
            }
            .overlay {
                Circle().strokeBorder(theme.tint.opacity(0.35), lineWidth: 2)
            }
            .frame(width: diameter, height: diameter)
            .accessibilityHidden(true)
    }
}
