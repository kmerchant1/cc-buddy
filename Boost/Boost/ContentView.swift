//
//  ContentView.swift
//  Boost
//
//  Created by Kaiden Merchant on 5/5/25.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @State private var isAuthenticated = false
    
    var body: some View {
        Group {
            if isAuthenticated {
                mainAppView
            } else {
                LoginView(isAuthenticated: $isAuthenticated)
                    .onAppear {
                        // Check if the user is already signed in
                        checkAuthStatus()
                    }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserDidSignOut"))) { _ in
            // Handle sign out notification
            isAuthenticated = false
        }
    }
    
    // Check if the user is already signed in
    private func checkAuthStatus() {
        if Auth.auth().currentUser != nil {
            isAuthenticated = true
            // Load the user's cards from Firebase
            WalletManager.shared.loadCardsFromFirebase()
        }
    }
    
    // Main app view with tabs
    private var mainAppView: some View {
        TabView {
            WalletView()
                .tabItem {
                    Label("Wallet", systemImage: "creditcard")
                }
            
            OffersView()
                .tabItem {
                    Label("Offers", systemImage: "tag")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Set the tab bar appearance to have a dark background
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.backgroundColor = UIColor.black
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    ContentView()
}
