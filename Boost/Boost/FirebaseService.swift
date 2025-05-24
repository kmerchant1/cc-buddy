//
//  FirebaseService.swift
//  Boost
//
//  Created for Firebase integration
//

import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

// Card details from Firebase with dynamic rewards
struct CardDetails: Identifiable {
    var id: String?
    var issuer: String
    var name: String
    var rewards: [String: Int]
    var imgURL: String? // Add imgURL property for card background image
}

// User model to represent Firebase user data
struct UserProfile {
    var uid: String
    var email: String
    var userCards: [String]
}

class FirebaseService {
    static let shared = FirebaseService()
    private let db: Firestore
    private let auth: Auth
    
    // Current logged in user
    @Published var currentUser: UserProfile?
    
    private init() {
        // Initialize Firebase if not already initialized
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        db = Firestore.firestore()
        auth = Auth.auth()
        
        // Check if user is already logged in
        if let user = auth.currentUser {
            fetchUserProfile(uid: user.uid) { result in
                switch result {
                case .success(let userProfile):
                    self.currentUser = userProfile
                case .failure:
                    // If we can't fetch the profile but have auth, create a basic profile
                    self.currentUser = UserProfile(uid: user.uid, email: user.email ?? "", userCards: [])
                }
            }
        }
    }
    
    // MARK: - Authentication Methods
    
    // Sign up with email and password
    func signUp(email: String, password: String, completion: @escaping (Result<UserProfile, Error>) -> Void) {
        auth.createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                print("❌ Error creating user: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let user = authResult?.user else {
                let error = NSError(domain: "FirebaseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to get user after sign up"])
                completion(.failure(error))
                return
            }
            
            // Create user document in Firestore
            let userData = [
                "email": email,
                "userCards": [] as [String]
            ]
            
            self.db.collection("users").document(user.uid).setData(userData) { error in
                if let error = error {
                    print("❌ Error creating user document: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                // Initialize userMetrics document with default values
                let userMetricsData: [String: Any] = [
                    "totalCards": 0,
                    "cardUsageByCategory": [:] as [String: [String: Int]]
                ]
                
                self.db.collection("userMetrics").document(user.uid).setData(userMetricsData) { metricsError in
                    if let metricsError = metricsError {
                        print("❌ Error creating userMetrics document: \(metricsError.localizedDescription)")
                        // Don't fail the entire signup if metrics creation fails
                    } else {
                        print("✅ Successfully created userMetrics document for new user")
                    }
                }
                
                let userProfile = UserProfile(uid: user.uid, email: email, userCards: [])
                self.currentUser = userProfile
                
                // Since this is a new user, there are no cards to load yet
                // But we'll still call loadCardsFromFirebase to ensure wallet is in the correct state
                WalletManager.shared.loadCardsFromFirebase()
                
                completion(.success(userProfile))
            }
        }
    }
    
    // Sign in with email and password
    func signIn(email: String, password: String, completion: @escaping (Result<UserProfile, Error>) -> Void) {
        auth.signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                print("❌ Error signing in: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let user = authResult?.user else {
                let error = NSError(domain: "FirebaseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to get user after sign in"])
                completion(.failure(error))
                return
            }
            
            // Fetch user profile from Firestore
            self.fetchUserProfile(uid: user.uid) { result in
                switch result {
                case .success(let userProfile):
                    // Load the user's cards from Firebase
                    WalletManager.shared.loadCardsFromFirebase()
                    completion(.success(userProfile))
                    
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Sign out current user
    func signOut() -> Bool {
        do {
            try auth.signOut()
            currentUser = nil
            
            // Clear the wallet when the user signs out
            WalletManager.shared.clearCards()
            
            // Post notification that user has signed out
            NotificationCenter.default.post(name: NSNotification.Name("UserDidSignOut"), object: nil)
            
            return true
        } catch {
            print("❌ Error signing out: \(error.localizedDescription)")
            return false
        }
    }
    
    // Get the current Firebase Auth user
    func getCurrentAuthUser() -> User? {
        return auth.currentUser
    }
    
    // MARK: - User Profile Methods
    
    // Fetch user profile from Firestore
    func fetchUserProfile(uid: String, completion: @escaping (Result<UserProfile, Error>) -> Void) {
        db.collection("users").document(uid).getDocument { document, error in
            if let error = error {
                print("❌ Error fetching user document: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let document = document, document.exists, let data = document.data() else {
                let error = NSError(domain: "FirebaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document not found"])
                completion(.failure(error))
                return
            }
            
            let email = data["email"] as? String ?? ""
            let userCards = data["userCards"] as? [String] ?? []
            
            let userProfile = UserProfile(uid: uid, email: email, userCards: userCards)
            self.currentUser = userProfile
            completion(.success(userProfile))
        }
    }
    
    // Function to fetch card details based on issuer and card type
    func fetchCardDetails(issuer: String, cardType: String, completion: @escaping (Result<CardDetails, Error>) -> Void) {
        // Log the query parameters
        print("🔍 Querying Firestore for card - Issuer: \(issuer), Card Type: \(cardType)")
        
        // Normalize issuer name for Capital One
        let normalizedIssuer = issuer == "Capital One" ? "Capital One" : issuer
        
        // Query Firestore for cards that match issuer and name (card type)
        db.collection("cards")
            .whereField("issuer", isEqualTo: normalizedIssuer)
            .whereField("name", isEqualTo: cardType)
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("❌ Firestore query error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let documents = querySnapshot?.documents, !documents.isEmpty else {
                    print("⚠️ No documents found for Issuer: \(issuer), Card Type: \(cardType)")
                    print("⚠️ Using normalized issuer: \(normalizedIssuer)")
                    print("⚠️ Query path: cards collection, issuer=\(normalizedIssuer), name=\(cardType)")
                    completion(.failure(NSError(domain: "FirebaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No card found with the specified issuer and type"])))
                    return
                }
                
                print("✅ Found \(documents.count) matching document(s) in Firestore")
                
                // Get the first matching document
                let document = documents[0]
                let data = document.data()
                
                print("📄 Document data: \(data)")
                
                // Create card details object directly from Firestore data
                do {
                    // Extract document fields directly
                    let docIssuer = data["issuer"] as? String ?? issuer
                    let docName = data["name"] as? String ?? cardType
                    let imgURL = data["imgURL"] as? String // Get imgURL from Firestore
                    
                    // Handle the rewards field
                    var rewardsMap = [String: Int]()
                    
                    // Try to get rewards as a dictionary
                    if let rewardsData = data["rewards"] as? [String: Any] {
                        print("📊 Processing rewards data...")
                        
                        // Iterate through each reward category
                        for (category, value) in rewardsData {
                            print("   - Category: \(category), Value: \(value), Type: \(type(of: value))")
                            
                            // Handle different numeric types
                            if let intValue = value as? Int {
                                rewardsMap[category] = intValue
                            } else if let doubleValue = value as? Double {
                                rewardsMap[category] = Int(doubleValue)
                            } else if let stringValue = value as? String, let intValue = Int(stringValue) {
                                rewardsMap[category] = intValue
                            } else if let nsNumber = value as? NSNumber {
                                rewardsMap[category] = nsNumber.intValue
                            }
                        }
                    }
                    
                    print("📊 Parsed rewards: \(rewardsMap)")
                    
                    // Create card details with the parsed data
                    let cardDetails = CardDetails(
                        id: document.documentID,
                        issuer: docIssuer,
                        name: docName,
                        rewards: rewardsMap,
                        imgURL: imgURL
                    )
                    
                    if let imgURL = imgURL {
                        print("🖼️ Card image URL: \(imgURL)")
                    } else {
                        print("⚠️ No image URL found for card")
                    }
                    
                    print("✅ Successfully created card details for \(cardDetails.issuer) \(cardDetails.name) with \(rewardsMap.count) reward categories")
                    completion(.success(cardDetails))
                } catch {
                    // Log error details but try to recover
                    print("⚠️ Error processing document: \(error.localizedDescription)")
                    
                    // Create a basic CardDetails object as a fallback
                    let fallbackCardDetails = CardDetails(
                        id: document.documentID,
                        issuer: data["issuer"] as? String ?? issuer,
                        name: data["name"] as? String ?? cardType,
                        rewards: [:],
                        imgURL: data["imgURL"] as? String
                    )
                    
                    print("⚠️ Using fallback card details with empty rewards")
                    completion(.success(fallbackCardDetails))
                }
            }
    }
    
    // Function to update a user's userCards array in Firestore
    func addCardToUserProfile(issuer: String, cardName: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let user = auth.currentUser else {
            let error = NSError(domain: "FirebaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion(.failure(error))
            return
        }
        
        // Format the card ID: convert to lowercase and replace spaces with underscores
        let formattedIssuer = issuer.lowercased().trimmingCharacters(in: .whitespaces)
        let formattedCardName = cardName.lowercased().trimmingCharacters(in: .whitespaces)
        let cardDocumentId = "\(formattedIssuer)_\(formattedCardName)".replacingOccurrences(of: " ", with: "_")
        
        print("📝 Adding card to user profile: \(cardDocumentId)")
        
        // Reference to the user document
        let userDocRef = db.collection("users").document(user.uid)
        
        // Update the userCards array with the new card reference
        userDocRef.updateData([
            "userCards": FieldValue.arrayUnion([cardDocumentId])
        ]) { error in
            if let error = error {
                print("❌ Error updating user cards: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            print("✅ Successfully added card to user profile: \(cardDocumentId)")
            
            // Update the current user profile in memory
            if var updatedUser = self.currentUser {
                if !updatedUser.userCards.contains(cardDocumentId) {
                    updatedUser.userCards.append(cardDocumentId)
                    self.currentUser = updatedUser
                }
            }
            
            completion(.success(true))
        }
    }
    
    // Function to remove a card from a user's userCards array in Firestore
    func removeCardFromUserProfile(cardId: String, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        guard let user = auth.currentUser else {
            let error = NSError(domain: "FirebaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion?(.failure(error))
            return
        }
        
        print("📝 Removing card from user profile: \(cardId)")
        
        // Reference to the user document
        let userDocRef = db.collection("users").document(user.uid)
        
        // Update the userCards array to remove the card reference
        userDocRef.updateData([
            "userCards": FieldValue.arrayRemove([cardId])
        ]) { error in
            if let error = error {
                print("❌ Error removing card from user profile: \(error.localizedDescription)")
                completion?(.failure(error))
                return
            }
            
            print("✅ Successfully removed card from user profile: \(cardId)")
            
            // Update the current user profile in memory
            if var updatedUser = self.currentUser {
                if let index = updatedUser.userCards.firstIndex(of: cardId) {
                    updatedUser.userCards.remove(at: index)
                    self.currentUser = updatedUser
                }
            }
            
            completion?(.success(true))
        }
    }
} 