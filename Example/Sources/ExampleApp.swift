//
//  ExampleApp.swift
//  Example
//
//  Created by William Entriken on 2025-07-25.
//

import SwiftUI

@main
struct ExampleApp: App {
    @StateObject private var vm = FDSoundActivatedRecorderViewModel()   // shared instance

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
        }
    }
}
