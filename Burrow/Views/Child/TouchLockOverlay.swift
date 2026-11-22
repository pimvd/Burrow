import SwiftUI

/// The button that closes the touch lock. It sits in the player's header while a
/// picture is playing, next to the quiet furniture rather than among the
/// transport buttons, because it is for the grown-up holding the device.
struct TouchLockButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "lock.open")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 48, height: 48)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.calm)
        .accessibilityLabel(Text("Lock the screen", comment: "Touch lock button"))
    }
}

/// The layer over a locked player: it takes every touch and passes none of them
/// on, and it carries the one way out.
///
/// The way out sits in the corner the lock button came from, so a parent reaches
/// for the same place twice, and it is small and grey rather than large and
/// inviting — a child who finds it should find nothing worth pressing.
struct TouchLockOverlay: View {
    @Binding var lock: TouchLock
    let tint: Color

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // The whole screen, safe areas included: a locked player has no
            // corner left that still does something.
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { lock.touched() }

            if lock.showsUnlock {
                HoldToUnlockButton(
                    tint: tint,
                    onTouched: { lock.touched() },
                    onHoldCompleted: { lock.unlock() }
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .transition(.opacity)
            }
        }
        .animation(CalmStyle.transition, value: lock.showsUnlock)
        .task(id: lock.revealCount) {
            guard lock.showsUnlock else { return }
            try? await Task.sleep(for: .seconds(TouchLock.unlockLinger))
            guard !Task.isCancelled else { return }
            lock.hideUnlock()
        }
    }
}

/// The way out: a press and hold, with a ring that fills as it goes so a parent
/// can see that holding on is the right thing to be doing.
private struct HoldToUnlockButton: View {
    let tint: Color

    /// Called as the press begins and again as it ends, so the caller can keep
    /// the button on screen for as long as somebody is working at it.
    let onTouched: () -> Void

    let onHoldCompleted: () -> Void

    /// Runs 0 to 1 over the length of the hold. It is only ever a picture of the
    /// gesture's own timing — the unlock itself comes from the gesture.
    @State private var holdProgress: CGFloat = 0

    private static let diameter: CGFloat = 64
    private static let ringWidth: CGFloat = 4

    /// A thumb settling into a three second hold wanders further than the
    /// default allowance, and a hold cancelled by a millimetre of drift reads as
    /// a lock that will not open.
    private static let holdDrift: CGFloat = 40

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(.thinMaterial)

                Circle()
                    .stroke(Color.secondary.opacity(0.25), lineWidth: Self.ringWidth)

                Circle()
                    .trim(from: 0, to: holdProgress)
                    .stroke(tint, style: StrokeStyle(lineWidth: Self.ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Image(systemName: "lock.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: Self.diameter, height: Self.diameter)

            Text("Hold to unlock", comment: "Touch lock hint")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: Capsule())
        }
        .contentShape(Rectangle())
        .onLongPressGesture(
            minimumDuration: TouchLock.unlockHold,
            maximumDistance: Self.holdDrift,
            perform: onHoldCompleted,
            onPressingChanged: { isPressing in
                onTouched()
                let pace: Animation = isPressing
                    ? .linear(duration: TouchLock.unlockHold)
                    : CalmStyle.transition
                withAnimation(pace) {
                    holdProgress = isPressing ? 1 : 0
                }
            }
        )
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text("Unlock the screen", comment: "Touch lock unlock button"))
        .accessibilityHint(Text("Press and hold", comment: "Touch lock unlock hint"))
    }
}

/// A locked player, minus the video: the overlay over something dark.
private struct TouchLockPreview: View {
    @State private var lock: TouchLock = {
        var lock = TouchLock()
        lock.lock()
        return lock
    }()

    var body: some View {
        ZStack {
            Color.black
            Text(verbatim: "A video plays here")
                .foregroundStyle(.white)
            TouchLockOverlay(lock: $lock, tint: .teal)
        }
    }
}

#Preview {
    TouchLockPreview()
}
