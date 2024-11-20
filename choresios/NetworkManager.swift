import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    private let baseURL = "http://10.0.0.107:7165"
    
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration,
                               delegate: SSLTrustingDelegate(),
                               delegateQueue: nil)
        return session
    }()
    
    private var jwtToken: String? {
        get { KeychainManager.shared.getToken() }
        set { 
            if let token = newValue {
                KeychainManager.shared.saveToken(token)
            } else {
                KeychainManager.shared.deleteToken()
            }
        }
    }
    
    func login(email: String, password: String) async throws -> String {
        let url = URL(string: "\(baseURL)/api/security/login")!
        print("Login URL: \(url)")  // Debug
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30  // Add timeout
        
        let loginRequest = LoginRequest(email: email, password: password)
        let jsonData = try JSONEncoder().encode(loginRequest)
        request.httpBody = jsonData
        print("Request body: \(String(data: jsonData, encoding: .utf8) ?? "")") // Debug
        
        do {
            print("Starting request...") // Debug
            let (data, response) = try await session.data(for: request)
            print("Got response!") // Debug
            print("Response: \(String(data: data, encoding: .utf8) ?? "")") // Debug
            print("Status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)") // Debug
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response type") // Debug
                throw NetworkError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                print("Bad status code: \(httpResponse.statusCode)") // Debug
                throw NetworkError.invalidResponse
            }
            
            // Parse JWT from response body
            let token = try JSONDecoder().decode(LoginResponse.self, from: data).token
            self.jwtToken = token
            return token
        } catch let error as URLError {
            print("URLError: \(error.code.rawValue), \(error.localizedDescription)") // Debug
            throw error
        } catch {
            print("Other error: \(error)") // Debug
            throw error
        }
    }
    
    private func authorizedRequest(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if let token = jwtToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
    
    func getFamilyMembers(familyId: Int) async throws -> [ChoreUser] {
        let url = URL(string: "\(baseURL)/api/family/\(familyId)/getfamilymembers")!
        let request = authorizedRequest(url)
        
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode([ChoreUser].self, from: data)
    }
    
    func getChores(familyId: Int) async throws -> [Chore] {
        let url = URL(string: "\(baseURL)/api/chore/getall/\(familyId)")!
        let request = authorizedRequest(url)
        
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode([Chore].self, from: data)
    }
}

struct LoginResponse: Codable {
    let token: String
}

enum NetworkError: Error {
    case invalidResponse
    case invalidToken
    case unauthorized
}
//TODO Remove this before deployment
class SSLTrustingDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, 
                    didReceive challenge: URLAuthenticationChallenge, 
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        
        completionHandler(.performDefaultHandling, nil)
    }
}
