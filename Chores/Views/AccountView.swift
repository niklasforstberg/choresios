import SwiftUI

struct AccountView: View {
    @Environment(Store.self) private var store

    var body: some View {
        Page(refresh: { await store.load() }) {
            if let me = store.me {
                PageTitle(text: t("menu.account"))
                ProfileForm(me: me)
                ColorPicker(me: me)
                PasswordForm()
            }
        }
    }
}

private struct ProfileForm: View {
    @Environment(Store.self) private var store
    let me: UserMe
    @State private var name: String
    @State private var email: String
    @State private var password = ""
    @State private var save = Action()

    init(me: UserMe) {
        self.me = me
        _name = State(initialValue: me.name)
        _email = State(initialValue: me.email)
    }

    private var emailChanged: Bool { email.trimmingCharacters(in: .whitespaces) != me.email }

    var body: some View {
        Card {
            SectionTitle(text: t("account.profile"))
            Field(label: t("auth.name")) {
                TextField("", text: $name).textContentType(.givenName)
            }
            Field(label: t("auth.email")) {
                TextField("", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            if emailChanged {
                Field(label: t("account.currentPassword"), hint: t("account.emailNeedsPassword")) {
                    SecureField("", text: $password).textContentType(.password)
                }
            }
            if let error = save.error { ErrorText(error) }
            if save.succeeded { SuccessText(t("account.saved")) }
            Button(t("common.save")) {
                save.run {
                    _ = try await API.shared.updateProfile(name: name, email: email, currentPassword: emailChanged ? password : nil)
                    password = ""
                    await store.load() // the member list shows names
                }
            }
            .buttonStyle(.primaryWide)
            .disabled(save.isRunning || name.isEmpty || email.isEmpty)
        }
        .onChange(of: name) { save.reset() }
        .onChange(of: email) { save.reset() }
    }
}

// A colour shown for someone else, chosen or handed out, isn't offered: picking it would change theirs.
private struct ColorPicker: View {
    @Environment(Store.self) private var store
    let me: UserMe
    @State private var save = Action()

    var body: some View {
        let members = store.household?.members ?? []
        let keys = Members.colorKeys(members)
        let labels = Members.labels(members)
        let current = keys[me.id] ?? me.color
        let owners = Dictionary(members.filter { $0.id != me.id }.map { (keys[$0.id]!, $0) }, uniquingKeysWith: { a, _ in a })

        Card {
            SectionTitle(text: t("account.color"))
            Muted(t("account.colorHelp"))
            FlowLayout(spacing: 10) {
                ForEach(Members.palette, id: \.key) { key, color in
                    let owner = owners[key]
                    let name = t("colors.\(key)")
                    Button {
                        save.run {
                            _ = try await API.shared.updateColor(key)
                            await store.load()
                        }
                    } label: {
                        ZStack {
                            Circle().fill(color.ink)
                            if current == key {
                                Image(systemName: "checkmark").font(.system(size: 18, weight: .bold))
                            } else if let owner {
                                Text(labels[owner.id] ?? "").font(.app(17, .bold))
                            }
                        }
                        .foregroundStyle(color.on)
                        .frame(width: 48, height: 48)
                        .padding(3)
                        .overlay(Circle().strokeBorder(current == key ? Theme.ink : .clear, lineWidth: 3).padding(-3))
                        .opacity(owner != nil && current != key ? 0.4 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(owner != nil || save.isRunning)
                    .accessibilityLabel(owner.map { t("account.colorTaken", ["color": name, "name": $0.name]) } ?? name)
                    .accessibilityAddTraits(current == key ? .isSelected : [])
                }
            }
            if me.color != nil {
                Button(t("account.colorAuto")) {
                    save.run {
                        _ = try await API.shared.updateColor(nil)
                        await store.load()
                    }
                }
                .buttonStyle(.ghost)
                .disabled(save.isRunning)
            }
            if let error = save.error { ErrorText(error) }
        }
    }
}

private struct PasswordForm: View {
    @State private var current = ""
    @State private var new = ""
    @State private var repeated = ""
    @State private var mismatch = false
    @State private var save = Action()

    var body: some View {
        Card {
            SectionTitle(text: t("account.changePassword"))
            Field(label: t("account.currentPassword")) {
                SecureField("", text: $current).textContentType(.password)
            }
            Field(label: t("account.newPassword")) {
                SecureField("", text: $new).textContentType(.newPassword)
            }
            Field(label: t("account.repeatPassword")) {
                SecureField("", text: $repeated).textContentType(.newPassword)
            }
            if mismatch { ErrorText(t("account.passwordMismatch")) }
            if let error = save.error { ErrorText(error) }
            if save.succeeded { SuccessText(t("account.passwordChanged")) }
            Button(t("account.changePassword")) {
                mismatch = new != repeated
                guard !mismatch else { return }
                save.run {
                    try await API.shared.changePassword(current: current, new: new)
                    current = ""
                    new = ""
                    repeated = ""
                }
            }
            .buttonStyle(.primaryWide)
            .disabled(save.isRunning || current.isEmpty || new.count < 8 || repeated.isEmpty)
        }
        .onChange(of: current) { if !current.isEmpty { save.reset() } }
        .onChange(of: new) { if !new.isEmpty { save.reset() } }
    }
}
