import SwiftUI
import AuthenticationServices

struct SignupView: View {
    @Binding var showSignup: Bool
    @EnvironmentObject var authStore: AuthStore
    @StateObject private var authVM = AuthViewModel()
    @FocusState private var focused: Field?
    @Environment(\.colorScheme) private var colorScheme

    private enum Field { case email, password, confirm }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 56)

                // Brand mark + header
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.tint)
                            .frame(width: 72, height: 72)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Text("Create Account")
                        .font(.system(size: 32, weight: .bold))
                    Text("Start your ELOS journey")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 36)

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
                        SecureField("Min 8 characters", text: $authVM.password)
                            .textContentType(.newPassword)
                            .focused($focused, equals: .password)
                            .submitLabel(.next)
                            .onSubmit { focused = .confirm }
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(focused == .password ? Color.tint : Color.clear, lineWidth: 1.5))
                    }

                    // Confirm password
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CONFIRM PASSWORD")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        SecureField("Re-enter password", text: $authVM.confirmPassword)
                            .textContentType(.newPassword)
                            .focused($focused, equals: .confirm)
                            .submitLabel(.go)
                            .onSubmit { Task { await authVM.register(authStore: authStore) } }
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(focused == .confirm ? Color.tint : Color.clear, lineWidth: 1.5))
                    }

                    if let err = authVM.errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(Color.bad)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let info = authVM.infoMessage {
                        Text(info)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task { await authVM.register(authStore: authStore) }
                    } label: {
                        Group {
                            if authVM.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Create Account")
                            }
                        }
                    }
                    .buttonStyle(ElosFilledButtonStyle())
                    .disabled(authVM.isLoading)
                    .padding(.top, 4)

                    HStack(spacing: 12) {
                        Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 1)
                        Text("or").font(.caption).foregroundStyle(.secondary)
                        Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 1)
                    }
                    .padding(.vertical, 2)

                    SignInWithAppleButton(.signUp) { request in
                        authVM.prepareAppleRequest(request)
                    } onCompletion: { result in
                        Task { await authVM.signInWithApple(result) }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .disabled(authVM.isLoading)
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 32)

                Button {
                    withAnimation { showSignup = false }
                } label: {
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundStyle(.secondary)
                        Text("Sign In")
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.tint)
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.plain)

                HStack(spacing: 4) {
                    Text("By signing up you agree to our")
                        .foregroundStyle(.secondary)
                    Link("Terms", destination: URL(string: "https://elos.onrender.com/terms")!)
                        .foregroundStyle(Color.tint)
                    Text("and")
                        .foregroundStyle(.secondary)
                    Link("Privacy Policy", destination: URL(string: "https://elos.onrender.com/privacy")!)
                        .foregroundStyle(Color.tint)
                }
                .font(.caption2)
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer().frame(height: 48)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea()
    }
}
