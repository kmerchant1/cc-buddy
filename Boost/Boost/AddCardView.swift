//
//  AddCardView.swift
//  Boost
//
//  Created for AddCardView sheet
//

import SwiftUI

struct SearchableDropdown<T: Hashable & Comparable>: View {
    @Binding var selection: T
    let options: [T]
    let label: String
    @State private var isExpanded = false
    @State private var searchText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Selected value display - acts as dropdown toggle
            HStack {
                Text(label)
                    .foregroundColor(.gray)
                Spacer()
                Text(String(describing: selection))
                    .foregroundColor(.white)
                Image(systemName: "chevron.down")
                    .foregroundColor(.blue)
                    .rotationEffect(isExpanded ? .degrees(180) : .degrees(0))
                    .animation(.spring(), value: isExpanded)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    isExpanded.toggle()
                }
            }
            .padding(.vertical, 10)
            
            // Dropdown content
            if isExpanded {
                VStack {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search", text: $searchText)
                            .foregroundColor(.white)
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(8)
                    .padding(.vertical, 5)
                    
                    // Filtered options list
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredOptions, id: \.self) { option in
                                HStack {
                                    Text(String(describing: option))
                                        .foregroundColor(.white)
                                    Spacer()
                                    if option == selection {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 5)
                                .background(option == selection ? Color.purple.opacity(0.2) : Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selection = option
                                    withAnimation {
                                        isExpanded = false
                                    }
                                    searchText = ""
                                }
                            }
                        }
                    }
                    .frame(height: min(CGFloat(filteredOptions.count) * 44, 220))
                }
                .padding(.vertical, 5)
                .transition(.opacity)
            }
        }
        .background(Color.black.opacity(0.6))
    }
    
    var filteredOptions: [T] {
        if searchText.isEmpty {
            return options.sorted()
        } else {
            return options.filter {
                String(describing: $0).lowercased().contains(searchText.lowercased())
            }.sorted()
        }
    }
}

struct AddCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var cards: [Card]
    @ObservedObject private var walletManager = WalletManager.shared
    
    @State private var selectedBank = "Chase"
    @State private var selectedCardType = ""
    @State private var showDuplicateAlert = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    // Bank issuers
    let banks = ["Chase", "American Express", "Citi", "Capital One", "Bank of America", "Apple", "Discover", "U.S Bank", "Wells Fargo", "Synchrony", "Barclays"]
    
    // Card types mapped to banks - simplified names for better Firebase matching
    let cardTypes = [
        "Chase": ["Sapphire Preferred", "Freedom Unlimited", "Slate Edge", "Freedom Flex"],
        "American Express": ["Platinum", "Gold", "Green", "Blue Cash Preferred"],
        "Citi": ["Premier", "Diamond Preferred", "Custom Cash", "Double Cash", "Costco Anywhere Visa"],
        "Capital One": ["Venture X", "Venture", "SavorOne", "Quicksilver", "Spark Business"],
        "Bank of America": ["Premium Rewards", "Travel Rewards", "Cash Rewards", "Unlimited Cash Rewards"],
        "Apple": ["Card"],
        "Discover": ["Cash Back", "Miles", "Chrome", "Secured"],
        "U.S Bank": ["Altitude Reserve", "Altitude Connect", "Cash+", "Platinum"],
        "Wells Fargo": ["Active Cash", "Reflect", "Autograph", "Platinum"],
        "Synchrony": ["Premier", "Plus", "Preferred", "Secured"],
        "Barclays": ["Arrival Plus", "JetBlue Plus", "AAdvantage Aviator Red", "View"]
    ]
    
    // Function to extract just the card name without the issuer prefix
    private func extractCardName(_ fullCardType: String) -> String {
        // For cards that include the issuer name at the start, remove it
        // Example: "Amex Gold" becomes "Gold"
        let components = fullCardType.components(separatedBy: " ")
        
        // If the card type starts with the selected bank or an abbreviation
        if components.count > 1 && (
            components[0].lowercased() == selectedBank.lowercased() ||
            components[0] == "Amex" && selectedBank == "American Express"
        ) {
            // Return everything after the first word
            return components.dropFirst().joined(separator: " ")
        }
        
        return fullCardType
    }
    
    private func addCard() {
        isLoading = true
        
        // Adjust issuer for American Express to match Firebase
        var issuerForFirebase = selectedBank
        if selectedBank == "American Express" {
            issuerForFirebase = "Amex"
        }
        
        // Log information about the card being added
        print("➕ Adding new card to wallet:")
        print("   - Full card type: \(selectedCardType)")
        print("   - Issuer for Firebase: \(issuerForFirebase)")
        print("   - Name for Firebase: \(selectedCardType)")
        
        // Fetch the complete card data from Firebase
        FirebaseService.shared.fetchCardDetails(issuer: issuerForFirebase, cardType: selectedCardType) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let cardDetails):
                    print("✅ Successfully fetched card details from Firebase")
                    
                    // Convert to WalletCard and add to WalletManager
                    let walletCard = WalletCard.fromCardDetails(cardDetails)
                    self.walletManager.addCard(walletCard)
                    
                    // Track card addition analytics
                    UserAnalytics.shared.trackCardAdded(issuer: issuerForFirebase, cardType: selectedCardType)
                    
                    // Now update the user's card collection in Firestore
                    FirebaseService.shared.addCardToUserProfile(issuer: issuerForFirebase, cardName: selectedCardType) { updateResult in
                        DispatchQueue.main.async {
                            self.isLoading = false
                            
                            switch updateResult {
                            case .success:
                                print("✅ Successfully updated user's card collection in Firestore")
                            case .failure(let error):
                                print("⚠️ Failed to update user's card collection: \(error.localizedDescription)")
                                // The card is still added to local wallet, just not synced to Firebase
                            }
                            
                            // Dismiss the sheet
                            self.dismiss()
                        }
                    }
                    
                case .failure(let error):
                    // Create a basic card without rewards as fallback
                    let basicWalletCard = WalletCard(
                        issuer: issuerForFirebase,
                        cardType: selectedCardType,
                        rewards: [:],
                        imgURL: nil
                    )
                    
                    print("⚠️ Error fetching card details: \(error.localizedDescription)")
                    print("⚠️ Adding card with empty rewards as fallback")
                    
                    // Add card to WalletManager
                    self.walletManager.addCard(basicWalletCard)
                    
                    // Track card addition analytics
                    UserAnalytics.shared.trackCardAdded(issuer: issuerForFirebase, cardType: selectedCardType)
                    
                    // Now update the user's card collection in Firestore
                    FirebaseService.shared.addCardToUserProfile(issuer: issuerForFirebase, cardName: selectedCardType) { updateResult in
                        DispatchQueue.main.async {
                            self.isLoading = false
                            
                            switch updateResult {
                            case .success:
                                print("✅ Successfully updated user's card collection in Firestore")
                            case .failure(let updateError):
                                print("⚠️ Failed to update user's card collection: \(updateError.localizedDescription)")
                                // The card is still added to local wallet, just not synced to Firebase
                            }
                            
                            // Dismiss the sheet
                            self.dismiss()
                        }
                    }
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                Form {
                    Section(header: Text("Select Bank").foregroundColor(.white)) {
                        SearchableDropdown(selection: $selectedBank, 
                                          options: banks, 
                                          label: "Bank Issuer")
                            .onChange(of: selectedBank) { _, newValue in
                                if let firstCard = cardTypes[newValue]?.first {
                                    selectedCardType = firstCard
                                }
                            }
                    }
                    .listRowBackground(Color.black.opacity(0.6))
                    
                    Section(header: Text("Select Card").foregroundColor(.white)) {
                        SearchableDropdown(selection: $selectedCardType, 
                                          options: cardTypes[selectedBank] ?? [], 
                                          label: "Card Type")
                    }
                    .listRowBackground(Color.black.opacity(0.6))
                    
                    Section {
                        Button(action: addCard) {
                            HStack {
                                Text("Add Card")
                                    .frame(maxWidth: .infinity)
                                    .foregroundColor(.black)
                                
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding(.leading, 10)
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                        }
                        .listRowBackground(Color.black)
                        .disabled(isLoading)
                    }
                }
                .scrollContentBackground(.hidden)
                .onAppear {
                    // Set initial card type
                    if let firstCard = cardTypes[selectedBank]?.first {
                        selectedCardType = firstCard
                    }
                }
            }
            .navigationTitle("Add a Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .alert(isPresented: Binding<Bool>(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Alert(
                    title: Text("Error"),
                    message: Text(errorMessage ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    AddCardView(cards: .constant([Card.virtualCard]))
} 
 