import Foundation

class ContentViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var error: String?
    @Published var familyMembers: [ChoreUser] = []
    @Published var chores: [Chore] = []
    @Published var selectedUser: ChoreUser?
    @Published var selectedChore: Chore?
    
    init() {
        // Check if we have a stored token
        if KeychainManager.shared.getToken() != nil {
            isLoggedIn = true
            Task {
                await loadInitialData()
            }
        }
    }
    
    func loadInitialData() async {
        // Load your family members and chores here
    }
    
    func logout() {
        KeychainManager.shared.deleteToken()
        isLoggedIn = false
    }
    
    func login(email: String, password: String) async {
        print("Login attempt with email: \(email)")  // Debug
        do {
            print("Calling NetworkManager.login")    // Debug
            let token = try await NetworkManager.shared.login(email: email, password: password)
            print("Got token: \(token)")            // Debug
            DispatchQueue.main.async {
                self.isLoggedIn = true
                self.error = nil
                print("Set isLoggedIn to true")     // Debug
            }
        } catch {
            print("Login error: \(error)")          // Debug
            DispatchQueue.main.async {
                self.error = error.localizedDescription
            }
        }
    }
    
    func submitChoreLog() async {
        // Implement the submission logic here
    }
}
