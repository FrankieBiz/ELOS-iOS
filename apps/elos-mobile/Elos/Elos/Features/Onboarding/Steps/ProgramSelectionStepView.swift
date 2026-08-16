import SwiftUI

struct ProgramSelectionStepView: View {
    @ObservedObject var vm: OnboardingViewModel

    private let years = ["freshman", "sophomore", "junior", "senior"]
    private let yearLabels = ["Freshman", "Sophomore", "Junior", "Senior"]

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                Text("School & Nutrition")
                    .font(.system(.title, weight: .bold))
                Text("Track assignments, exams, and hit your macro targets.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
                // School name
                VStack(alignment: .leading, spacing: 6) {
                    Text("SCHOOL NAME")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    TextField("e.g. University High School", text: $vm.schoolName)
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                // School year
                VStack(alignment: .leading, spacing: 8) {
                    Text("YEAR")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(0..<years.count, id: \.self) { i in
                            Button {
                                vm.schoolYear = years[i]
                            } label: {
                                Text(yearLabels[i])
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(vm.schoolYear == years[i] ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(vm.schoolYear == years[i] ? Color.tint : Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Calorie goal
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("DAILY CALORIE GOAL")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Toggle("Auto", isOn: $vm.useAutoCalc)
                            .labelsHidden()
                            .onChange(of: vm.useAutoCalc) { _, auto in
                                if auto { vm.applyAutoCalc() }
                            }
                        Text("Auto")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("\(vm.useAutoCalc ? vm.autoCalcCalories : vm.calGoal) kcal")
                            .font(.elosNumeric(.title2, weight: .semibold))
                            .foregroundStyle(Color.mNutri)
                        Spacer()
                        if !vm.useAutoCalc {
                            Stepper("", value: $vm.calGoal, in: 1200...5000, step: 50)
                                .labelsHidden()
                        }
                    }
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text("These are general estimates for educational use, not medical or dietary advice. Talk to a doctor or registered dietitian before changing how you eat — especially if you're still growing.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .onAppear {
            // Only (re-)derive from auto-calc; a Back-then-Next revisit must not clobber a value
            // the user already set by hand with the Stepper while auto-calc was off.
            if vm.useAutoCalc { vm.applyAutoCalc() }
        }
    }
}
