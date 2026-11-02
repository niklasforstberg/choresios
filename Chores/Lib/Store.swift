import Foundation
import Observation

/// What every screen needs: who I am, my household and its chores.
/// Each screen loads its own claims and completions.
@MainActor @Observable
final class Store {
    var me: UserMe?
    var household: Household?
    var chores: [Chore] = []
    var loadError: String?
    // Goes up on every load, so screens that key their own loading on it fetch again too.
    var revision = 0

    func load() async {
        let api = API.shared
        do {
            let me = try await api.getMe()
            if me.householdId != nil {
                async let household = api.getHousehold()
                async let chores = api.getChores()
                (self.household, self.chores) = try await (household, chores)
            } else {
                household = nil
                chores = []
            }
            self.me = me
            loadError = nil
            revision += 1
        } catch {
            if !Task.isCancelled && me == nil { loadError = error.localizedDescription }
        }
    }

    func reset() {
        me = nil
        household = nil
        chores = []
        loadError = nil
    }
}
