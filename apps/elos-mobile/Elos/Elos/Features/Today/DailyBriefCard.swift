import SwiftUI

struct DailyBriefCard: View {
    @EnvironmentObject var vm: AppViewModel

    private var moodColor: Color {
        switch vm.dailyBrief.mood {
        case "positive": return .good
        case "alert":    return .bad
        default:         return .warn
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Daily Brief", systemImage: "sparkles")
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(moodColor)

            Text(vm.dailyBrief.text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(moodColor)
                .frame(width: 3)
                .padding(.vertical, 8)
        }
    }
}
