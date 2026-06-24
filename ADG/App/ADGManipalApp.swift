import SwiftUI
import Supabase

@main
struct ADGManipalApp: App {
    @State private var session = ADGSession()
    @State private var loadingProgress: Double = 0.0
    @State private var showSplash = true
    @State private var showResetPasswordScreen = false

    init() {
        URLCache.shared = URLCache(
            memoryCapacity: 60 * 1024 * 1024,
            diskCapacity: 250 * 1024 * 1024,
            diskPath: "adg-remote-images"
        )
    }

    var body: some Scene {
        WindowGroup {
            // 1. Base Container
            ZStack {
                Color.black.ignoresSafeArea()
                
                if showSplash {
                    SplashView(progress: loadingProgress)
                        .transition(.opacity)
                } else {
                    RootView()
                        .transition(.asymmetric(insertion: .opacity, removal: .identity))
                }
            }
            // 2. Move deep link listener to the container so it's active immediately on launch
            .onOpenURL { url in
                if url.scheme == "adgapp" && url.host == "reset-password" {
                    // Mark recovery flow and hand the URL to Supabase to establish the session
                    session.beginPasswordRecovery()
                    SupabaseProvider.shared.auth.handle(url)
                    
                    // If deep link arrives during splash, dismiss splash immediately
                    if showSplash {
                        showSplash = false
                    }
                    
                    // Trigger the password update sheet
                    showResetPasswordScreen = true
                }
            }
            // 3. Move the sheet here so it can display over the entire app structure
            .sheet(isPresented: $showResetPasswordScreen) {
                UpdatePasswordView(isPresented: $showResetPasswordScreen)
            }
            // ❌ REMOVED the .onChange modifier block that was causing the 'cannot find viewModel' error
            // 4. Global configurations
            .environment(session)
            .animation(.easeInOut(duration: 0.4), value: showSplash)
            .preferredColorScheme(.light)
            .task {
                await loadAppResources()
            }
        }
    }
    
    private func loadAppResources() async {
        try? await Task.sleep(for: .seconds(0.4))
        await MainActor.run { loadingProgress = 0.25 }
        
        try? await Task.sleep(for: .seconds(0.5))
        await MainActor.run { loadingProgress = 0.70 }
        
        try? await Task.sleep(for: .seconds(0.4))
        await MainActor.run { loadingProgress = 1.0 }
        
        try? await Task.sleep(for: .seconds(0.2))
        await MainActor.run {
            // Guard clause: If a deep link already forced-dismissed the splash screen,
            // don't toggle it again.
            if showSplash {
                showSplash = false
            }
        }
    }
}
