//
//  UserAnalytics.swift
//  Boost
//
//  Created for tracking user engagement metrics
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// User metrics model
struct UserMetrics {
    var totalCards: Int
    var cardUsageByCategory: [String: [String: Int]]
    
    init() {
        self.totalCards = 0
        self.cardUsageByCategory = [:]
    }
    
    init(totalCards: Int, cardUsageByCategory: [String: [String: Int]]) {
        self.totalCards = totalCards
        self.cardUsageByCategory = cardUsageByCategory
    }
}

class UserAnalytics {
    static let shared = UserAnalytics()
    private let db: Firestore
    private let auth: Auth
    
    private init() {
        db = Firestore.firestore()
        auth = Auth.auth()
    }
    
    // MARK: - Private Helper Methods
    
    private func getCurrentUserUID() -> String? {
        return auth.currentUser?.uid
    }
    
    private func createCardKey(issuer: String, cardType: String) -> String {
        // Create a consistent key format: "issuer_cardtype" with spaces and special chars removed
        let cleanIssuer = issuer.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ".", with: "")
        let cleanCardType = cardType.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ".", with: "")
        return "\(cleanIssuer)_\(cleanCardType)"
    }
    
    // MARK: - Card Management Analytics
    
    // Update total cards count and initialize card in cardUsageByCategory
    func trackCardAdded(issuer: String, cardType: String) {
        guard let userUID = getCurrentUserUID() else {
            print("❌ UserAnalytics: No authenticated user found")
            return
        }
        
        let userMetricsRef = db.collection("userMetrics").document(userUID)
        let cardKey = createCardKey(issuer: issuer, cardType: cardType)
        
        print("📊 UserAnalytics: Tracking card added - \(issuer) \(cardType)")
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let userMetricsDoc: DocumentSnapshot
            do {
                try userMetricsDoc = transaction.getDocument(userMetricsRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            var totalCards = 0
            var cardUsageByCategory: [String: [String: Int]] = [:]
            
            if userMetricsDoc.exists {
                totalCards = userMetricsDoc.data()?["totalCards"] as? Int ?? 0
                cardUsageByCategory = userMetricsDoc.data()?["cardUsageByCategory"] as? [String: [String: Int]] ?? [:]
            }
            
            // Increment total cards and initialize card with empty category map
            totalCards += 1
            cardUsageByCategory[cardKey] = [:]
            
            let updateData: [String: Any] = [
                "totalCards": totalCards,
                "cardUsageByCategory": cardUsageByCategory
            ]
            
            if userMetricsDoc.exists {
                transaction.updateData(updateData, forDocument: userMetricsRef)
            } else {
                // Create new document
                transaction.setData(updateData, forDocument: userMetricsRef)
            }
            
            return nil
        }) { (object, error) in
            if let error = error {
                print("❌ UserAnalytics: Error tracking card addition: \(error.localizedDescription)")
            } else {
                print("✅ UserAnalytics: Successfully tracked card addition for \(issuer) \(cardType)")
                // Post notification to update ProfileView
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("CardCountChanged"), object: nil)
                }
            }
        }
    }
    
    // Update total cards count and remove card from cardUsageByCategory
    func trackCardDeleted(issuer: String, cardType: String) {
        guard let userUID = getCurrentUserUID() else {
            print("❌ UserAnalytics: No authenticated user found")
            return
        }
        
        let userMetricsRef = db.collection("userMetrics").document(userUID)
        let cardKey = createCardKey(issuer: issuer, cardType: cardType)
        
        print("📊 UserAnalytics: Tracking card deleted - \(issuer) \(cardType)")
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let userMetricsDoc: DocumentSnapshot
            do {
                try userMetricsDoc = transaction.getDocument(userMetricsRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard userMetricsDoc.exists else {
                print("⚠️ UserAnalytics: User metrics document doesn't exist for card deletion")
                return nil
            }
            
            var totalCards = userMetricsDoc.data()?["totalCards"] as? Int ?? 0
            var cardUsageByCategory = userMetricsDoc.data()?["cardUsageByCategory"] as? [String: [String: Int]] ?? [:]
            
            // Decrement total cards and remove card from cardUsageByCategory
            totalCards = max(0, totalCards - 1)
            cardUsageByCategory.removeValue(forKey: cardKey)
            
            let updateData: [String: Any] = [
                "totalCards": totalCards,
                "cardUsageByCategory": cardUsageByCategory
            ]
            
            transaction.updateData(updateData, forDocument: userMetricsRef)
            return nil
        }) { (object, error) in
            if let error = error {
                print("❌ UserAnalytics: Error tracking card deletion: \(error.localizedDescription)")
            } else {
                print("✅ UserAnalytics: Successfully tracked card deletion for \(issuer) \(cardType)")
                // Post notification to update ProfileView
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("CardCountChanged"), object: nil)
                }
            }
        }
    }
    
    // MARK: - Usage Analytics
    
    // Track when user clicks pay/open wallet button
    func trackPaymentUsage(category: String, issuer: String, cardType: String) {
        guard let userUID = getCurrentUserUID() else {
            print("❌ UserAnalytics: No authenticated user found")
            return
        }
        
        let userMetricsRef = db.collection("userMetrics").document(userUID)
        let cardKey = createCardKey(issuer: issuer, cardType: cardType)
        
        print("📊 UserAnalytics: Tracking payment usage - Category: \(category), Card: \(issuer) \(cardType)")
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let userMetricsDoc: DocumentSnapshot
            do {
                try userMetricsDoc = transaction.getDocument(userMetricsRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            var cardUsageByCategory: [String: [String: Int]] = [:]
            var totalCards = 0
            
            if userMetricsDoc.exists {
                cardUsageByCategory = userMetricsDoc.data()?["cardUsageByCategory"] as? [String: [String: Int]] ?? [:]
                totalCards = userMetricsDoc.data()?["totalCards"] as? Int ?? 0
            }
            
            // Initialize card if it doesn't exist
            if cardUsageByCategory[cardKey] == nil {
                cardUsageByCategory[cardKey] = [:]
            }
            
            // Increment category usage for this card (create category if doesn't exist)
            cardUsageByCategory[cardKey]![category] = (cardUsageByCategory[cardKey]![category] ?? 0) + 1
            
            let updateData: [String: Any] = [
                "totalCards": totalCards,
                "cardUsageByCategory": cardUsageByCategory
            ]
            
            if userMetricsDoc.exists {
                transaction.updateData(updateData, forDocument: userMetricsRef)
            } else {
                // Create new document if it doesn't exist
                transaction.setData(updateData, forDocument: userMetricsRef)
            }
            
            return nil
        }) { (object, error) in
            if let error = error {
                print("❌ UserAnalytics: Error tracking payment usage: \(error.localizedDescription)")
            } else {
                print("✅ UserAnalytics: Successfully tracked payment usage for \(category) with \(issuer) \(cardType)")
            }
        }
    }
    
    // MARK: - Data Retrieval
    
    // Fetch current user metrics (for debugging or display purposes)
    func fetchUserMetrics(completion: @escaping (Result<UserMetrics, Error>) -> Void) {
        guard let userUID = getCurrentUserUID() else {
            let error = NSError(domain: "UserAnalytics", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authenticated user found"])
            completion(.failure(error))
            return
        }
        
        db.collection("userMetrics").document(userUID).getDocument { (document, error) in
            if let error = error {
                print("❌ UserAnalytics: Error fetching user metrics: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let document = document, document.exists, let data = document.data() else {
                // Return empty metrics if document doesn't exist
                completion(.success(UserMetrics()))
                return
            }
            
            let totalCards = data["totalCards"] as? Int ?? 0
            let cardUsageByCategory = data["cardUsageByCategory"] as? [String: [String: Int]] ?? [:]
            
            let metrics = UserMetrics(totalCards: totalCards, cardUsageByCategory: cardUsageByCategory)
            completion(.success(metrics))
        }
    }
    
    // Sync total cards count with actual wallet (useful for data consistency)
    func syncTotalCardsWithWallet() {
        guard let userUID = getCurrentUserUID() else {
            print("❌ UserAnalytics: No authenticated user found for sync")
            return
        }
        
        let actualCardCount = WalletManager.shared.walletCards.filter { $0.issuer != "Virtual" }.count
        
        db.collection("userMetrics").document(userUID).updateData([
            "totalCards": actualCardCount
        ]) { error in
            if let error = error {
                print("❌ UserAnalytics: Error syncing total cards: \(error.localizedDescription)")
            } else {
                print("✅ UserAnalytics: Successfully synced total cards count: \(actualCardCount)")
            }
        }
    }
} 