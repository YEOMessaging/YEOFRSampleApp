//
//  GreenTickAnimation.swift
//  YEOFRSampleApp
//
//  Created by paul calver on 08/09/2025.
//

import SwiftUI

struct GreenTickAnimation: View {
    @Binding var isVisible: Bool
    
    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0.0
    
    var body: some View {
        ZStack {
            if isVisible {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 80, weight: .bold))
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .shadow(radius: 8)
                    .onAppear {
                        runAnimation()
                    }
            }
        }
        .allowsHitTesting(false) // so it doesn't block taps
    }
    
    private func runAnimation() {
        scale = 0.6
        opacity = 0.0
        
        // Animate in
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            scale = 1.0
            opacity = 1.0
        }
        
        // Optional overshoot bounce
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5).delay(0.2)) {
            scale = 1.1
        }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.8).delay(0.35)) {
            scale = 1.0
        }
        
        // Auto-hide after delay (optional)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                opacity = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isVisible = false
            }
        }
    }
}
