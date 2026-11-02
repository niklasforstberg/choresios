import SwiftUI

@main
struct ChoresApp: App {
    @State private var api = API.shared
    @State private var store = Store()

    init() {
        Theme.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(api)
                .environment(store)
        }
    }
}

struct RootView: View {
    @Environment(API.self) private var api
    @Environment(Store.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if !api.isLoggedIn {
                AuthView()
            } else if let me = store.me {
                // The account page is reachable before joining a household; nothing else is.
                if me.householdId == nil {
                    NavigationStack { NoHouseholdView().appToolbar() }
                } else {
                    MainTabs()
                }
            } else if let error = store.loadError {
                VStack(spacing: 16) {
                    ErrorText(error).multilineTextAlignment(.center)
                    Button(t("common.retry")) { Task { await store.load() } }.buttonStyle(.ghost)
                    Button(t("auth.logout")) { Task { await api.logout() } }.buttonStyle(.ghost)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.paper.ignoresSafeArea())
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.paper.ignoresSafeArea())
            }
        }
        .font(.app(17))
        .foregroundStyle(Theme.ink)
        .tint(Theme.pink)
        .task(id: api.isLoggedIn) {
            if api.isLoggedIn { await store.load() } else { store.reset() }
        }
        .onChange(of: scenePhase) { _, phase in
            // Someone else in the household may have ticked things off while the app was away.
            if phase == .active && api.isLoggedIn && store.me != nil { Task { await store.load() } }
        }
    }
}

struct MainTabs: View {
    var body: some View {
        TabView {
            NavigationStack { WeekView().appToolbar() }
                .tabItem { Label(t("nav.week"), systemImage: "square.and.pencil") }
            NavigationStack { HistoryView().appToolbar() }
                .tabItem { Label(t("nav.history"), systemImage: "chart.bar.xaxis") }
            NavigationStack { HouseholdView().appToolbar() }
                .tabItem { Label(t("nav.household"), systemImage: "house") }
        }
    }
}

// MARK: - Header

extension View {
    /// The web's header: the brand on the left, the user menu on the right.
    func appToolbar() -> some View { modifier(AppToolbar()) }
}

private struct AppToolbar: ViewModifier {
    @Environment(API.self) private var api
    @Environment(Store.self) private var store
    @State private var showAccount = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(t("common.appName")).font(.app(21, .bold)).tracking(-0.6).fixedSize()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if let me = store.me {
                            Section("\(me.name)\n\(me.email)") {}
                        }
                        Button { showAccount = true } label: { Label(t("menu.account"), systemImage: "person") }
                        Button(role: .destructive) { Task { await api.logout() } } label: {
                            Label(t("auth.logout"), systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Text(store.me.map { String($0.name.prefix(1)).uppercased() } ?? "?")
                            .font(.app(17, .bold))
                            .foregroundStyle(Theme.paper)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Theme.ink))
                    }
                    .accessibilityLabel(t("menu.open"))
                }
            }
            .toolbarBackground(Theme.paper, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAccount) {
                NavigationStack {
                    AccountView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button { showAccount = false } label: { Image(systemName: "xmark") }
                                    .accessibilityLabel(t("common.cancel"))
                            }
                        }
                        .toolbarBackground(Theme.paper, for: .navigationBar)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .font(.app(17))
                .foregroundStyle(Theme.ink)
                .tint(Theme.pink)
            }
    }
}
