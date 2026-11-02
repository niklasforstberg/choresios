import SwiftUI

private func parseTarget(_ s: String) -> Int? {
    Int(s.trimmingCharacters(in: .whitespaces))
}

struct HouseholdView: View {
    @Environment(Store.self) private var store
    @State private var name = ""
    @State private var target = ""
    @State private var add = Action()
    @State private var move = Action()

    var body: some View {
        Page(refresh: { await store.load() }) {
            if let household = store.household {
                PageTitle(text: household.name)

                Card {
                    SectionTitle(text: t("household.members"))
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(household.members) { m in Text(m.name).font(.app(17, .medium)) }
                    }
                    Muted(t("household.inviteHelp"))
                    Text(household.inviteCode)
                        .font(.app(33, .bold))
                        .tracking(4.6)
                        .foregroundStyle(Theme.blue)
                        .textSelection(.enabled)
                }

                Card {
                    SectionTitle(text: t("household.chores"))
                    Muted(t("household.choresHelp"))
                    VStack(spacing: 0) {
                        ForEach(Array(store.chores.enumerated()), id: \.element.id) { i, chore in
                            ChoreRow(chore: chore, first: i == 0, last: i == store.chores.count - 1) { dir in
                                reorder(i, dir)
                            }
                            .id(chore) // starts the row over once the saved chore comes back
                            DashedRule()
                        }
                    }
                    HStack(spacing: 8) {
                        TextField(t("household.choreName"), text: $name).appInput()
                        TextField(t("household.weeklyTargetShort"), text: $target)
                            .keyboardType(.numberPad)
                            .frame(width: 76)
                            .appInput()
                            .accessibilityLabel(t("household.weeklyTarget"))
                    }
                    Button(t("household.addChore")) {
                        add.run {
                            _ = try await API.shared.createChore(
                                name: name, weeklyTarget: parseTarget(target),
                                sortOrder: (store.chores.map(\.sortOrder).max() ?? -1) + 1)
                            name = ""
                            target = ""
                            await store.load()
                        }
                    }
                    .buttonStyle(.primary)
                    .disabled(add.isRunning || name.trimmingCharacters(in: .whitespaces).isEmpty)
                    if let error = add.error ?? move.error { ErrorText(error) }
                }
            }
        }
    }

    // Rewrites every position, so chores that share a sort order end up in a definite one.
    private func reorder(_ index: Int, _ dir: Int) {
        var order = store.chores
        order.swapAt(index, index + dir)
        move.run {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for (i, chore) in order.enumerated() where chore.sortOrder != i {
                    var updated = chore
                    updated.sortOrder = i
                    group.addTask { _ = try await API.shared.updateChore(updated) }
                }
                try await group.waitForAll()
            }
            await store.load()
        }
    }
}

private struct ChoreRow: View {
    @Environment(Store.self) private var store
    let chore: Chore
    let first: Bool
    let last: Bool
    let onMove: (Int) -> Void

    @State private var name: String
    @State private var target: String
    @State private var save = Action()
    @State private var confirmDelete = false

    init(chore: Chore, first: Bool, last: Bool, onMove: @escaping (Int) -> Void) {
        self.chore = chore
        self.first = first
        self.last = last
        self.onMove = onMove
        _name = State(initialValue: chore.name)
        _target = State(initialValue: chore.weeklyTarget.map(String.init) ?? "")
    }

    private var dirty: Bool { name != chore.name || parseTarget(target) != chore.weeklyTarget }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField(t("household.choreName"), text: $name).appInput()
                TextField("–", text: $target)
                    .keyboardType(.numberPad)
                    .frame(width: 76)
                    .appInput()
                    .accessibilityLabel(t("household.weeklyTarget"))
            }
            HStack(spacing: 4) {
                if dirty {
                    Button(t("common.save")) {
                        var updated = chore
                        updated.name = name
                        updated.weeklyTarget = parseTarget(target)
                        save.run {
                            _ = try await API.shared.updateChore(updated)
                            await store.load()
                        }
                    }
                    .buttonStyle(.primary)
                    .disabled(save.isRunning || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Spacer()
                Button { onMove(-1) } label: { Image(systemName: "arrow.up") }
                    .buttonStyle(.icon).disabled(first)
                    .accessibilityLabel(t("household.moveUp"))
                Button { onMove(1) } label: { Image(systemName: "arrow.down") }
                    .buttonStyle(.icon).disabled(last)
                    .accessibilityLabel(t("household.moveDown"))
                Button { confirmDelete = true } label: { Image(systemName: "trash") }
                    .buttonStyle(.icon)
                    .accessibilityLabel(t("household.deleteChore"))
            }
            if let error = save.error { ErrorText(error) }
        }
        .padding(.vertical, 10)
        .alert(t("household.confirmDelete", ["name": chore.name]), isPresented: $confirmDelete) {
            Button(t("household.deleteChore"), role: .destructive) {
                save.run {
                    try await API.shared.deleteChore(id: chore.id)
                    await store.load()
                }
            }
            Button(t("common.cancel"), role: .cancel) {}
        }
    }
}
