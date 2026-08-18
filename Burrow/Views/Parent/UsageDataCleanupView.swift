import SwiftData
import SwiftUI

/// Manual clean-up of usage data. Burrow never deletes statistics on a
/// schedule; the parent decides when, and what.
struct UsageDataCleanupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var sessions: [UsageSession]

    @State private var pendingChoice: Choice?
    @State private var resultMessage: String?

    private enum Choice: Int, Identifiable, CaseIterable {
        case olderThanThirtyDays = 30
        case olderThanNinetyDays = 90
        case olderThanOneYear = 365
        case everything = 0

        var id: Int { rawValue }

        var localizedTitle: String {
            switch self {
            case .olderThanThirtyDays:
                return String(localized: "Older than 30 days", comment: "Usage cleanup option")
            case .olderThanNinetyDays:
                return String(localized: "Older than 90 days", comment: "Usage cleanup option")
            case .olderThanOneYear:
                return String(localized: "Older than a year", comment: "Usage cleanup option")
            case .everything:
                return String(localized: "All usage data", comment: "Usage cleanup option")
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Choice.allCases) { choice in
                        Button(role: choice == .everything ? .destructive : nil) {
                            pendingChoice = choice
                        } label: {
                            LabeledContent {
                                Text("\(count(for: choice))")
                                    .monospacedDigit()
                            } label: {
                                Text(choice.localizedTitle)
                            }
                        }
                    }
                } header: {
                    Text("Delete", comment: "Usage cleanup section")
                } footer: {
                    Text(
                        "Burrow keeps usage data until you remove it yourself. Tiles you delete take their own statistics with them after 14 days.",
                        comment: "Usage cleanup explanation"
                    )
                }

                if let resultMessage {
                    Section {
                        Label(resultMessage, systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(Text("Clear usage data", comment: "Usage cleanup title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done", comment: "Close the sheet")
                    }
                }
            }
            .confirmationDialog(
                Text("Delete this data?", comment: "Usage cleanup confirmation"),
                isPresented: Binding(
                    get: { pendingChoice != nil },
                    set: { if !$0 { pendingChoice = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    if let pendingChoice {
                        delete(pendingChoice)
                    }
                    pendingChoice = nil
                } label: {
                    Text("Delete", comment: "Confirm deletion")
                }
                Button(role: .cancel) {
                    pendingChoice = nil
                } label: {
                    Text("Cancel", comment: "Cancel deletion")
                }
            } message: {
                Text(
                    "This cannot be undone. Your profiles and tiles stay exactly as they are.",
                    comment: "Usage cleanup confirmation explanation"
                )
            }
        }
    }

    private func cutoffDate(for choice: Choice) -> Date? {
        guard choice != .everything else { return nil }
        return Calendar.current.date(byAdding: .day, value: -choice.rawValue, to: Date())
    }

    private func count(for choice: Choice) -> Int {
        guard let cutoff = cutoffDate(for: choice) else { return sessions.count }
        return sessions.filter { $0.startTime < cutoff }.count
    }

    private func delete(_ choice: Choice) {
        let removed = count(for: choice)

        do {
            if let cutoff = cutoffDate(for: choice) {
                try modelContext.delete(
                    model: UsageSession.self,
                    where: #Predicate { $0.startTime < cutoff }
                )
            } else {
                try modelContext.delete(model: UsageSession.self)
            }
            ModelSaver.save(modelContext, describing: "clearing usage data")
            resultMessage = String(
                localized: "\(removed) entries removed.",
                comment: "Usage cleanup result"
            )
        } catch {
            resultMessage = error.localizedDescription
        }
    }
}
