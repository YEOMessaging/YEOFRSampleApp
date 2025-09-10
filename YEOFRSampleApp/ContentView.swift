//
//  ContentView.swift
//  YEOFRSampleApp
//
//  Created by paul calver on 22/08/2025.
//

import SwiftUI
import YEOFR

struct ContentView: View {
    @State private var showVideoStream = false
    
    var body: some View {
        VStack(spacing: 16) {
            Button("Live Video Stream") {
                showVideoStream = true
            }
        }
        .padding()
        .sheet(isPresented: $showVideoStream) {
            LiveVideoScreen()
        }
    }
}

#Preview {
    ContentView()
}
