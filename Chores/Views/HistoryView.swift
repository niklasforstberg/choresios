import SwiftUI

struct HistoryView: View {
    @Environment(Store.self) private var store
    @State private var weeks = 4
    @State private var completions: [ChoreCompletion]?
    @State private var error: String?

    // Whole weeks back to a Monday, this week included, so the weekly targets add up.
    private let periods = [(4, "history.weeks4"), (13, "history.months3"), (52, "history.months12")]

    private var fromDate: Date { Week.addDays(Week.monday(of: Date()), -7 * (weeks - 1)) }

    var body: some View {
        Page(refresh: { await store.load() }) {
            PageTitle(text: t("history.title"))
            HStack(spacing: 6) {
                ForEach(periods, id: \.0) { period in
                    if period.0 == weeks {
                        Button(t(period.1)) {}.buttonStyle(PrimaryButtonStyle())
                    } else {
                        Button(t(period.1)) { weeks = period.0 }
                            .buttonStyle(GhostButtonStyle(border: Theme.rule, minHeight: 40))
                    }
                }
            }
            Muted(t("history.since", ["date": Week.longFormatter.string(from: fromDate)]))
            if let error { ErrorText(error) }
            if store.chores.isEmpty {
                Muted(t("week.noChores"))
            } else if let completions, let household = store.household {
                SummaryView(chores: store.chores, members: household.members, completions: completions, weeks: weeks)
            }
        }
        .task(id: "\(weeks)|\(store.revision)") {
            do {
                completions = try await API.shared.getCompletions(from: Week.iso(fromDate), to: Week.today())
                error = nil
            } catch {
                if !Task.isCancelled { self.error = error.localizedDescription }
            }
        }
    }
}
