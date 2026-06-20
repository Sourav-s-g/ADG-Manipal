import SwiftUI

@main
struct ADGManipalApp: App {
    @State private var session = ADGSession()
    @State private var loadingProgress: Double = 0.0
    @State private var showSplash = true

    init() {
        URLCache.shared = URLCache(
            memoryCapacity: 60 * 1024 * 1024,
            diskCapacity: 250 * 1024 * 1024,
            diskPath: "adg-remote-images"
        )
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.ignoresSafeArea() // Keeps the underlying window jet black
                
                if showSplash {
                    SplashView(progress: loadingProgress)
                        .transition(.opacity) // Fade-out transition
                } else {
                    RootView()
                        .environment(session)
                        .transition(.asymmetric(insertion: .opacity, removal: .identity))
                }
            }
            .animation(.easeInOut(duration: 0.4), value: showSplash)
            .task {
                await loadAppResources()
            }
        }
    }
    
    private func loadAppResources() async {
        // Step 1: Logo faded in, start initializing sequence
        try? await Task.sleep(for: .seconds(0.4))
        await MainActor.run { loadingProgress = 0.25 }
        
        // Step 2: Initialize Supabase Auth Session
        // await session.checkCurrentAuthStatus()
        try? await Task.sleep(for: .seconds(0.5)) // Simulate auth/network delay
        await MainActor.run { loadingProgress = 0.70 }
        
        // Step 3: Prefetch minor configurations or local cache syncs
        try? await Task.sleep(for: .seconds(0.4))
        await MainActor.run { loadingProgress = 1.0 }
        
        // Step 4: Allow progress bar to visually fill completely, then drop splash
        try? await Task.sleep(for: .seconds(0.2))
        await MainActor.run {
            showSplash = false
        }
    }
}
