import SwiftUI

/// Done per member and chore, against the weekly target for the period, plus how many are still planned.
struct SummaryView: View {
    let chores: [Chore]
    let members: [HouseholdMember]
    let completions: [ChoreCompletion]
    var claims: [ChoreClaim] = []
    let weeks: Int // the target is per week, so it scales with the period

    var body: some View {
        let colors = Members.colors(members)
        let labels = Members.labels(members)

        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .center, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow(alignment: .bottom) {
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    ForEach(members) { m in
                        VStack(spacing: 4) {
                            MemberDot(label: labels[m.id] ?? "?", color: colors[m.id])
                            Text(m.name).font(.app(17, .semibold)).lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                }
                rule

                ForEach(chores) { chore in
                    let target = chore.weeklyTarget.map { $0 * weeks }
                    GridRow {
                        Text(chore.name).font(.app(17, .semibold)).lineLimit(1)
                            .gridColumnAlignment(.leading)
                            .padding(.leading, 16)
                            .padding(.trailing, 12)
                        ForEach(members) { m in
                            let done = count(completions, m.id, chore.id)
                            let planned = count(claims, m.id, chore.id)
                            let reached = target.map { done >= $0 } ?? false
                            HStack(spacing: 0) {
                                Text("\(done)" + (target.map { "/\($0)" } ?? ""))
                                    .font(.app(17, reached ? .bold : .medium))
                                    .foregroundStyle(reached ? Theme.pink : Theme.ink)
                                if planned > 0 { Text(" +\(planned)").foregroundStyle(Theme.muted) }
                            }
                            .monospacedDigit()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                    }
                    rule
                }

                GridRow {
                    Text(t("summary.total")).font(.app(17, .bold))
                        .gridColumnAlignment(.leading)
                        .padding(.leading, 16)
                    ForEach(members) { m in
                        Text("\(count(completions, m.id))").font(.app(17, .bold)).monospacedDigit()
                            .padding(.vertical, 10)
                    }
                }
            }
            .padding(.trailing, 4)
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.sheet))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var rule: some View {
        DashedRule().gridCellUnsizedAxes(.horizontal)
    }

    private func count(_ list: [some DayEntry], _ userId: Int, _ choreId: Int? = nil) -> Int {
        list.filter { $0.userId == userId && (choreId == nil || $0.choreId == choreId) }.count
    }
}
