import Foundation

// Mirrors choresweb's src/api/: one section per domain.

struct UserMe: Codable, Equatable {
    let id: Int
    let email: String
    let name: String
    let role: String
    let householdId: Int?
    let color: String? // a key of Members.palette; nil picks a free one
}

struct HouseholdMember: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let color: String?
}

struct Household: Codable, Equatable {
    let id: Int
    let name: String
    let inviteCode: String
    let members: [HouseholdMember]
}

struct Chore: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
    var weeklyTarget: Int? // per member; nil for chores done when needed
    var sortOrder: Int
}

/// One member on one chore and day: a claim or a completion.
protocol DayEntry {
    var id: Int { get }
    var choreId: Int { get }
    var userId: Int { get }
    var date: String { get } // YYYY-MM-DD
}

// A claim takes a chore on today or a day to come.
struct ChoreClaim: Codable, Identifiable, DayEntry {
    let id: Int
    let choreId: Int
    let userId: Int
    let date: String
}

// A completion records one done today or earlier; any member may record it for another.
struct ChoreCompletion: Codable, Identifiable, DayEntry {
    let id: Int
    let choreId: Int
    let userId: Int
    let date: String
    let recordedById: Int? // nil once the member who recorded it has deleted their account
}

private struct SaveChore: Encodable {
    let name: String
    let weeklyTarget: Int?
    let sortOrder: Int
}

extension API {
    // MARK: Users

    func getMe() async throws -> UserMe { try await get("/api/users/me") }

    func updateProfile(name: String, email: String, currentPassword: String?) async throws -> UserMe {
        struct Body: Encodable { let name: String; let email: String; let currentPassword: String? }
        return try await send("PUT", "/api/users/me", Body(name: name, email: email, currentPassword: currentPassword))
    }

    func updateColor(_ color: String?) async throws -> UserMe {
        struct Body: Encodable {
            let color: String?
            // Sent as null rather than left out, to make "pick automatically" explicit.
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(color, forKey: .color)
            }
            enum CodingKeys: CodingKey { case color }
        }
        return try await send("PUT", "/api/users/me/color", Body(color: color))
    }

    func changePassword(current: String, new: String) async throws {
        // Our own refresh token stays valid; the API logs every other device out.
        struct Body: Encodable { let currentPassword: String; let newPassword: String; let refreshToken: String? }
        try await send("PUT", "/api/users/me/password", Body(currentPassword: current, newPassword: new, refreshToken: Keychain.refreshToken))
    }

    // MARK: Household

    func getHousehold() async throws -> Household { try await get("/api/household") }

    func createHousehold(name: String) async throws -> Household {
        struct Body: Encodable { let name: String }
        return try await send("POST", "/api/household", Body(name: name))
    }

    func joinHousehold(code: String) async throws -> Household {
        struct Body: Encodable { let inviteCode: String }
        return try await send("POST", "/api/household/join", Body(inviteCode: code))
    }

    // MARK: Chores

    func getChores() async throws -> [Chore] { try await get("/api/chores") }

    func createChore(name: String, weeklyTarget: Int?, sortOrder: Int) async throws -> Chore {
        try await send("POST", "/api/chores", SaveChore(name: name, weeklyTarget: weeklyTarget, sortOrder: sortOrder))
    }

    func updateChore(_ chore: Chore) async throws -> Chore {
        try await send("PUT", "/api/chores/\(chore.id)", SaveChore(name: chore.name, weeklyTarget: chore.weeklyTarget, sortOrder: chore.sortOrder))
    }

    func deleteChore(id: Int) async throws { try await send("DELETE", "/api/chores/\(id)") }

    // MARK: Claims and completions

    func getClaims(from: String, to: String) async throws -> [ChoreClaim] { try await get("/api/claims?from=\(from)&to=\(to)") }

    func createClaim(choreId: Int, date: String) async throws -> ChoreClaim {
        struct Body: Encodable { let choreId: Int; let date: String }
        return try await send("POST", "/api/claims", Body(choreId: choreId, date: date))
    }

    // Returns the completion that replaces the claim.
    func completeClaim(id: Int) async throws -> ChoreCompletion { try await send("POST", "/api/claims/\(id)/complete") }

    func deleteClaim(id: Int) async throws { try await send("DELETE", "/api/claims/\(id)") }

    func getCompletions(from: String, to: String) async throws -> [ChoreCompletion] {
        try await get("/api/completions?from=\(from)&to=\(to)")
    }

    func createCompletion(choreId: Int, date: String, userId: Int) async throws -> ChoreCompletion {
        struct Body: Encodable { let choreId: Int; let date: String; let userId: Int }
        return try await send("POST", "/api/completions", Body(choreId: choreId, date: date, userId: userId))
    }

    func deleteCompletion(id: Int) async throws { try await send("DELETE", "/api/completions/\(id)") }
}
