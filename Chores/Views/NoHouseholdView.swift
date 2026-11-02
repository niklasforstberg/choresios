import SwiftUI

/// Shown until the user creates or joins a household.
struct NoHouseholdView: View {
    @Environment(Store.self) private var store
    @State private var name = ""
    @State private var code = ""
    @State private var create = Action()
    @State private var join = Action()

    var body: some View {
        Page(refresh: { await store.load() }) {
            PageTitle(text: t("noHousehold.title"))
            Muted(t("noHousehold.intro"))

            Card {
                SectionTitle(text: t("noHousehold.createTitle"))
                Field(label: t("noHousehold.name")) {
                    TextField("", text: $name)
                }
                if let error = create.error { ErrorText(error) }
                Button(t("noHousehold.create")) {
                    create.run {
                        _ = try await API.shared.createHousehold(name: name)
                        await store.load()
                    }
                }
                .buttonStyle(.primaryWide)
                .disabled(create.isRunning || name.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Card {
                SectionTitle(text: t("noHousehold.joinTitle"))
                Field(label: t("noHousehold.code")) {
                    TextField("", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .tracking(2)
                }
                if let error = join.error { ErrorText(error) }
                Button(t("noHousehold.join")) {
                    join.run {
                        _ = try await API.shared.joinHousehold(code: code)
                        await store.load()
                    }
                }
                .buttonStyle(.primaryWide)
                .disabled(join.isRunning || code.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}
