import SwiftUI

struct ProgramSelectionStepView: View {
    @ObservedObject var vm: OnboardingViewModel

    private let years = ["freshman", "sophomore", "junior", "senior"]
    private let yearLabels = ["Freshman", "Sophomore", "Junior", "Senior"]

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                Text("School & Nutrition")
                    .font(.system(size: 28, weight: .bold))
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
                        .clipShape(RoundedRectangle(cornerRadius: 10))
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
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
                            .font(.system(size: 22, weight: .semibold, design: .monospaced))
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
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .onAppear {
            vm.applyAutoCalc()
        }
    }
}
