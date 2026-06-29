import SwiftUI
import Combine

// MARK: - Response types

struct SharedTemplateResponse: Decodable {
    let share_code: String
    let owner_name: String
    let template_name: String
    let exercises: [SharedTemplateExerciseResponse]
}

struct SharedTemplateExerciseResponse: Decodable {
    let exercise_name: String
    let exercise_id: String?
    let order_index: Int
    let target_sets: Int
    let target_reps: String
    let target_rpe: Double?
    let rest_seconds: Int
    let notes: String?
    let equipment_id: String?
    let equipment_dedupe_key: String?
    let equipment_brand_name: String?
}

// MARK: - State

enum ImportState: Equatable {
    case fetchingTemplate
    case idle(SharedTemplateResponse)
    case importing
    case success
    case error(String)

    static func == (lhs: ImportState, rhs: ImportState) -> Bool {
        switch (lhs, rhs) {
        case (.fetchingTemplate, .fetchingTemplate), (.importing, .importing), (.success, .success):
            return true
        case (.idle(let a), .idle(let b)):
            return a.share_code == b.share_code
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - ViewModel

@MainActor
class TemplateImportViewModel: ObservableObject {
    @Published var state: ImportState = .fetchingTemplate

    func fetchTemplate(shareCode: String) {
        state = .fetchingTemplate
        Task {
            do {
                let template: SharedTemplateResponse = try await ApiClient.shared.get(
                    "/templates/shared/\(shareCode)"
                )
                state = .idle(template)
            } catch ApiError.httpError(404, _) {
                state = .error("404")
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    func importTemplate(template: SharedTemplateResponse) {
        state = .importing
        Task {
            do {
                struct ExerciseRequest: Encodable {
                    let exercise_id: String?
                    let exercise_name: String
                    let order_index: Int
                    let target_sets: Int
                    let target_reps: String
                    let target_rpe: Double?
                    let rest_seconds: Int
                    let notes: String?
                    let equipment_id: String?
                    let equipment_dedupe_key: String?
                    let equipment_brand_name: String?
                }
                struct CreateRequest: Encodable {
                    let name: String
                    let exercises: [ExerciseRequest]
                }
                struct CreateResponse: Decodable { let id: String }

                let body = CreateRequest(
                    name: template.template_name,
                    exercises: template.exercises.map { ex in
                        ExerciseRequest(
                            exercise_id: ex.exercise_id,
                            exercise_name: ex.exercise_name,
                            order_index: ex.order_index,
                            target_sets: ex.target_sets,
                            target_reps: ex.target_reps,
                            target_rpe: ex.target_rpe,
                            rest_seconds: ex.rest_seconds,
                            notes: ex.notes,
                            equipment_id: ex.equipment_id,
                            equipment_dedupe_key: ex.equipment_dedupe_key,
                            equipment_brand_name: ex.equipment_brand_name
                        )
                    }
                )
                let _: CreateResponse = try await ApiClient.shared.post("/templates", body: body)
                state = .success
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }
}
