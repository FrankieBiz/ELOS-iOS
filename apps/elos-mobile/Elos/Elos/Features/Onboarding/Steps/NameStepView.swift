import SwiftUI

struct NameStepView: View {
    @ObservedObject var vm: OnboardingViewModel
    @FocusState private var focused: Field?

    private enum Field { case first, last, username }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What's your name?")
                    .font(.system(size: 28, weight: .bold))
                Text("We'll use this to personalize your experience.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("FIRST NAME")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    TextField("Frank", text: $vm.firstName)
                        .textContentType(.givenName)
                        .focused($focused, equals: .first)
                        .submitLabel(.next)
                        .onSubmit { focused = .last }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("LAST NAME")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    TextField("Bisignano", text: $vm.lastName)
                        .textContentType(.familyName)
                        .focused($focused, equals: .last)
                        .submitLabel(.next)
                        .onSubmit { focused = .username }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                usernameField
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .onAppear { focused = .first }
    }

    private var usernameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("USERNAME")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text("@").foregroundStyle(.secondary)
                TextField("frank_b", text: $vm.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.username)
                    .focused($focused, equals: .username)
                    .submitLabel(.done)
                    .onSubmit { focused = nil }
                    .onChange(of: vm.username) { _, newValue in
                        vm.onUsernameChanged(newValue)
                    }
                statusIcon
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(statusColor)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch vm.usernameStatus {
        case .checking:
            ProgressView().controlSize(.small)
        case .available:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.good)
        case .taken, .invalid:
            Image(systemName: "xmark.circle.fill").foregroundStyle(Color.bad)
        case .unknown:
            Image(systemName: "wifi.slash").foregroundStyle(.secondary)
        case .empty:
            EmptyView()
        }
    }

    private var statusMessage: String {
        switch vm.usernameStatus {
        case .empty:     return "This is how friends find you. Letters, numbers, underscore."
        case .checking:  return "Checking availability…"
        case .available: return "✓ Available"
        case .taken:     return "That username is taken — try another."
        case .invalid:   return "3–20 characters, must start with a letter."
        case .unknown:   return "Couldn't check right now — you can still continue."
        }
    }

    private var statusColor: Color {
        switch vm.usernameStatus {
        case .available: return Color.good
        case .taken, .invalid: return Color.bad
        default: return .secondary
        }
    }
}
