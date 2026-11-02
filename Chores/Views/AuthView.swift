import SwiftUI

struct AuthView: View {
    var body: some View {
        NavigationStack { LoginView() }
            .tint(Theme.pink)
    }
}

private struct AuthPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) { content }
                .frame(maxWidth: 380, alignment: .leading)
                .padding(16)
                .padding(.top, 48)
                .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.paper.ignoresSafeArea())
    }
}

struct LoginView: View {
    @Environment(API.self) private var api
    @State private var email = ""
    @State private var password = ""
    @State private var action = Action()

    var body: some View {
        AuthPage {
            TwoInk(text: t("common.appName"), size: 80)
                .padding(.bottom, 12)
                .accessibilityAddTraits(.isHeader)
            Field(label: t("auth.email")) {
                TextField("", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Field(label: t("auth.password")) {
                SecureField("", text: $password)
                    .textContentType(.password)
                    .onSubmit(submit)
            }
            if let error = action.error { ErrorText(error) }
            Button(t("auth.login"), action: submit)
                .buttonStyle(.primaryWide)
                .disabled(action.isRunning || email.isEmpty || password.isEmpty)
                .padding(.top, 4)
            HStack(spacing: 4) {
                Muted(t("auth.noAccount"))
                NavigationLink(t("auth.register")) { RegisterView() }
                    .foregroundStyle(Theme.pink)
                    .underline()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func submit() {
        guard !email.isEmpty, !password.isEmpty else { return }
        action.run { try await api.login(email: email.trimmingCharacters(in: .whitespaces), password: password) }
    }
}

struct RegisterView: View {
    @Environment(API.self) private var api
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var action = Action()

    var body: some View {
        AuthPage {
            PageTitle(text: t("auth.register"))
            Field(label: t("auth.name")) {
                TextField("", text: $name).textContentType(.givenName)
            }
            Field(label: t("auth.email")) {
                TextField("", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Field(label: t("auth.password")) {
                SecureField("", text: $password).textContentType(.newPassword)
            }
            if let error = action.error { ErrorText(error) }
            Button(t("auth.register")) {
                action.run { try await api.register(name: name, email: email.trimmingCharacters(in: .whitespaces), password: password) }
            }
            .buttonStyle(.primaryWide)
            .disabled(action.isRunning || name.isEmpty || email.isEmpty || password.count < 8)
            .padding(.top, 4)
        }
        .toolbarBackground(Theme.paper, for: .navigationBar)
    }
}
