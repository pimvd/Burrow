import SwiftUI

/// The birth-year gate in front of everything a parent can change.
///
/// It is not a locked modal: a back button always returns to the child screen.
struct ParentalGateView: View {
    @Environment(ParentSessionState.self) private var parentSession
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = ParentalGateViewModel()
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: CalmStyle.sectionSpacing) {
            Spacer(minLength: 0)

            Image(systemName: "lock.shield")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("For grown-ups", comment: "Parental gate title")
                    .font(.title2.weight(.semibold))

                Text("Enter your birth year to continue.", comment: "Parental gate instruction")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                Button {
                    viewModel.adjustYear(by: -1)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(Text("One year earlier", comment: "Parental gate stepper"))

                TextField(
                    String(localized: "Year", comment: "Parental gate field placeholder"),
                    text: $viewModel.enteredYearText
                )
                .keyboardType(.numberPad)
                .textContentType(.none)
                .multilineTextAlignment(.center)
                .font(.system(.title, design: .rounded).monospacedDigit())
                .frame(maxWidth: 160)
                .padding(.vertical, 8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .focused($isFieldFocused)
                .onChange(of: viewModel.enteredYearText) { _, _ in
                    viewModel.clearFailure()
                }

                Button {
                    viewModel.adjustYear(by: 1)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(Text("One year later", comment: "Parental gate stepper"))
            }

            // Identical message for every failure reason, on purpose.
            Text("That is not correct. Please try again.", comment: "Parental gate failure")
                .font(.callout)
                .foregroundStyle(.red)
                .opacity(viewModel.showsFailure ? 1 : 0)
                .accessibilityHidden(!viewModel.showsFailure)

            Button {
                submit()
            } label: {
                Text("Continue", comment: "Parental gate confirm button")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.enteredYearText.isEmpty)

            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Label(
                        String(localized: "Back", comment: "Leave the parental gate"),
                        systemImage: "chevron.backward"
                    )
                }
            }
        }
        .onAppear {
            isFieldFocused = true
        }
    }

    private func submit() {
        if viewModel.validate() {
            isFieldFocused = false
            parentSession.unlock()
        }
    }
}

#Preview {
    NavigationStack {
        ParentalGateView()
    }
    .environment(ParentSessionState())
}
