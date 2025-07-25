//
//  ContentView.swift
//
//  Created by Engin BULANIK on 25.08.2020.
//  Copyright © William Entriken
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var vm: FDSoundActivatedRecorderViewModel

    var body: some View {
        VStack(spacing: 16) {

            // MARK: – Controls
            Text("Auto‑saves after 10 seconds or when silence is detected.")

            Button("Start Listening")               { vm.pressedStartListening() }
                .controlStyle(background: .yellow)

            Button("Abort")                         { vm.pressedAbort() }
                .controlStyle(background: .red, fg: .white)

            Button("Play Saved File")               { vm.pressedPlay() }
                .controlStyle(background: .green,  fg: .white)
                .disabled(vm.savedURL == nil)

            // MARK: – Live level bar
            Text("Microphone level")
            ZStack(alignment: .leading) {
                Rectangle().fill(.gray)
                Rectangle()
                    .fill(vm.progressTintColor)          // <‑‑ dynamic colour
                    .frame(width: vm.progressBarLevel * vm.menuWidth)
            }
            .frame(width: vm.menuWidth, height: 10)
            Text(vm.microphoneLevelText)

            // MARK: – Waveform
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ForEach(vm.sampleSquares) { s in
                        VStack(spacing: 0) {
                            Spacer()
                            Rectangle()                  // current sample bar
                                .fill(s.color)
                                .frame(width: vm.graphSampleSize,
                                       height: s.value * geo.size.height)
                            Spacer(minLength: 0)
                        }
                        .overlay(                        // threshold marker
                            VStack(spacing: 0) {
                                Spacer()
                                Rectangle()
                                    .fill(s.thresholdColor)
                                    .frame(width: vm.graphSampleSize,
                                           height: s.thresholdValue * geo.size.height)
                                Spacer(minLength: 0)
                            }
                        )
                    }
                }
            }
            .frame(height: 150)
        }
        .padding()
    }
}

// MARK: – Helpers ------------------------------------------------------------

private extension Button {
    /// Sugar for uniform “pill” style buttons.
    func controlStyle(background bg: Color,
                      fg: Color = .black) -> some View {
        self.frame(width: 300)
            .padding()
            .background(bg)
            .foregroundColor(fg)
            .cornerRadius(20)
    }
}

// MARK: – Preview ------------------------------------------------------------

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(FDSoundActivatedRecorderViewModel())
            .previewLayout(.sizeThatFits)
    }
}
