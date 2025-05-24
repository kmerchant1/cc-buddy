//
//  CardView.swift
//  Boost
//
//  Created for Card UI
//

import SwiftUI
import Combine

struct CardView: View {
    let card: Card
    var onDelete: (() -> Void)?
    var showDeleteButton: Bool = true
    var buttonsAtTop: Bool = false // New parameter to control button position
    
    @State private var showingRewards = false
    @State private var rewards: [String: Int]?
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Card background - either image or gradient
            if let imgURL = card.imgURL, !imgURL.isEmpty {
                // Use remote image as background if available
                CardBackgroundImage(imageURL: imgURL)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(radius: 10)
            } else {
                // Fallback to gradient background
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: card.gradientColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)
                    .shadow(radius: 10)
            }
            
            // Card content with header and footer
            VStack(spacing: 0) {
                // Top section with buttons (if buttonsAtTop is true)
                if buttonsAtTop {
                    HStack {
                        // Card title can go on top left if needed
                        // Text("\(card.issuer) \(card.cardType)")
                        //     .font(.headline)
                        //     .fontWeight(.bold)
                        //     .foregroundColor(.white)
                        //     .padding(.leading, 20)
                        //     .padding(.top, 8)
                        //     .shadow(color: .black, radius: 2, x: 1, y: 1)
                        
                        Spacer()
                        
                        // Only show delete button, no info button
                        if showDeleteButton && onDelete != nil {
                            Button(action: {
                                onDelete?()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 24))
                                    .shadow(color: .black.opacity(0.5), radius: 1, x: 1, y: 1)
                            }
                            .padding(.trailing, 20)
                            .padding(.top, 8)
                        }
                    }
                }
                
                // Middle space
                Spacer()
                
                // Bottom section with delete button (if buttonsAtTop is false)
                if !buttonsAtTop {
                    HStack {
                        // Card title on the bottom left
                        // Text(card.cardType)
                        //     .font(.headline)
                        //     .fontWeight(.bold)
                        //     .foregroundColor(.white)
                        //     .padding(.leading, 20)
                        //     .padding(.bottom, 12)
                        //     .shadow(color: .black, radius: 2, x: 1, y: 1)
                        
                        Spacer()
                        
                        // Only show delete button, no info button
                        if showDeleteButton && onDelete != nil {
                            Button(action: {
                                onDelete?()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 24))
                                    .shadow(color: .black.opacity(0.5), radius: 1, x: 1, y: 1)
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 12)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 200)
            
            // Loading indicator overlay
            if isLoading {
                VStack {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding(.top, 12)
                            .padding(.trailing, 15)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: 200)
            }
        }
        // Make the entire card clickable for non-virtual cards
        .onTapGesture {
            if card.issuer != "Virtual" && !isLoading {
                fetchRewards()
            }
        }
        .sheet(isPresented: $showingRewards) {
            if let rewards = rewards, !rewards.isEmpty {
                RewardsView(rewards: rewards, cardName: card.cardType, issuer: card.issuer)
                    .presentationDetents([.fraction(0.5)]) // Half-screen presentation
            } else {
                Text("No rewards information available")
                    .padding()
                    .presentationDetents([.fraction(0.3)]) // Smaller presentation for no data
            }
        }
        .alert(item: Binding<CardError?>(
            get: { errorMessage != nil ? CardError(message: errorMessage!) : nil },
            set: { errorMessage = $0?.message }
        )) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func fetchRewards() {
        isLoading = true
        errorMessage = nil
        
        print("🔄 Finding rewards from local data for \(card.issuer) \(card.cardType)")
        
        // Use WalletManager to get the card from local data
        if let walletCard = WalletManager.shared.getCard(issuer: card.issuer, cardType: card.cardType) {
            DispatchQueue.main.async {
                isLoading = false
                
                // Convert Double rewards to Int to maintain compatibility with existing UI
                let intRewards = walletCard.rewards.mapValues { Int($0) }
                self.rewards = intRewards
                self.showingRewards = true
                
                print("✅ Found rewards locally for \(card.issuer) \(card.cardType)")
                print("📊 Rewards map contains \(intRewards.count) categories: \(intRewards.keys.joined(separator: ", "))")
            }
        } else {
            DispatchQueue.main.async {
                isLoading = false
                errorMessage = "Card data not found locally"
                print("⚠️ Card not found in WalletManager: \(card.issuer) \(card.cardType)")
            }
        }
    }
}

// Card background image view with remote loading and caching
/**
 * CardBackgroundImage
 * A component that displays a card's background image with proper styling.
 * 
 * Features:
 * - Loads and caches remote images using ImageLoader
 * - Applies a semi-transparent gradient overlay for better text visibility
 * - Maintains visual consistency when displaying card information over the image
 * 
 * @param imageURL The URL of the background image to display
 */
struct CardBackgroundImage: View {
    let imageURL: String
    
    var body: some View {
        RemoteImage(url: imageURL)
            .overlay(
                // Add semi-transparent gradient overlay for better text visibility
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.5),
                        Color.black.opacity(0.2),
                        Color.black.opacity(0.5)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}

// Helper for error alert
struct CardError: Identifiable {
    let id = UUID()
    let message: String
}

// Rewards view sheet
struct RewardsView: View {
    let rewards: [String: Int]
    let cardName: String
    let issuer: String
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("\(issuer) \(cardName) Rewards")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top)
                    
                    if rewards.isEmpty {
                        Text("No rewards information available")
                            .foregroundColor(.white)
                            .padding()
                    } else {
                        VStack(alignment: .leading, spacing: 15) {
                            // Dynamically display all reward categories, sorted by percentage in descending order
                            ForEach(rewards.sorted(by: { $0.value > $1.value }), id: \.key) { category, percentage in
                                RewardRow(category: formatCategoryName(category), percentage: percentage)
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(10)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitle("Card Rewards", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
        .preferredColorScheme(.dark)
    }
    
    // Format the category name to look nicer
    private func formatCategoryName(_ category: String) -> String {
        // Capitalize the first letter and format with spaces if needed
        let formattedName = category.prefix(1).uppercased() + category.dropFirst()
        return formattedName
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
    }
}

struct RewardRow: View {
    let category: String
    let percentage: Int
    
    var body: some View {
        HStack {
            Text(category)
                .foregroundColor(.white)
            
            Spacer()
            
            Text("\(percentage)%")
                .foregroundColor(.white)
                .fontWeight(.bold)
        }
    }
}

#Preview {
    VStack {
        CardView(
            card: Card(issuer: "Virtual", cardType: "Debit Card"),
            showDeleteButton: false
        )
        
        CardView(
            card: Card(issuer: "Visa", cardType: "Rewards Card"),
            onDelete: {},
            showDeleteButton: true,
            buttonsAtTop: true
        )
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
} 