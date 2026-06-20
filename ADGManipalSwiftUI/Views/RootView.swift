import SwiftUI
import PhotosUI

struct RootView: View {
    @Environment(ADGSession.self) private var session
    @State private var selectedTab: ADGTab = .announcements
    @State private var showsAdminLogin = false

    var body: some View {
        VStack(spacing: 0) {
            BrandHeader(
                isSignedIn: session.isAuthenticated,
                isAdmin: session.isAdminAuthenticated,
                onAccountTap: { showsAdminLogin = true }
            )
            .onLongPressGesture(minimumDuration: 3.0) {
                showsAdminLogin = true
            }

            ADGSegmentedTabs(selectedTab: $selectedTab)
                .padding(.horizontal, ADGTheme.pagePadding)
                .padding(.top, 12)

            TabView(selection: $selectedTab) {
                // Tab 1: Updates
                AnnouncementsView()
                    .tag(ADGTab.announcements)

                // Tab 2: Events
                EventsView()
                    .tag(ADGTab.events)

                // Tab 3: About Us
                AboutUsView()
                    .tag(ADGTab.about)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(ADGTheme.paper)
        .safeAreaInset(edge: .bottom) {
            if session.isAdminAuthenticated {
                AdminStatusBar()
            }
        }
        .sheet(isPresented: $showsAdminLogin) {
            AdminLoginSheet()
                .presentationDetents([.height(430)])
                .presentationDragIndicator(.visible)
        }
    }
}

enum ADGTab: String, CaseIterable, Identifiable {
    case announcements = "Updates"
    case events = "Events"
    case about = "About Us"

    var id: String { rawValue }
}

private struct ADGSegmentedTabs: View {
    @Binding var selectedTab: ADGTab

    var body: some View {
        Picker("Main Section", selection: $selectedTab) {
            ForEach(ADGTab.allCases) { tab in
                Text(tab.rawValue)
                    .font(.caption.weight(.semibold))
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .backgroundStyle(.clear)
        .controlSize(.large)
        .padding(6)
        .frame(height: 58)
        .background(ADGTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct AdminStatusBar: View {
    @Environment(ADGSession.self) private var session

    var body: some View {
        HStack {
            Text("CMS CONTROL")
                .font(.caption2.bold())
                .tracking(1.6)
            Spacer()
            if let email = session.adminEmail ?? session.userEmail {
                Text(email)
                    .font(.caption2)
            }
            Button("Sign Out") {
                Task { await session.signOut() }
            }
            .font(.caption.weight(.semibold))
        }
        .foregroundStyle(ADGTheme.paper)
        .padding(.horizontal, ADGTheme.pagePadding)
        .frame(height: 42)
        .background(ADGTheme.ink)
    }
}
