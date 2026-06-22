import SwiftUI
import UIKit

struct AdminLoginSheet: View {
    @Environment(ADGSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var mode: AuthMode = .signIn
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isSigningIn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(session.isAuthenticated ? "Account" : "Sign In")
                .font(.largeTitle.bold())
                .tracking(0.3)
                .fixedSize(horizontal: false, vertical: true)

            if session.isAuthenticated {
                signedInContent
            } else {
                authForm
            }
        }
        .padding(ADGTheme.pagePadding)
        .background(ADGTheme.paper)
    }

    private var signedInContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(session.userEmail ?? "Signed in")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(session.isAdminAuthenticated ? "Admin mode active" : "Student account")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            Button {
                Task {
                    isSigningIn = true
                    await session.signOut()
                    isSigningIn = false
                    dismiss()
                }
            } label: {
                Text(isSigningIn ? "Signing Out" : "Sign Out")
                    .font(.callout.weight(.bold))
                    .tracking(1.1)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(ADGTheme.paper)
                    .background(ADGTheme.ink)
            }
            .accessibilityHint("Signs out of the current account.")
        }
    }

    private var authForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Mode", selection: $mode) {
                ForEach(AuthMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 12) {
                if mode == .signUp {
                    TextField("Full Name", text: $fullName)
                        .textInputAutocapitalization(.words)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(ADGTheme.surface)
                }

                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(ADGTheme.surface)

                SecureField("Password", text: $password)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(ADGTheme.surface)
            }

            if let authError = session.authError {
                Text(authError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task {
                    isSigningIn = true
                    if mode == .signIn {
                        await session.signIn(email: email, password: password)
                    } else {
                        await session.signUp(email: email, password: password, fullName: fullName)
                    }
                    isSigningIn = false
                    if session.isAuthenticated {
                        dismiss()
                    }
                }
            } label: {
                Text(isSigningIn ? "Please Wait" : mode.buttonTitle)
                    .font(.callout.weight(.bold))
                    .tracking(1.1)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(ADGTheme.paper)
                    .background(ADGTheme.ink)
            }
            .disabled(!isValid || isSigningIn)
            .accessibilityHint(mode == .signIn ? "Signs in with your account." : "Creates a student account.")
        }
        .onChange(of: session.authError) { _, error in
            if let error {
                UIAccessibility.post(notification: .announcement, argument: error)
            }
        }
    }

    private var isValid: Bool {
        if mode == .signUp && fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }

        return !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && password.count >= 6
    }
}

private enum AuthMode: String, CaseIterable, Identifiable {
    case signIn
    case signUp

    var id: String { rawValue }
    var title: String { self == .signIn ? "Sign In" : "Create Account" }
    var buttonTitle: String { self == .signIn ? "Sign In" : "Create Account" }
}
