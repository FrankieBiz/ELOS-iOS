import SwiftUI
import SwiftData

struct OnboardingView: View {
    @EnvironmentObject var authStore: AuthStore
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = OnboardingViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            VStack(spacing: 5) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 4)
                        Capsule()
                            .fill(Color.tint)
                            .frame(
                                width: geo.size.width * CGFloat(vm.step + 1) / CGFloat(vm.totalSteps),
                                height: 4
                            )
                    }
                }
                .frame(height: 4)
                Text("Step \(vm.step + 1) of \(vm.totalSteps)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 4)
            .animation(.spring(duration: 0.4), value: vm.step)

            // Step content
            Group {
                switch vm.step {
                case 0: WelcomeStepView()
                case 1: NameStepView(vm: vm)
                case 2: BodyMetricsStepView(vm: vm)
                case 3: ExperienceStepView(vm: vm)
                case 4: ProgramSelectionStepView(vm: vm)
                default: ReadyStepView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal:   .move(edge: .leading).combined(with: .opacity)
            ))

            // Navigation buttons
            HStack(spacing: 12) {
                if vm.step > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { vm.step -= 1 }
                    } label: {
                        Text("Back")
                    }
                    .buttonStyle(ElosSecondaryButtonStyle())
                    .frame(width: 100)
                }

                Button {
                    advance()
                } label: {
                    if vm.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(vm.step == vm.totalSteps - 1 ? "Get Started" : "Next")
                    }
                }
                .buttonStyle(ElosFilledButtonStyle())
                .disabled(!vm.canAdvance || vm.isLoading)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)

            if let err = vm.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(Color.bad)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .background(Color(.systemGroupedBackground))
        .animation(.easeInOut(duration: 0.3), value: vm.step)
    }

    private func advance() {
        if vm.step == vm.totalSteps - 1 {
            Task { await vm.completeOnboarding(context: modelContext, authStore: authStore) }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) { vm.step += 1 }
        }
    }
}

// MARK: - Final "Ready" step
private struct ReadyStepView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.mGym)
            Text("You're all set!")
                .font(.system(size: 32, weight: .bold))
            Text("Your profile is ready.\nLet's get to work.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}
