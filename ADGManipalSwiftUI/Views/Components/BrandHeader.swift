import SwiftUI

struct BrandHeader: View {
    var isSignedIn: Bool
    var isAdmin: Bool
    var onAccountTap: () -> Void = {}

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                Image("ADGLogo")
                    .resizable()
                    .frame(width: 55, height: 55)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Developers Group")
                        .font(.title2.weight(.bold))
                        .tracking(0.4)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("MIT Manipal")
                        .font(.caption.weight(.medium))
                        .tracking(2.4)
                        .textCase(.uppercase)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)

                Spacer()

                Button(action: onAccountTap) {
                    accountIcon
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accountAccessibilityLabel)
                .accessibilityHint(isSignedIn ? "Opens account options." : "Opens sign in and account creation.")
            }

            Rectangle()
                .fill(ADGTheme.ink)
                .frame(height: 1)
        }
        .padding(.horizontal, ADGTheme.pagePadding)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(ADGTheme.paper)
    }
    
    private var accountIcon: some View {
        Image(systemName: accountSymbolName)
            .font(.title2.weight(.semibold))
            .frame(width: 44, height: 44)
            .foregroundStyle(isSignedIn ? ADGTheme.paper : ADGTheme.ink)
            .background(
                Circle()
                    .fill(isSignedIn ? ADGTheme.ink : ADGTheme.surface)
            )
    }

    private var accountSymbolName: String {
        if isAdmin {
            return "checkmark.circle.fill"
        } else if isSignedIn {
            return "person.crop.circle.fill"
        } else {
            return "person.crop.circle"
        }
    }

    private var accountAccessibilityLabel: String {
        if isAdmin {
            return "Admin account signed in"
        } else if isSignedIn {
            return "Account signed in"
        } else {
            return "Sign in"
        }
    }
}
