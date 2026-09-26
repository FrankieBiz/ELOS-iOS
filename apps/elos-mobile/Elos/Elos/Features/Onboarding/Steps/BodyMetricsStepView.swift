import SwiftUI

struct BodyMetricsStepView: View {
    @ObservedObject var vm: OnboardingViewModel

    private var weightIntBinding: Binding<Int> {
        Binding(get: { Int(vm.weightLbs) }, set: { vm.weightLbs = Double($0) })
    }

    /// Convert the stored values once on a units toggle so the wheels never land on
    /// an empty/invalid selection. Note: in metric mode the cm picker binds directly to
    /// `vm.heightFeet`, and `vm.weightLbs` holds kg. By the time this fires `vm.useImperial`
    /// has already flipped, so we convert from the raw fields rather than the computed props.
    private func convertUnits(toImperial: Bool) {
        if toImperial {
            // metric -> imperial: heightFeet held cm, weightLbs held kg
            let cm = Double(vm.heightFeet)
            let totalInches = cm / 2.54
            let feet = Int((totalInches / 12).rounded(.down))
            let inches = Int((totalInches - Double(feet) * 12).rounded())
            vm.heightFeet = min(max(feet, 4), 8)
            vm.heightInches = min(max(inches, 0), 11)
            let lbs = vm.weightLbs / WeightUnit.kgPerLb
            vm.weightLbs = min(max(lbs, 80), 400)
        } else {
            // imperial -> metric: heightFeet held feet, weightLbs held lbs
            let cm = (Double(vm.heightFeet) * 12 + Double(vm.heightInches)) * 2.54
            vm.heightFeet = min(max(Int(cm.rounded()), 100), 250)
            let kg = vm.weightLbs * WeightUnit.kgPerLb
            vm.weightLbs = min(max(kg, 35), 200)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your body stats")
                    .font(.system(.title, weight: .bold))
                Text("Used to calculate personalized nutrition and training targets.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Unit toggle
            HStack {
                Text("UNITS")
                    .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $vm.useImperial) {
                    Text("Imperial").tag(true)
                    Text("Metric").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .onChange(of: vm.useImperial) { _, nowImperial in
                    convertUnits(toImperial: nowImperial)
                }
            }

            // Height
            VStack(alignment: .leading, spacing: 6) {
                Text("HEIGHT")
                    .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                HStack(spacing: 0) {
                    if vm.useImperial {
                        Picker("Feet", selection: $vm.heightFeet) {
                            ForEach(4...8, id: \.self) { Text("\($0) ft").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        Picker("Inches", selection: $vm.heightInches) {
                            ForEach(0...11, id: \.self) { Text("\($0) in").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    } else {
                        Picker("cm", selection: $vm.heightFeet) {
                            ForEach(100...250, id: \.self) { Text("\($0) cm").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                }
                .frame(height: 120)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            // Weight + Age side by side
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("WEIGHT")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    Picker("Weight", selection: weightIntBinding) {
                        let range = vm.useImperial ? Array(80...400) : Array(35...200)
                        ForEach(range, id: \.self) { w in
                            Text("\(w) \(vm.useImperial ? "lbs" : "kg")").tag(w)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("AGE")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                    Picker("Age", selection: $vm.ageYears) {
                        ForEach(13...80, id: \.self) { Text("\($0) yrs").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }
}
