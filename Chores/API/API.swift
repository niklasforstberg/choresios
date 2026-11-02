import Foundation
import Observation

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Talks to choresapi. Stays logged in with a refresh token kept in the Keychain:
/// the JWT lives only in memory and is fetched again with it whenever it's missing or expired.
@MainActor @Observable
final class API {
    static let shared = API()

    private(set) var isLoggedIn: Bool

    @ObservationIgnored private var token: String?
    @ObservationIgnored private var refreshing: Task<Void, Error>?
    // CHORES_API_URL points a debug run at a local API, e.g. http://127.0.0.1:5072.
    @ObservationIgnored private let baseURL = ProcessInfo.processInfo.environment["CHORES_API_URL"]
        .flatMap(URL.init(string:)) ?? URL(string: "https://chores.forstberg.net")!

    private init() {
        isLoggedIn = Keychain.refreshToken != nil
    }

    // MARK: - Auth

    private struct TokenResponse: Decodable { let token: String; let refreshToken: String? }
    private struct RefreshBody: Encodable { let refreshToken: String }

    func login(email: String, password: String) async throws {
        struct Body: Encodable { let email: String; let password: String; let refreshToken = true }
        signIn(try decode(await data("POST", "/api/auth/login", Body(email: email, password: password), authorized: false)))
    }

    func register(name: String, email: String, password: String) async throws {
        struct Body: Encodable { let email: String; let password: String; let name: String; let refreshToken = true }
        signIn(try decode(await data("POST", "/api/auth/register", Body(email: email, password: password, name: name), authorized: false)))
    }

    func logout() async {
        if let refreshToken = Keychain.refreshToken {
            _ = try? await raw("POST", "/api/auth/logout", RefreshBody(refreshToken: refreshToken), authorized: false)
        }
        signOut()
    }

    private func signIn(_ response: TokenResponse) {
        token = response.token
        Keychain.refreshToken = response.refreshToken
        isLoggedIn = true
    }

    private func signOut() {
        token = nil
        Keychain.refreshToken = nil
        isLoggedIn = false
    }

    // Concurrent requests that find the JWT expired share one refresh.
    private func refresh() async throws {
        if let refreshing { return try await refreshing.value }
        let task = Task {
            defer { refreshing = nil }
            guard let refreshToken = Keychain.refreshToken else {
                signOut()
                throw APIError(message: "Unauthorized")
            }
            let (data, status) = try await raw("POST", "/api/auth/refresh", RefreshBody(refreshToken: refreshToken), authorized: false)
            // Only the server saying no logs out; being offline doesn't.
            if status == 401 {
                signOut()
                throw APIError(message: "Unauthorized")
            }
            try check(data, status)
            token = try decode(data, as: TokenResponse.self).token
        }
        refreshing = task
        try await task.value
    }

    // MARK: - Requests

    func get<T: Decodable>(_ path: String) async throws -> T {
        try decode(await data("GET", path, nil))
    }

    func send<T: Decodable>(_ method: String, _ path: String, _ body: (any Encodable)? = nil) async throws -> T {
        try decode(await data(method, path, body))
    }

    func send(_ method: String, _ path: String, _ body: (any Encodable)? = nil) async throws {
        _ = try await data(method, path, body)
    }

    private func data(_ method: String, _ path: String, _ body: (any Encodable)?, authorized: Bool = true) async throws -> Data {
        if authorized && token == nil { try await refresh() }
        var (data, status) = try await raw(method, path, body, authorized: authorized)
        if authorized && status == 401 {
            try await refresh()
            (data, status) = try await raw(method, path, body, authorized: authorized)
        }
        if status == 401 {
            if authorized { signOut() }
            throw APIError(message: authorized ? "Unauthorized" : t("auth.loginFailed"))
        }
        try check(data, status)
        return data
    }

    private func raw(_ method: String, _ path: String, _ body: (any Encodable)?, authorized: Bool) async throws -> (Data, Int) {
        var request = URLRequest(url: URL(string: path, relativeTo: baseURL)!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authorized, let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONEncoder().encode(body) }
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    private func check(_ data: Data, _ status: Int) throws {
        if (200..<300).contains(status) { return }
        // The API never answers 502–504 itself: that's Caddy or Cloudflare while a deploy runs.
        if (502...504).contains(status) { throw APIError(message: t("common.serverUnavailable")) }
        var text = String(decoding: data, as: UTF8.self)
        if let parsed = try? JSONDecoder().decode(String.self, from: data) { text = parsed }
        if text.trimmingCharacters(in: .whitespaces).hasPrefix("<") { text = "" } // an HTML error page
        throw APIError(message: text.isEmpty ? "HTTP \(status)" : text)
    }

    private func decode<T: Decodable>(_ data: Data, as type: T.Type = T.self) throws -> T {
        try JSONDecoder().decode(T.self, from: data)
    }
}
