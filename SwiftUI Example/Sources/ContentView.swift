//
//  ContentView.swift
//  FDSoundActivatedRecorder-SwiftUI
//
//  Created by Engin BULANIK on 25.08.2020.
//  Copyright © 2020 William Entriken. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: FDSoundActivatedRecorderViewModel
    
    var body: some View {
        
        VStack(spacing: 10){
            Text("Recording times out after 10 seconds")
            Button(action: self.viewModel.pressedStartListening) {
                Text("startListening")
                    .frame(width: viewModel.menuWidth)
                    .padding()
                    .background(Color.yellow)
                    .foregroundColor(Color.white)
                    .cornerRadius(20)
            }
            
            Button(action: self.viewModel.pressedStartRecording) {
                Text("startRecording")
                    .frame(width: viewModel.menuWidth)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(Color.white)
                    .cornerRadius(20)
            }
            
            Button(action: self.viewModel.pressedStopAndSaveRecording) {
                Text("stopAndSaveRecording")
                    .frame(width: viewModel.menuWidth)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(Color.white)
                    .cornerRadius(20)
            }
            
            Button(action: self.viewModel.pressedAbort) {
                Text("abort")
                    .frame(width: viewModel.menuWidth)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(Color.white)
                    .cornerRadius(20)
            }
            
            // Mic level
            Text("Microphone level")
            Rectangle()
                .fill(Color.gray)
                .frame(width: self.viewModel.menuWidth, height: 10)
                .overlay(Rectangle()
                    .fill(Color.red)
                    .frame(width: self.viewModel.progressBarLevel * self.viewModel.menuWidth, height: 10))
                .frame(height: 20)
            
            Text(viewModel.microphoneLevel)
            
            Button(action: {
                // What to perform
                self.viewModel.pressedPlay()
            }) {
                // How the button looks like
                Text("play")
                    .frame(width: viewModel.menuWidth)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(Color.white)
                    .cornerRadius(20)
            }.disabled(self.viewModel.savedURL == nil)
            
            // Graph Animation
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Spacer()
                    ForEach(self.viewModel.sampleSquares, id: \.id) { sample in
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(sample.color)
                                .frame(width: self.viewModel.graphSampleSize, height: self.viewModel.graphSampleSize)
                            Spacer()
                                .frame(height: sample.value * geometry.size.height)
                        }.overlay(
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(sample.thresholdColor)
                                    .frame(width: self.viewModel.graphSampleSize, height: self.viewModel.graphSampleSize)
                                Spacer()
                                    .frame(height: sample.thresholdValue * geometry.size.height)
                            }
                        )
                    }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
