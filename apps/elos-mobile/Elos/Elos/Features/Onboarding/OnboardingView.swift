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
            .animation(.elosEmphasis, value: vm.step)

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
                        withAnimation(.elosStandard) { vm.step -= 1 }
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
            .padding(.bottom, vm.step == 1 && !vm.canAdvance ? 8 : 40)

            if vm.step == 1 && !vm.canAdvance {
                Text("Pick an available username to continue")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }

            if let err = vm.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(Color.bad)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .background(Color(.systemGroupedBackground))
        .animation(.elosStandard, value: vm.step)
    }

    private func advance() {
        if vm.step == vm.totalSteps - 1 {
            Task { await vm.completeOnboarding(context: modelContext, authStore: authStore) }
        } else {
            withAnimation(.elosStandard) { vm.step += 1 }
        }
    }
}

// MARK: - Final "Ready" step
private struct ReadyStepView: View {
    @State private var bounce = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.mGym)
                .symbolEffect(.bounce, value: bounce)
                .onAppear { bounce.toggle() }
            Text("You're all set!")
                .font(.system(.title, weight: .bold))
            Text("Your profile is ready.\nLet's get to work.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}
