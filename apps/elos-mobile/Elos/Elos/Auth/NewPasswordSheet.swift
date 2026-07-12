import SwiftUI
import Supabase

/// Presented when the app is opened from a password-reset email link.
/// The recovery link already established a session, so the user just picks
/// a new password — no re-login dance.
struct NewPasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirm = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("New password (min 8 characters)", text: $password)
                        .textContentType(.newPassword)
                        .focused($focused)
                    SecureField("Confirm new password", text: $confirm)
                        .textContentType(.newPassword)
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(Color.bad)
                    }
                }
                Section {
                    Button {
                        save()
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving { ProgressView() }
                            else { Text("Set New Password").fontWeight(.semibold) }
                            Spacer()
                        }
                    }
                    .disabled(isSaving || password.isEmpty || confirm.isEmpty)
                }
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { focused = true }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private func save() {
        guard password.count >= 8 else { errorMessage = "Password must be at least 8 characters."; return }
        guard password == confirm else { errorMessage = "Passwords do not match."; return }
        errorMessage = nil
        isSaving = true
        Task {
            do {
                try await SupabaseManager.shared.client.auth.update(
                    user: UserAttributes(password: password)
                )
                HapticManager.success()
                dismiss()
            } catch {
                errorMessage = "Couldn't update the password. Please try again."
            }
            isSaving = false
        }
    }
}
