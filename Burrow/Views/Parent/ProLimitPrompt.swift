import SwiftUI

/// One freemium limit the parent just ran into. The message is the identity, so
/// the sheet stays stable while it animates in.
private struct ProLimitPrompt: Identifiable {
    let message: String

    var id: String { message }
}

/// Presents a freemium limit where it can actually be resolved.
///
/// A free parent goes straight to the purchase screen with the reason on top, so
/// the limit and the way past it are one tap apart. A parent who already has
/// everything — bought or still trialling — can only reach the hard 50-item
/// playlist cap, which no purchase lifts, so that one stays a plain alert.
private struct ProLimitModifier: ViewModifier {
    @Environment(StoreManager.self) private var store

    @Binding var message: String?

    func body(content: Content) -> some View {
        content
            .sheet(item: purchasePrompt) { prompt in
                NavigationStack {
                    PurchaseView(reason: prompt.message)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button {
                                    message = nil
                                } label: {
                                    Text("Close", comment: "Dismiss the purchase screen")
                                }
                            }
                        }
                }
            }
            .alert(
                Text("Not available yet", comment: "Freemium limit alert title"),
                isPresented: capReached
            ) {
                Button(role: .cancel) {
                    message = nil
                } label: {
                    Text("OK", comment: "Alert dismiss")
                }
            } message: {
                Text(message ?? "")
            }
    }

    /// Set only while a free parent has a limit to clear.
    private var purchasePrompt: Binding<ProLimitPrompt?> {
        Binding(
            get: { store.hasFullAccess ? nil : message.map(ProLimitPrompt.init(message:)) },
            set: { if $0 == nil { message = nil } }
        )
    }

    /// Set only for the paid tier's own ceiling, which buying cannot raise.
    private var capReached: Binding<Bool> {
        Binding(
            get: { store.hasFullAccess && message != nil },
            set: { if !$0 { message = nil } }
        )
    }
}

extension View {
    /// Shows the purchase screen — or, for a paid parent, an alert — whenever
    /// `message` holds a ``ProGate`` limit message.
    func proLimitPrompt(_ message: Binding<String?>) -> some View {
        modifier(ProLimitModifier(message: message))
    }
}
