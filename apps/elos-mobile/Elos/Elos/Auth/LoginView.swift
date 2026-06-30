import SwiftUI

struct LoginView: View {
    @Binding var showSignup: Bool
    @EnvironmentObject var authStore: AuthStore
    @StateObject private var authVM = AuthViewModel()
    @FocusState private var focused: Field?

    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 64)

                // Brand mark + wordmark
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.tint)
                            .frame(width: 72, height: 72)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Text("ELOS")
                        .font(.system(size: 38, weight: .black))
                        .foregroundStyle(Color.tint)
                    Text("Everyday Life Operating System")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 48)

                VStack(spacing: 16) {
                    // Email
                    VStack(alignment: .leading, spacing: 6) {
                        Text("EMAIL")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        TextField("you@example.com", text: $authVM.email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($focused, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focused = .password }
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(focused == .email ? Color.tint : Color.clear, lineWidth: 1.5))
                    }

                    // Password
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PASSWORD")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        SecureField("••••••••", text: $authVM.password)
                            .textContentType(.password)
                            .focused($focused, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { Task { await authVM.login(authStore: authStore) } }
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(focused == .password ? Color.tint : Color.clear, lineWidth: 1.5))
                    }

                    if let err = authVM.errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(Color.bad)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await authVM.login(authStore: authStore) }
                    } label: {
                        Group {
                            if authVM.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Sign In")
                            }
                        }
                    }
                    .buttonStyle(ElosFilledButtonStyle())
                    .disabled(authVM.isLoading || authVM.email.isEmpty || authVM.password.isEmpty)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)

                // Forgot password
                Button {
                    Task { await authVM.sendPasswordReset() }
                } label: {
                    HStack(spacing: 6) {
                        if authVM.isLoading {
                            ProgressView().scaleEffect(0.7)
                        }
                        Text(authVM.isLoading ? "Sending…" : "Forgot password?")
                            .font(.caption)
                            .foregroundStyle(Color.tint)
                    }
                }
                .buttonStyle(.plain)
                .disabled(authVM.isLoading)
                .padding(.top, 12)

                if let info = authVM.infoMessage {
                    Text(info)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }

                Spacer().frame(height: 40)

                Button {
                    withAnimation { showSignup = true }
                } label: {
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .foregroundStyle(.secondary)
                        Text("Sign Up")
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.tint)
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.plain)

                Spacer().frame(height: 60)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea()
    }
}
