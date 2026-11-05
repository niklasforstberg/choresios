import SwiftUI

/// choresweb's Week page as it looks on a phone: one day at a time, picked from a strip of the week.
struct WeekView: View {
    @Environment(Store.self) private var store
    @State private var monday = Week.monday(of: Date())
    @State private var picked = Week.today()
    @State private var claims: [ChoreClaim] = []
    @State private var completions: [ChoreCompletion] = []
    @State private var loadedWeek: String?
    @State private var error: String?
    // The completion just made lands like a stamp; the rest of the week stays still.
    @State private var stamped: Int?

    private var weekStart: String { Week.iso(monday) }
    private var weekEnd: String { Week.iso(Week.addDays(monday, 6)) }

    var body: some View {
        Page(refresh: { await store.load() }) {
            if let me = store.me, let household = store.household {
                header
                if let error { ErrorText(error) }
                if store.chores.isEmpty {
                    Muted(t("week.noChores"))
                } else if loadedWeek == weekStart {
                    content(me: me, members: household.members)
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
        }
        .task(id: "\(weekStart)|\(store.revision)") { await load() }
    }

    private func load() async {
        do {
            async let c = API.shared.getClaims(from: weekStart, to: weekEnd)
            async let d = API.shared.getCompletions(from: weekStart, to: weekEnd)
            let (newClaims, newCompletions) = try await (c, d)
            claims = newClaims
            completions = newCompletions
            loadedWeek = weekStart
            error = nil
        } catch {
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }

    private func mutate(_ work: @escaping () async throws -> ChoreCompletion?) {
        Task {
            do {
                if let done = try await work() { stamped = done.id }
                error = nil
                await load()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: Header

    private var isThisWeek: Bool { weekStart == Week.iso(Week.monday(of: Date())) }

    private var header: some View {
        let number = Week.number(monday)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                PageTitle(text: t("week.title", ["number": number]))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button { goTo(Week.addDays(monday, -7)) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.icon)
                    .accessibilityLabel(t("week.previous"))
                Button { goTo(Week.addDays(monday, 7)) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.icon)
                    .accessibilityLabel(t("week.next"))
            }
            HStack {
                Muted(Week.rangeFormatter.string(from: monday, to: Week.addDays(monday, 6))).font(.app(17, .medium))
                Spacer()
                if !isThisWeek {
                    Button(t("week.thisWeek")) { goTo(Date()) }.buttonStyle(.ghost)
                }
            }
            .frame(minHeight: 36)
        }
    }

    private func goTo(_ date: Date) {
        monday = Week.monday(of: date)
    }

    // MARK: Day view

    @ViewBuilder
    private func content(me: UserMe, members: [HouseholdMember]) -> some View {
        let today = Week.today()
        let days = (0..<7).map { Week.addDays(monday, $0) }
        let inWeek = { (date: String) in date >= weekStart && date <= weekEnd }
        // The day shown: the one picked in this week, else today, else Monday.
        let day = inWeek(picked) ? picked : inWeek(today) ? today : weekStart
        let labels = Members.labels(members)
        let colors = Members.colors(members)
        let names = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.name) })

        HStack(spacing: 4) {
            ForEach(days, id: \.self) { d in
                let date = Week.iso(d)
                DayTab(weekday: Week.weekday(d), number: Week.calendar.component(.day, from: d),
                       selected: date == day, today: date == today) { picked = date }
            }
        }

        VStack(spacing: 0) {
            ForEach(Array(store.chores.enumerated()), id: \.element.id) { index, chore in
                if index > 0 { DashedRule() }
                row(chore: chore, day: day, today: today, me: me, members: members,
                    labels: labels, colors: colors, names: names)
            }
        }
        .padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.sheet))

        Muted(t("week.legendDay")).font(.app(15))

        SectionTitle(text: t("summary.title"))
        SummaryView(chores: store.chores, members: members, completions: completions, claims: claims, weeks: 1)
    }

    private func row(chore: Chore, day: String, today: String, me: UserMe, members: [HouseholdMember],
                     labels: [Int: String], colors: [Int: MemberColor], names: [Int: String]) -> some View {
        let onDay = { (e: any DayEntry) in e.choreId == chore.id && e.date == day }
        let myClaim = claims.first { onDay($0) && $0.userId == me.id }
        let myDone = completions.filter { $0.choreId == chore.id && $0.userId == me.id }.count
        // Done only once the day has come: by ticking off my claim, or straight away on a day that has passed.
        let canDo = myClaim != nil ? day <= today : day < today
        let dayCompletions = completions.filter(onDay)
        let dayClaims = claims.filter(onDay)

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                FlowLayout(spacing: 10) {
                    Text(chore.name).font(.app(21, .semibold)).tracking(-0.2)
                    if let target = chore.weeklyTarget, let color = colors[me.id] {
                        Quota(done: myDone, target: target, color: color.ink)
                    }
                }
                if !dayCompletions.isEmpty || !dayClaims.isEmpty {
                    FlowLayout(spacing: 5) {
                        ForEach(dayCompletions) { e in
                            completionChip(e, me: me, labels: labels, colors: colors, names: names)
                        }
                        ForEach(dayClaims) { e in
                            claimChip(e, me: me, today: today, labels: labels, colors: colors, names: names)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                if canDo {
                    Button(t("week.doneShort")) { markDone(chore.id, day, me.id) }
                        .buttonStyle(.primary)
                        .frame(minWidth: 84)
                } else {
                    Button(t("week.add")) { mutate { _ = try await API.shared.createClaim(choreId: chore.id, date: day); return nil } }
                        .buttonStyle(GhostButtonStyle(minHeight: 44))
                        .frame(minWidth: 84)
                }
                if day <= today {
                    Menu {
                        Section(t("week.pickDoneBy")) {
                            // Me first, as that's the usual pick.
                            ForEach(members.sorted { $0.id == me.id && $1.id != me.id }) { m in
                                Button(t("week.doneBy", ["name": m.id == me.id ? t("week.me") : m.name])) {
                                    markDone(chore.id, day, m.id)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 44, height: 44)
                            .overlay(Circle().strokeBorder(Theme.rule, lineWidth: 1.5))
                    }
                    .accessibilityLabel(t("week.pickDoneBy"))
                }
            }
        }
        .padding(.vertical, 14)
    }

    // Marking a member done ticks off their claim for the day if they have one.
    private func markDone(_ choreId: Int, _ date: String, _ userId: Int) {
        if let claim = claims.first(where: { $0.choreId == choreId && $0.date == date && $0.userId == userId }) {
            mutate { try await API.shared.completeClaim(id: claim.id) }
        } else {
            mutate { try await API.shared.createCompletion(choreId: choreId, date: date, userId: userId) }
        }
    }

    // MARK: Chips

    private func claimChip(_ e: ChoreClaim, me: UserMe, today: String, labels: [Int: String],
                           colors: [Int: MemberColor], names: [Int: String]) -> some View {
        let own = e.userId == me.id
        // Anyone may tick off a claim once its day has come, e.g. one its member forgot.
        let canTap = own || e.date <= today
        return Chip(label: labels[e.userId] ?? "?", color: colors[e.userId], done: false,
                    accessibility: "\(names[e.userId] ?? "") – \(t("week.planned"))",
                    onTap: canTap ? { mutate { try await API.shared.completeClaim(id: e.id) } } : nil,
                    tapEnabled: e.date <= today,
                    onRemove: own ? { mutate { try await API.shared.deleteClaim(id: e.id); return nil } } : nil)
    }

    private func completionChip(_ e: ChoreCompletion, me: UserMe, labels: [Int: String],
                                colors: [Int: MemberColor], names: [Int: String]) -> some View {
        let byOther = e.recordedById != e.userId
        let recordedBy = e.recordedById.flatMap { names[$0] } ?? "?"
        var description = "\(names[e.userId] ?? "") – \(t("week.done"))"
        if byOther { description += ", \(t("week.markedBy", ["name": recordedBy]))" }
        return Chip(label: labels[e.userId] ?? "?", color: colors[e.userId], done: true,
                    by: byOther ? t("week.by", ["label": e.recordedById.flatMap { labels[$0] } ?? "?"]) : nil,
                    stamp: e.id == stamped, accessibility: description,
                    onRemove: e.userId == me.id || e.recordedById == me.id
                        ? { mutate { try await API.shared.deleteCompletion(id: e.id); return nil } } : nil)
    }
}

// MARK: - Pieces

private struct DayTab: View {
    let weekday: String
    let number: Int
    let selected: Bool
    let today: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(weekday).font(.app(13.6))
                    .foregroundStyle(selected ? Theme.paper : today ? Theme.navy : Theme.muted)
                Text("\(number)").font(.app(21, .bold))
                    .foregroundStyle(selected ? (today ? Theme.todaySelected : Theme.paper) : today ? Theme.navy : Theme.ink)
            }
            .padding(.top, 8)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(selected ? Theme.ink : today ? Theme.sun : .clear))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The sheet's "×3" as three dots, filled as I do them.
private struct Quota: View {
    let done: Int
    let target: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<target, id: \.self) { i in
                Circle()
                    .strokeBorder(color, lineWidth: 1.5)
                    .background(Circle().fill(i < done ? color : .clear))
                    .frame(width: 10, height: 10)
            }
            if done > target {
                Text("+\(done - target)").font(.app(13.6, .bold)).foregroundStyle(color)
            }
        }
        .frame(height: 26)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(t("week.myWeek", ["done": done, "target": target]))
    }
}

/// One member on one chore and day. Planned is a pencilled ring; done is a filled dot of the member's ink.
private struct Chip: View {
    let label: String
    let color: MemberColor?
    let done: Bool
    var by: String?
    var stamp = false
    let accessibility: String
    var onTap: (() -> Void)?
    var tapEnabled = true
    var onRemove: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false

    var body: some View {
        let ink = color?.ink ?? Theme.muted
        HStack(spacing: 0) {
            if let onTap {
                Button(action: onTap) { main }
                    .buttonStyle(.plain)
                    .disabled(!tapEnabled)
                    .accessibilityLabel("\(accessibility). \(t("week.markDone"))")
            } else {
                main.accessibilityLabel(accessibility)
            }
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                        .padding(.leading, 3)
                        .padding(.trailing, 8)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(0.75)
                .accessibilityLabel(t("week.remove"))
            }
        }
        .font(.app(15, .bold))
        .foregroundStyle(done ? (color?.on ?? .white) : ink)
        .frame(height: 30)
        .background(Capsule().fill(done ? ink : .clear))
        .overlay(Capsule().strokeBorder(ink, style: StrokeStyle(lineWidth: 1.5, dash: done ? [] : [4, 3])))
        .scaleEffect(stamp && !landed ? 1.5 : 1)
        .rotationEffect(.degrees(stamp && !landed ? -8 : 0))
        .opacity(stamp && !landed ? 0 : 1)
        .onAppear {
            guard stamp && !reduceMotion else { landed = true; return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) { landed = true }
        }
    }

    private var main: some View {
        HStack(spacing: 2) {
            Text(label)
            if done { Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)) }
            if let by { Text(by).font(.app(12, .medium)).opacity(0.85).padding(.leading, 3) }
        }
        .padding(.horizontal, 7)
        .frame(minWidth: 28, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}
