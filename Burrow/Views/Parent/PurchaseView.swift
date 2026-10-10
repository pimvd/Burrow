import StoreKit
import SwiftUI

/// The free trial and the single one-time purchase. No subscription, no ads,
/// nothing to track.
struct PurchaseView: View {
    /// Why the parent landed here, set when they arrived from a limit rather
    /// than from the settings list.
    var reason: String?

    @Environment(StoreManager.self) private var store

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    if let reason {
                        Label(reason, systemImage: "lock")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Text("Unlock Burrow", comment: "Purchase title")
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
                benefit(
                    systemImage: "gamecontroller",
                    title: String(localized: "All games", comment: "Purchase benefit"),
                    detail: String(localized: "The free version has two per profile.", comment: "Purchase benefit detail")
                )
            } header: {
                Text("What you get", comment: "Purchase section")
            } footer: {
                Text(YouTubeSupportNotice.full)
            }

            if store.isPro {
                Section {
                    Label {
                        Text("Already unlocked", comment: "Purchase state")
                    } icon: {
                        Image(systemName: "checkmark.seal")
                    }
                }
            } else {
                // The trial is its own section so the offer reads as an offer
                // rather than as one more button under the price.
                if !store.trial.state.hasStarted {
                    Section {
                        Button {
                            Task { await store.startTrial() }
                        } label: {
                            Label(
                                String(
                                    localized: "Try everything free for 14 days",
                                    comment: "Start the free trial"
                                ),
                                systemImage: "gift"
                            )
                        }
                        .disabled(store.isPurchasing || store.trialProduct == nil)
                    } footer: {
                        Text(
                            "The App Store asks you to confirm, as with any purchase, but the trial costs nothing and there is nothing to cancel. When the fortnight is over Burrow goes back to the free version and everything you made stays where it is.",
                            comment: "Free trial explanation"
                        )
                    }
                } else if store.trial.state.isActive {
                    Section {
                        Label {
                            Text(
                                "\(store.trial.state.daysRemaining) days left in your trial",
                                comment: "Remaining trial days"
                            )
                        } icon: {
                            Image(systemName: "hourglass")
                        }
                        .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        Label {
                            Text("Your free trial has ended.", comment: "Trial finished")
                        } icon: {
                            Image(systemName: "hourglass.bottomhalf.filled")
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                Section {
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
            }

            if let message = store.lastErrorMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.callout)
                }
            }
        }
        .navigationTitle(Text("Burrow", comment: "Purchase screen title"))
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
