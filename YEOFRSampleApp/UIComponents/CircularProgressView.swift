//
//  CircularProgressView.swift
//  YEOFRSampleApp
//
//  Created by paul calver on 08/09/2025.
//
import SwiftUI

struct CircularProgressView: View {
    /// 0.0 ... 1.0
    var progress: Double
    /// true -> green, false -> red
    var isGood: Bool
    /// Styling
    var lineWidth: CGFloat = 10
    var backgroundColor: Color = .secondary.opacity(0.2)
    var goodColor: Color = .green
    var badColor: Color = .red

    var clampedProgress: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)

            // Progress ring, starts at top (rotate -90°)
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    isGood ? goodColor : badColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.35), value: clampedProgress)
                .animation(.easeInOut(duration: 0.20), value: isGood)
        }
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(clampedProgress * 100)) percent")
        .aspectRatio(1, contentMode: .fit)
    }
}
