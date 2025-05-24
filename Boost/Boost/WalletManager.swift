//
//  WalletManager.swift
//  Boost
//
//  Created for Wallet Management
//

import Foundation
import SwiftUI
import FirebaseFirestore

// Complete card data model with rewards
struct WalletCard: Identifiable, Equatable, Codable {
    let id = UUID()
    let issuer: String
    let cardType: String
    let userName: String = ""
    let rewards: [String: Double]
    let imgURL: String? // Add imgURL property for card background image
    
    // For compatibility with existing Card model
    var gradientColors: [Color] {
        switch issuer.lowercased() {
        case "american express", "amex":
            return [Color.black, Color.yellow, Color.yellow.opacity(0.7)]
        case "citi":
            return [Color.black, Color.green.opacity(0.8)]
        case "chase":
            return [Color.black, Color.blue.opacity(0.8)]
        case "discover":
            return [Color.black, Color.orange.opacity(0.8)]
        case "capital one":
            return [Color.black, Color.red.opacity(0.8)]
        case "bank of america":
            return [Color.black, Color.red.opacity(0.6), Color.blue.opacity(0.8)]
        case "u.s bank":
            return [Color.black, Color.red.opacity(0.6), Color.blue.opacity(0.8)]
        case "wells fargo":
            return [Color.black, Color.red.opacity(0.7), Color.yellow.opacity(0.8)]
        case "synchrony":
            return [Color.black, Color.blue.opacity(0.4)]
        case "barclays":
            return [Color.black, Color.blue.opacity(0.4)]
        default:
            return [Color.black, Color.gray.opacity(0.8)]
        }
    }
    
    static func == (lhs: WalletCard, rhs: WalletCard) -> Bool {
        return lhs.issuer == rhs.issuer && lhs.cardType == rhs.cardType
    }
    
    // Virtual card factory method
    static let virtualCard = WalletCard(issuer: "Virtual", cardType: "Debit Card", rewards: [:], imgURL: nil)
    
    // Convert from CardDetails to WalletCard
    static func fromCardDetails(_ cardDetails: CardDetails) -> WalletCard {
        // Convert Int rewards to Double
        let doubleRewards = cardDetails.rewards.mapValues { Double($0) }
        
        return WalletCard(
            issuer: cardDetails.issuer,
            cardType: cardDetails.name,
            rewards: doubleRewards,
            imgURL: cardDetails.imgURL
        )
    }
}

// Category mapping between UI display names and database keys
struct CategoryMapping {
    static let mappings: [String: [String]] = [
        "Restaurants": ["dining", "restaurant", "restaurants", "food"],
        "Groceries": ["groceries"],
        "Drugstore": ["drugstore", "pharmacy", "pharmacies", "health"],
        "Gas": ["gas", "fuel", "gasoline", "petrol"],
        "Transit": ["transit"]
    ]
    
    // Get all possible database keys for a category display name
    static func getDatabaseKeys(for category: String) -> [String] {
        return mappings[category] ?? [category.lowercased()]
    }
}

// Singleton manager to maintain the wallet list
class WalletManager: ObservableObject {
    static let shared = WalletManager()
    
    @Published var walletCards: [WalletCard] = [WalletCard.virtualCard] {
        didSet {
            saveWalletCards()
        }
    }
    @Published var selectedCategory: String? = nil // Track selected category
    
    private let walletCardsKey = "walletCards"
    private let userDefaults = UserDefaults.standard
    
    private init() {
        // Load saved cards from UserDefaults
        loadWalletCards()
        print("🔄 WalletManager initialized with \(walletCards.count) cards")
        
        // Add observer for user sign out to clear cards
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserSignOut),
            name: NSNotification.Name("UserDidSignOut"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // Handle user sign out by clearing all non-virtual cards
    @objc private func handleUserSignOut() {
        print("🔄 User signed out, clearing wallet cards")
        clearCards()
    }
    
    // Clear all cards except the virtual card
    func clearCards() {
        walletCards = [WalletCard.virtualCard]
        saveWalletCards()
        print("🧹 Cleared all cards from wallet except virtual card")
    }
    
    // Load user's cards from Firebase based on userCards array in Firestore
    func loadCardsFromFirebase() {
        print("📲 Loading cards from Firebase")
        
        // First, clear existing cards but keep virtual card
        clearCards()
        
        // Check if user is authenticated
        guard let userId = FirebaseService.shared.getCurrentAuthUser()?.uid else {
            print("⚠️ No authenticated user, keeping only virtual card")
            return
        }
        
        // Get the user profile to access userCards array
        FirebaseService.shared.fetchUserProfile(uid: userId) { [weak self] result in
            switch result {
            case .success(let userProfile):
                print("✅ Fetched user profile with \(userProfile.userCards.count) cards")
                
                // Load each card reference from Firestore
                let group = DispatchGroup()
                var loadedCards: [WalletCard] = []
                
                for cardId in userProfile.userCards {
                    group.enter()
                    
                    // Parse the card ID to get issuer and card type
                    let components = cardId.split(separator: "_")
                    if components.count >= 2 {
                        // The first component is the issuer, the rest combined is the card type
                        var issuer = String(components[0])
                        let cardType = components.dropFirst().joined(separator: " ")
                        
                        // Special handling for Capital One
                        if issuer == "capital" && components.count > 1 && components[1] == "one" {
                            issuer = "Capital One"
                            let cardTypeComponents = components.dropFirst(2)
                            let cardType = cardTypeComponents.joined(separator: " ")
                            
                            // Capitalize first letter of each word for display
                            let formattedCardType = cardType.split(separator: "_")
                                                         .map { String($0).capitalized }
                                                         .joined(separator: " ")
                            
                            print("🔍 Loading Capital One card: \(formattedCardType)")
                            
                            // Fetch card details from Firebase
                            FirebaseService.shared.fetchCardDetails(issuer: issuer, cardType: formattedCardType) { cardResult in
                                defer { group.leave() }
                                
                                switch cardResult {
                                case .success(let cardDetails):
                                    let walletCard = WalletCard.fromCardDetails(cardDetails)
                                    loadedCards.append(walletCard)
                                    print("✅ Successfully loaded card: \(walletCard.issuer) \(walletCard.cardType)")
                                    
                                case .failure(let error):
                                    print("⚠️ Failed to load card \(cardId): \(error.localizedDescription)")
                                    
                                    // Create a basic card as fallback
                                    let basicCard = WalletCard(
                                        issuer: issuer,
                                        cardType: formattedCardType,
                                        rewards: [:],
                                        imgURL: nil
                                    )
                                    loadedCards.append(basicCard)
                                    print("⚠️ Created fallback card: \(issuer) \(formattedCardType)")
                                }
                            }
                            continue
                        }
                        
                        // Regular card handling for non-Capital One cards
                        // Capitalize first letter of each word for display
                        let formattedIssuer = issuer.capitalized
                        let formattedCardType = cardType.split(separator: "_")
                                                     .map { String($0).capitalized }
                                                     .joined(separator: " ")
                        
                        print("🔍 Loading card: \(formattedIssuer) \(formattedCardType)")
                        
                        // Fetch card details from Firebase
                        FirebaseService.shared.fetchCardDetails(issuer: formattedIssuer, cardType: formattedCardType) { cardResult in
                            defer { group.leave() }
                            
                            switch cardResult {
                            case .success(let cardDetails):
                                let walletCard = WalletCard.fromCardDetails(cardDetails)
                                loadedCards.append(walletCard)
                                print("✅ Successfully loaded card: \(walletCard.issuer) \(walletCard.cardType)")
                                
                            case .failure(let error):
                                print("⚠️ Failed to load card \(cardId): \(error.localizedDescription)")
                                
                                // Create a basic card as fallback
                                let basicCard = WalletCard(
                                    issuer: formattedIssuer,
                                    cardType: formattedCardType,
                                    rewards: [:],
                                    imgURL: nil
                                )
                                loadedCards.append(basicCard)
                                print("⚠️ Created fallback card: \(formattedIssuer) \(formattedCardType)")
                            }
                        }
                    } else {
                        print("⚠️ Invalid card ID format: \(cardId)")
                        group.leave()
                    }
                }
                
                // When all cards are loaded, update the wallet
                group.notify(queue: .main) {
                    guard let self = self else { return }
                    
                    // Add the loaded cards to the wallet (keeping the virtual card)
                    for card in loadedCards {
                        if !self.walletCards.contains(where: { $0.issuer == card.issuer && $0.cardType == card.cardType }) {
                            self.walletCards.append(card)
                        }
                    }
                    
                    print("🎉 Finished loading \(loadedCards.count) cards from Firebase")
                }
                
            case .failure(let error):
                print("❌ Failed to fetch user profile: \(error.localizedDescription)")
            }
        }
    }
    
    // Save wallet cards to UserDefaults
    private func saveWalletCards() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(walletCards)
            UserDefaults.standard.set(data, forKey: walletCardsKey)
            print("💾 Saved \(walletCards.count) cards to local storage")
        } catch {
            print("❌ Error saving wallet cards: \(error.localizedDescription)")
        }
    }
    
    // Load wallet cards from UserDefaults
    private func loadWalletCards() {
        if let data = UserDefaults.standard.data(forKey: walletCardsKey) {
            do {
                let decoder = JSONDecoder()
                let cards = try decoder.decode([WalletCard].self, from: data)
                // Make sure we always have at least the virtual card
                if cards.isEmpty || !cards.contains(where: { $0.issuer == "Virtual" && $0.cardType == "Debit Card" }) {
                    walletCards = [WalletCard.virtualCard]
                } else {
                    walletCards = cards
                }
                print("📱 Loaded \(walletCards.count) cards from local storage")
            } catch {
                print("❌ Error loading wallet cards: \(error.localizedDescription)")
                walletCards = [WalletCard.virtualCard]
            }
        } else {
            // Initialize with just the virtual card if no saved data
            walletCards = [WalletCard.virtualCard]
            print("ℹ️ No saved cards found, initializing with virtual card")
        }
    }
    
    // Add a card to the wallet list
    func addCard(_ card: WalletCard) {
        // Check if the card already exists
        if !walletCards.contains(card) {
            walletCards.append(card)
            print("✅ Added card to wallet: \(card.issuer) \(card.cardType)")
            
            // Print the rewards map
            if !card.rewards.isEmpty {
                print("   Rewards: \(formatRewardsMap(card.rewards))")
            } else {
                print("   No rewards data available")
            }
            
            // Save changes to UserDefaults
            saveWalletCards()
        } else {
            print("⚠️ Card already exists in wallet: \(card.issuer) \(card.cardType)")
        }
    }
    
    // Find the best card for a given category
    func findBestCard(for category: String) -> (WalletCard, Double)? {
        print("🔍 Finding best card for category: \(category)")
        
        // Get all possible database keys for this category
        let possibleKeys = CategoryMapping.getDatabaseKeys(for: category)
        print("   Possible keys in database: \(possibleKeys.joined(separator: ", "))")
        
        var bestCard: WalletCard? = nil
        var bestMultiplier: Double = 0.0
        var usingOtherCategory = false
        
        // Check each card in the wallet
        for card in walletCards {
            // Skip the virtual card
            if card.issuer == "Virtual" { continue }
            
            // Look for the highest reward multiplier among possible keys
            var foundSpecificCategory = false
            for key in possibleKeys {
                // Use case-insensitive key comparison
                for (rewardKey, multiplier) in card.rewards {
                    if rewardKey.lowercased() == key.lowercased() && multiplier > bestMultiplier {
                        bestCard = card
                        bestMultiplier = multiplier
                        foundSpecificCategory = true
                        usingOtherCategory = false
                        print("   Found new best: \(card.issuer) \(card.cardType) with \(multiplier)x for \(rewardKey)")
                    }
                }
            }
            
            // If no specific category match, check the 'other' category as fallback
            if !foundSpecificCategory {
                // Look for 'other' category (case insensitive)
                for (rewardKey, multiplier) in card.rewards {
                    if rewardKey.lowercased() == "other" {
                        // Only use 'other' if we don't have a specific category match already
                        // or if this 'other' is better than our current best 'other'
                        if (!usingOtherCategory && bestCard == nil) || (usingOtherCategory && multiplier > bestMultiplier) {
                            bestCard = card
                            bestMultiplier = multiplier
                            usingOtherCategory = true
                            print("   Using fallback 'other' category: \(card.issuer) \(card.cardType) with \(multiplier)x")
                        }
                    }
                }
            }
        }
        
        // Return the best card and its multiplier if found
        if let card = bestCard {
            if usingOtherCategory {
                print("   ⚠️ No specific category match found. Using 'other' category.")
            }
            return (card, bestMultiplier)
        }
        
        print("   No cards found with rewards for this category or 'other' category")
        return nil
    }
    
    // Format rewards map for logging
    private func formatRewardsMap(_ rewards: [String: Double]) -> String {
        let formatted = rewards.map { "\($0.key): \($0.value)x" }.joined(separator: ", ")
        return "{\(formatted)}"
    }
    
    // Get a card by issuer and cardType
    func getCard(issuer: String, cardType: String) -> WalletCard? {
        print("🔍 Finding card: \(issuer) \(cardType)")
        return walletCards.first { 
            $0.issuer.lowercased() == issuer.lowercased() && 
            $0.cardType.lowercased() == cardType.lowercased() 
        }
    }
    
    // Delete a card from the wallet
    func deleteCard(issuer: String, cardType: String) -> Bool {
        print("🗑️ Attempting to delete card: \(issuer) \(cardType)")
        
        // Don't allow deleting the virtual card
        if issuer.lowercased() == "virtual" && cardType.lowercased() == "debit card" {
            print("⚠️ Cannot delete the virtual card")
            return false
        }
        
        // Find the index of the card to delete
        guard let index = walletCards.firstIndex(where: { 
            $0.issuer.lowercased() == issuer.lowercased() && 
            $0.cardType.lowercased() == cardType.lowercased() 
        }) else {
            print("❌ Card not found in wallet: \(issuer) \(cardType)")
            return false
        }
        
        // Remove from local wallet
        walletCards.remove(at: index)
        print("✅ Card deleted from wallet: \(issuer) \(cardType)")
        
        // Also remove from Firestore if user is logged in
        let formattedIssuer = issuer.lowercased().trimmingCharacters(in: .whitespaces)
        let formattedCardName = cardType.lowercased().trimmingCharacters(in: .whitespaces)
        let cardDocumentId = "\(formattedIssuer)_\(formattedCardName)".replacingOccurrences(of: " ", with: "_")
        
        // Call FirebaseService to remove card from user's Firestore document
        removeCardFromFirestore(cardId: cardDocumentId)
        
        // Save changes to UserDefaults
        saveWalletCards()
        return true
    }
    
    // Remove card from user's Firestore document
    private func removeCardFromFirestore(cardId: String) {
        // Call FirebaseService to remove card from user's Firestore document
        FirebaseService.shared.removeCardFromUserProfile(cardId: cardId) { result in
            switch result {
            case .success:
                print("✅ Successfully removed card from Firestore: \(cardId)")
            case .failure(let error):
                print("❌ Failed to remove card from Firestore: \(error.localizedDescription)")
            }
        }
    }
    
    // Find the best card for a business, prioritizing cards with matching business names
    func findBestCardForBusiness(businessName: String, category: String) -> (WalletCard, Double, String?)? {
        print("🔍 Finding best card for business: \(businessName)")
        
        // Clean up business name for matching - lowercase and remove common words
        let cleanBusinessName = businessName.lowercased()
            .replacingOccurrences(of: "wholesale", with: "")
            .replacingOccurrences(of: "store", with: "")
            .replacingOccurrences(of: "gas station", with: "")
            .replacingOccurrences(of: "supermarket", with: "")
            .replacingOccurrences(of: "supercenter", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("   Matching against: \(cleanBusinessName)")
        
        // First try to find a co-branded card that matches the business name
        for card in walletCards {
            // Skip the virtual card
            if card.issuer == "Virtual" { continue }
            
            // Check if card name contains the business name or vice versa
            let cardName = card.cardType.lowercased()
            
            if cardName.contains(cleanBusinessName) || 
               (cleanBusinessName.count > 3 && cleanBusinessName.contains(cardName)) {
                // Found a card matching the business name
                
                // Find the best multiplier for this category
                var bestMultiplier: Double = 1.0 // Default to 1x for co-branded cards
                
                // Special case for Costco Gas Station with Citi Costco card
                if businessName.lowercased().contains("costco") && 
                   businessName.lowercased().contains("gas") &&
                   card.issuer == "Citi" && card.cardType == "Costco Anywhere Visa" {
                    bestMultiplier = 5.0
                    print("   🔥 Special case: Costco Gas Station with Costco Anywhere Visa - using 5% cashback")
                } else {
                    //best multiplier should be just the clean business name
                    //the databse will maintain rewards for the business itself
                    //i.e. Costco Anywhere Visa will have rewards field for 'costco'
                    bestMultiplier = card.rewards[cleanBusinessName] ?? 1.0
                    
                    // Check "other" category as fallback
                    if bestMultiplier == 1.0 {
                        if let otherMultiplier = card.rewards["other"] {
                            bestMultiplier = otherMultiplier
                        }
                    }
                }
                
                print("   ✅ Found co-branded card: \(card.issuer) \(card.cardType) with \(bestMultiplier)x rewards")
                
                // Return the card, multiplier, and the clean business name as the matching category
                return (card, bestMultiplier, cleanBusinessName.capitalized)
            }
        }
        
        // No co-branded card found, fall back to category-based matching
        print("   No co-branded card found, using category-based matching")
        if let result = findBestCard(for: category) {
            return (result.0, result.1, nil) // Return with nil for matchingCategory to indicate no business-specific match
        }
        
        return nil
    }
} 