import Foundation

struct LoginRequest: Codable {
    let email: String
    let password: String
    
    enum CodingKeys: String, CodingKey {
        case email
        case password
    }
}

struct ChoreUser: Codable {
    let id: Int
    let firstName: String?
    let lastName: String?
    let email: String?
}

struct Chore: Codable {
    let id: Int?
    let name: String?
    let description: String?
}

struct ChoreLogRequest: Codable {
    let choreId: Int
    let userId: Int
    let completedDate: Date
    let reportedByUserId: Int
}
