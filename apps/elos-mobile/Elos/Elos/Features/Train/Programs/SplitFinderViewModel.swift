import SwiftUI
import Combine

final class SplitFinderViewModel: ObservableObject {

    @Published var currentStep: Int = 1
    @Published var input = SplitFinderInput()

    @Published var machineRating: Int    = 3
    @Published var dumbbellRating: Int   = 3
    @Published var barbellRating: Int    = 3
    @Published var autoSelectEquipment: Bool = false

    @Published var preferredStructure: SplitStyle? = nil

    @Published var hasSport: Bool = false
    @Published var sportFocusStep: Int = 0
    private let focusStepValues: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]
    private let focusStepLabels = ["Hobby", "Enthusiast", "Competitive", "Semi-Pro", "Elite"]

    var sportFocusLabel: String { focusStepLabels[sportFocusStep] }

    @Published var hasInjuries: Bool = false
    @Published var selectedInjuries: [InjuredPart: InjurySeverity] = [:]

    var injuryEntries: [InjuryEntry] {
        selectedInjuries.map { InjuryEntry(part: $0.key, severity: $0.value) }
    }

    @Published var hasWarmups: Bool = false
    @Published var recommendations: [SplitRecommendation] = []
    @Published var isComputing: Bool = false

    let totalSteps = 9

    var canGoNext: Bool {
        if currentStep == 7 { return !hasSport || input.sport != nil }
        return true
    }

    func next() {
        commitCurrentStep()
        if currentStep == totalSteps {
            computeRecommendations()
        } else {
            currentStep += 1
        }
    }

    func back() {
        guard currentStep > 1 else { return }
        currentStep -= 1
    }

    private func commitCurrentStep() {
        switch currentStep {
        case 4:
            buildEquipmentProfile()
        case 5:
            input.preferredStructure = preferredStructure
        case 7:
            input.sport = hasSport ? input.sport : nil
            input.sportFocusRatio = hasSport ? focusStepValues[sportFocusStep] : 0.0
        case 8:
            input.injuries = hasInjuries ? injuryEntries : []
        case 9:
            input.includeWarmups = hasWarmups
            input.warmupStyle = hasWarmups ? input.warmupStyle : nil
        default:
            break
        }
    }

    func buildEquipmentProfile() {
        if autoSelectEquipment {
            input.equipment = .balanced
            return
        }
        let total = Double(machineRating + dumbbellRating + barbellRating)
        if total == 0 {
            input.equipment = .balanced
        } else {
            input.equipment = EquipmentProfile(
                machineRatio:  Double(machineRating)  / total,
                dumbbellRatio: Double(dumbbellRating) / total,
                barbellRatio:  Double(barbellRating)  / total
            )
        }
    }

    func computeRecommendations() {
        isComputing = true
        var recs = SplitRecommender.recommend(input: input)
        InjurySubstitutionEngine.apply(to: &recs, input: input)
        recommendations = recs
        isComputing = false
        currentStep = totalSteps + 1
    }

    var showResults: Bool { currentStep > totalSteps }

    func reset() {
        currentStep          = 1
        input                = SplitFinderInput()
        machineRating        = 3
        dumbbellRating       = 3
        barbellRating        = 3
        autoSelectEquipment  = false
        preferredStructure   = nil
        hasSport             = false
        sportFocusStep       = 0
        hasInjuries          = false
        selectedInjuries     = [:]
        hasWarmups           = false
        recommendations      = []
    }
}
