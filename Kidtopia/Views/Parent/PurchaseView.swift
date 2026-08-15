import StoreKit
import SwiftUI

/// The single one-time purchase. No subscription, no ads, nothing to track.
struct PurchaseView: View {
    @Environment(StoreManager.self) private var store

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Unlock Kidtopia", comment: "Purchase title")
                        .font(.title2.weight(.semibold))

                    Text(
                        "One purchase, forever. No subscription, no ads, and nothing about your family leaves your devices.",
                        comment: "Purchase promise"
                    )
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section {
                benefit(
                    systemImage: "person.2",
                    title: String(localized: "Unlimited profiles", comment: "Purchase benefit"),
                    detail: String(localized: "The free version has one.", comment: "Purchase benefit detail")
                )
                benefit(
                    systemImage: "square.grid.2x2",
                    title: String(localized: "Unlimited tiles", comment: "Purchase benefit"),
                    detail: String(localized: "The free version has five per profile.", comment: "Purchase benefit detail")
                )
                benefit(
                    systemImage: "music.note.list",
                    title: String(localized: "Up to 50 items per playlist", comment: "Purchase benefit"),
                    detail: String(localized: "The free version has three.", comment: "Purchase benefit detail")
                )
            } header: {
                Text("What you get", comment: "Purchase section")
            }

            Section {
                if store.isPro {
                    Label {
                        Text("Already unlocked", comment: "Purchase state")
                    } icon: {
                        Image(systemName: "checkmark.seal")
                    }
                } else {
                    Button {
                        Task { await store.purchase() }
                    } label: {
                        HStack {
                            Text("Unlock", comment: "Purchase button")
                            Spacer()
                            if store.isPurchasing {
                                ProgressView()
                            } else if let product = store.product {
                                Text(product.displayPrice)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(store.isPurchasing || store.product == nil)

                    Button {
                        Task { await store.restorePurchases() }
                    } label: {
                        Text("Restore purchase", comment: "Restore button")
                    }
                }

                if let message = store.lastErrorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.callout)
                }
            }
        }
        .navigationTitle(Text("Kidtopia", comment: "Purchase screen title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.refresh()
        }
    }

    private func benefit(systemImage: String, title: String, detail: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
        }
    }
}
