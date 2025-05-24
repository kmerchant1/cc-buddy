//
//  ProfileView.swift
//  Boost
//
//  Created for TabView example
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @State private var userEmail: String = "Loading..."
    @State private var totalCards: Int = 0
    @State private var isLoadingCards: Bool = true
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSigningOut = false
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                Text("Profile")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Email:")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text(userEmail)
                            .font(.body)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    
                    HStack {
                        Text("Total Cards:")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        if isLoadingCards {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("\(totalCards)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    
                    Button(action: {
                        signOut()
                    }) {
                        if isSigningOut {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                        } else {
                            Text("Sign Out")
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(10)
                        }
                    }
                    .disabled(isSigningOut)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            loadUserProfile()
            loadCardCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CardCountChanged"))) { _ in
            // Refresh card count when cards are added or deleted
            loadCardCount()
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func loadUserProfile() {
        // Get current user
        if let user = FirebaseService.shared.getCurrentAuthUser() {
            userEmail = user.email ?? "No email available"
        } else {
            userEmail = "Not signed in"
        }
    }
    
    private func loadCardCount() {
        isLoadingCards = true
        
        UserAnalytics.shared.fetchUserMetrics { result in
            DispatchQueue.main.async {
                isLoadingCards = false
                
                switch result {
                case .success(let metrics):
                    totalCards = metrics.totalCards
                    print("📊 ProfileView: Loaded card count: \(metrics.totalCards)")
                    
                case .failure(let error):
                    print("❌ ProfileView: Error loading card count: \(error.localizedDescription)")
                    // Fallback to counting cards in WalletManager
                    totalCards = WalletManager.shared.walletCards.filter { $0.issuer != "Virtual" }.count
                }
            }
        }
    }
    
    private func signOut() {
        isSigningOut = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let success = FirebaseService.shared.signOut()
            isSigningOut = false
            
            if !success {
                alertMessage = "Failed to sign out"
                showAlert = true
            }
        }
    }
}

#Preview {
    ProfileView()
        .preferredColorScheme(.dark)
} 