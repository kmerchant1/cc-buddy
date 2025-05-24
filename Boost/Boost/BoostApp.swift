//
//  BoostApp.swift
//  Boost
//
//  Created by Kaiden Merchant on 5/5/25.
//

import SwiftUI
import FirebaseCore

@main
struct BoostApp: App {
    // Initialize Firebase when the app starts
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
