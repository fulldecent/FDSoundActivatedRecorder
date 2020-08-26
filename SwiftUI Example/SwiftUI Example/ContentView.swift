//
//  ContentView.swift
//  FDSoundActivatedRecorder-SwiftUI
//
//  Created by Engin BULANIK on 25.08.2020.
//  Copyright © 2020 Engin BULANIK. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: FDSoundActivatedRecorderViewModel
    
    var body: some View {
        
        VStack(spacing: 10){
            Text("Note: Default time-out value is 10 seconds")
            Button(action: self.viewModel.pressedStartListening) {
                // How the button looks like
                Text("startListening")
                    .frame(width: viewModel.menuWidth)
                    .padding()
                    .background(Color(.lightGray))
                    .cornerRadius(40)
            }
            
            Button(action: self.viewModel.pressedStartRecording) {
                // How the button looks like
                Text("startRecording")
                    .frame(width: viewModel.menuWidth)
                    .padding()
                    .background(Color(.lightGray))
                    .cornerRadius(40)
            }
            
            Button(action: self.viewModel.pressedStopAndSaveRecording) {
                // How the button looks like
                Text("stopAndSaveRecording")
                    .frame(width: viewModel.menuWidth)
                    .padding()
                    .background(Color(.lightGray))
                    .cornerRadius(40)
            }
            
            Button(action: self.viewModel.pressedAbort) {
                // How the button looks like
                Text("abort")
                    .frame(width: viewModel.menuWidth)
                    .padding()
                    .background(Color(.lightGray))
                    .cornerRadius(40)
            }
            
            //Mic level
            Text("Microphone Level")
            Rectangle()
                .fill(Color.gray)
                .frame(width: self.viewModel.menuWidth, height: 5)
                .overlay(Rectangle()
                    .fill(Color.red)
                    .frame(width: self.viewModel.progressBarLevel * self.viewModel.menuWidth, height: 5))
                .frame(height: 20)
            
            Text(viewModel.microphoneLevel)
            
            Button(action: {
                // What to perform
                self.viewModel.pressedPlayBack()
            }) {
                // How the button looks like
                Text("playBack")
                    .frame(width: viewModel.menuWidth)
                    .padding()
                    .background(Color(.lightGray))
                    .cornerRadius(40)
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
