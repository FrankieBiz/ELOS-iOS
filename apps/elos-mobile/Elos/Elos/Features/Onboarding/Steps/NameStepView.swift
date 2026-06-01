import SwiftUI

struct NameStepView: View {
    @ObservedObject var vm: OnboardingViewModel
    @FocusState private var focused: Field?

    private enum Field { case first, last }

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
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
                        .submitLabel(.done)
                        .onSubmit { focused = nil }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .onAppear { focused = .first }
    }
}
