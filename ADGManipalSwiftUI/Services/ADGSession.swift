import Foundation
import Observation
import Supabase

@MainActor
@Observable
final class ADGSession {
    var isAuthenticated = false
    var isAdminAuthenticated = false
    var userID: UUID?
    var userEmail: String?
    var adminEmail: String?
    var authError: String?

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseProvider.shared) {
        self.client = client
        Task { @MainActor in
            await self.refreshSession()
        }
    }

    func refreshSession() async {
        do {
            let session = try await client.auth.session
            apply(user: session.user)
        } catch {
            clearUser()
        }
    }

    func signIn(email: String, password: String) async {
        authError = nil
        do {
            let response = try await client.auth.signIn(email: email, password: password)
            apply(user: response.user)
        } catch {
            authError = error.localizedDescription
            clearUser()
        }
    }

    func signUp(email: String, password: String, fullName: String) async {
        authError = nil
        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: ["full_name": .string(fullName)]
            )
            apply(user: response.user)
        } catch {
            authError = error.localizedDescription
        }
    }

    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            authError = error.localizedDescription
        }
        clearUser()
    }

    private func apply(user: User) {
        let appRole = user.appMetadata["role"]?.stringValue
        let userRole = user.userMetadata["role"]?.stringValue
        let appIsAdmin = user.appMetadata["is_admin"]?.boolValue ?? false
        let userIsAdmin = user.userMetadata["is_admin"]?.boolValue ?? false
        let isAdmin = appRole == "admin" || userRole == "admin" || appIsAdmin || userIsAdmin

        userID = user.id
        userEmail = user.email
        adminEmail = isAdmin ? user.email : nil
        isAdminAuthenticated = isAdmin
        isAuthenticated = true
    }

    private func clearUser() {
        userID = nil
        userEmail = nil
        adminEmail = nil
        isAuthenticated = false
        isAdminAuthenticated = false
    }
    
    
}
