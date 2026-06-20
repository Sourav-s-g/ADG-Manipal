//
//  SplashView.swift
//  ADG
//
//  Created by Sourav S Gaikwad on 07/06/26.
//

import SwiftUI

struct SplashView: View {
    let progress: Double
    
    @State private var logoOpacity: Double = 0
    @State private var progressScale: Double = 0.5
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            // 1. Absolute Center Layer for the Logo
            Image("ADGLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 180)
                .opacity(logoOpacity)
            
            // 2. Bottom Anchored Layer for the Progress Bar
            VStack {
                Spacer()
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(Color.white)
                            .frame(width: geo.size.width * CGFloat(progress), height: 4)
                            .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.8), value: progress)
                    }
                }
                .frame(width: 140, height: 4)
                .scaleEffect(progressScale)
                .opacity(logoOpacity)
                .padding(.bottom, 60) // Clean clearance from the bottom edge
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                logoOpacity = 1
                progressScale = 1.0
            }
        }
    }
}

#Preview {
    SplashView(progress: 0.4)
}
