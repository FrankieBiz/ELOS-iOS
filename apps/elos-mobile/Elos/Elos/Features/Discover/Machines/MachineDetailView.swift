import SwiftUI
import Combine

// MARK: - Response types

private struct MachineDetailAPIResponse: Decodable {
    let id: String
    let name: String
    let slug: String
    let alternate_names: [String]
    let category: String
    let equipment_type: String
    let primary_muscles: [String]
    let secondary_muscles: [String]
    let movement_pattern: String?
    let description: String?
    let image_url: String?
    let tags: [String]
    let models: [MachineModelResponse]
    let exercises: [MachineExerciseResponse]
    let substitutions: [MachineSubstitutionResponse]
}

struct MachineModelResponse: Decodable {
    let id: String
    let brand_name: String
    let model_name: String?
    let setup_instructions: String?
    let adjustment_notes: String?
    let usage_steps: [String]
    let form_cues: [String]
    let common_mistakes: [String]
    let safety_notes: [String]
    let beginner_tips: [String]
    let advanced_tips: [String]
    let rep_range_rec: String?
    let notes: String?
}

struct MachineExerciseResponse: Decodable {
    let exercise_name: String
    let exercise_id: String?
    let notes: String?
}

struct MachineSubstitutionResponse: Decodable {
    let substitution_type: String?
    let notes: String?
    let substitute_machine_name: String?
    let substitute_machine_slug: String?
    let substitute_exercise_id: String?
}

// MARK: - View

struct MachineDetailView: View {
    let slug: String

    @State private var machine: MachineDetailAPIResponse?
    @State private var isLoading = false
    @State private var expandedModelID: String?
    @State private var favoritedExerciseIDs: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                } else if let m = machine {
                    headerCard(m)
                    muscleChipsCard(m)
                    if !m.models.isEmpty { brandsSection(m.models) }
                    if !m.exercises.isEmpty { exercisesCard(m.exercises) }
                    if !m.substitutions.isEmpty { substitutionsCard(m.substitutions) }
                } else {
                    Text("Could not load machine.").foregroundStyle(.secondary).padding(.top, 40)
                }
            }
            .padding(16)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(machine?.name ?? "Machine")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadMachine() }
    }

    private func loadMachine() async {
        isLoading = true
        defer { isLoading = false }
        machine = try? await ApiClient.shared.get("/machines/\(slug)") as MachineDetailAPIResponse
        expandedModelID = machine?.models.first?.id
    }

    // MARK: Cards

    private func headerCard(_ m: MachineDetailAPIResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(m.name).font(.title3).fontWeight(.bold)
                Spacer()
                Text(m.equipment_type.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption2).fontWeight(.semibold)
                    .foregroundStyle(Color.tint)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.tint.opacity(0.12))
                    .clipShape(Capsule())
            }
            if !m.alternate_names.isEmpty {
                Text("Also known as: " + m.alternate_names.joined(separator: ", "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let desc = m.description, !desc.isEmpty {
                Text(desc).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .elosCard()
    }

    private func muscleChipsCard(_ m: MachineDetailAPIResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !m.primary_muscles.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Primary Muscles").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(m.primary_muscles, id: \.self) { muscle in
                            Text(muscle.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption2).fontWeight(.semibold)
                                .foregroundStyle(Color.tint)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.tint.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                }
            }
            if !m.secondary_muscles.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Secondary").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(m.secondary_muscles, id: \.self) { muscle in
                            Text(muscle.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                }
            }
            if let pattern = m.movement_pattern, !pattern.isEmpty {
                HStack(spacing: 4) {
                    Text("Movement:").font(.caption).foregroundStyle(.secondary)
                    Text(pattern.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption).fontWeight(.semibold)
                }
            }
        }
        .padding(16)
        .elosCard()
    }

    private func brandsSection(_ models: [MachineModelResponse]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Brand Variations").font(.subheadline).fontWeight(.semibold)
            ForEach(models, id: \.id) { model in
                MachineModelCard(model: model, isExpanded: expandedModelID == model.id) {
                    expandedModelID = expandedModelID == model.id ? nil : model.id
                }
            }
        }
        .padding(16)
        .elosCard()
    }

    private func exercisesCard(_ exercises: [MachineExerciseResponse]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Exercises on This Machine").font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text("Tap ★ to save").font(.caption2).foregroundStyle(.secondary)
            }
            ForEach(exercises, id: \.exercise_name) { ex in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.good).font(.caption)
                    Text(ex.exercise_name).font(.subheadline)
                    Spacer()
                    if let id = ex.exercise_id {
                        Button {
                            Task { await toggleFavorite(exerciseID: id) }
                        } label: {
                            Image(systemName: favoritedExerciseIDs.contains(id) ? "star.fill" : "star")
                                .foregroundStyle(favoritedExerciseIDs.contains(id) ? .yellow : .secondary)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if let notes = ex.notes, !notes.isEmpty {
                    Text(notes).font(.caption).foregroundStyle(.secondary)
                        .padding(.leading, 20)
                }
            }
        }
        .padding(16)
        .elosCard()
    }

    private func toggleFavorite(exerciseID: String) async {
        struct OkResponse: Decodable { let ok: Bool }
        struct EmptyBody: Encodable {}
        if favoritedExerciseIDs.contains(exerciseID) {
            favoritedExerciseIDs.remove(exerciseID)
            _ = try? await ApiClient.shared.delete("/exercises/\(exerciseID)/favorite") as OkResponse
        } else {
            favoritedExerciseIDs.insert(exerciseID)
            _ = try? await ApiClient.shared.post("/exercises/\(exerciseID)/favorite", body: EmptyBody()) as OkResponse
        }
    }

    private func substitutionsCard(_ subs: [MachineSubstitutionResponse]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Substitutions").font(.subheadline).fontWeight(.semibold)
            ForEach(Array(subs.filter { $0.substitute_machine_name != nil }.enumerated()), id: \.offset) { _, sub in
                HStack {
                    Image(systemName: "arrow.2.squarepath")
                        .foregroundStyle(.secondary).font(.caption)
                    VStack(alignment: .leading, spacing: 2) {
                        if let name = sub.substitute_machine_name {
                            Text(name).font(.subheadline)
                        }
                        if let type_ = sub.substitution_type {
                            Text(type_.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .elosCard()
    }
}

// MARK: - Machine Model Card

private struct MachineModelCard: View {
    let model: MachineModelResponse
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Text(model.brand_name)
                        .font(.subheadline).fontWeight(.semibold).foregroundStyle(.primary)
                    if let modelName = model.model_name, !modelName.isEmpty {
                        Text("· \(modelName)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.vertical, 6)
                VStack(alignment: .leading, spacing: 10) {
                    if let setup = model.setup_instructions, !setup.isEmpty {
                        detailSection("Setup", text: setup)
                    }
                    if !model.usage_steps.isEmpty {
                        numberedList("How to Use", items: model.usage_steps)
                    }
                    if !model.form_cues.isEmpty {
                        bulletList("Form Cues", items: model.form_cues, color: .tint)
                    }
                    if !model.common_mistakes.isEmpty {
                        bulletList("Common Mistakes", items: model.common_mistakes, color: .bad)
                    }
                    if !model.beginner_tips.isEmpty {
                        bulletList("Beginner Tips", items: model.beginner_tips, color: .good)
                    }
                    if let rep = model.rep_range_rec, !rep.isEmpty {
                        HStack {
                            Text("Recommended:").font(.caption).foregroundStyle(.secondary)
                            Text(rep).font(.caption).fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func detailSection(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary).fontWeight(.semibold)
            Text(text).font(.caption).foregroundStyle(.primary)
        }
    }

    private func numberedList(_ title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary).fontWeight(.semibold)
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                HStack(alignment: .top, spacing: 6) {
                    Text("\(i + 1).").font(.caption2).foregroundStyle(.secondary).frame(width: 16)
                    Text(item).font(.caption).foregroundStyle(.primary)
                }
            }
        }
    }

    private func bulletList(_ title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary).fontWeight(.semibold)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Circle().fill(color).frame(width: 5, height: 5).padding(.top, 4)
                    Text(item).font(.caption).foregroundStyle(.primary)
                }
            }
        }
    }
}
