//
//  WalletView.swift
//  Boost
//

import SwiftUI
import GooglePlaces

// Create a simple struct for card info instead of using a tuple
public struct SelectedCardInfo: Equatable {
    public var issuer: String
    public var cardType: String
    public var multiplier: Double
    public var imgURL: String?
    
    public init(issuer: String = "", cardType: String = "", multiplier: Double = 0.0, imgURL: String? = nil) {
        self.issuer = issuer
        self.cardType = cardType
        self.multiplier = multiplier
        self.imgURL = imgURL
    }
}

struct WalletView: View {
    @State private var showAddCardSheet = false
    @State private var cards: [Card] = []
    @State private var showMaxCardsAlert = false
    @State private var hasSelectedVirtualCard: Bool = false
    @State private var selectedCardInfo: SelectedCardInfo = SelectedCardInfo()
    @State private var showCardSelectionSheet = false
    @State private var showDeleteMenu = false // State for showing the delete menu
    @State private var refreshCounter: Int = 0 // Add a counter to force refreshes
    @State private var currentCategory: String = "Category" // Track current category for reward calculation
    @State private var showPlaceSearch = false // State to control place search presentation
    @State private var showLocationOptions = false // State for location options
    @State private var showCoordinateInput = false // State for coordinate input
    @State private var latitudeInput: String = ""
    @State private var longitudeInput: String = ""
    @StateObject private var locationManager = BasicLocation() // Shared location manager
    @State private var showNearbyPlacesInVirtualCardView: Bool = false // Flag to show nearby places

    @ObservedObject private var walletManager = WalletManager.shared
    @Namespace private var animation

    // Mapping from place types to reward categories (copied from VirtualCardView)
    private let placeTypeToRewardCategory: [String: String] = [
        "acai_shop": "dining",
        "afghani_restaurant": "dining",
        "african_restaurant": "dining",
        "american_restaurant": "dining",
        "asian_restaurant": "dining",
        "bagel_shop": "dining",
        "bakery": "dining",
        "bar": "dining",
        "bar_and_grill": "dining",
        "barbecue_restaurant": "dining",
        "brazilian_restaurant": "dining",
        "breakfast_restaurant": "dining",
        "brunch_restaurant": "dining",
        "buffet_restaurant": "dining",
        "cafe": "dining",
        "cafeteria": "dining",
        "candy_store": "dining",
        "cat_cafe": "dining",
        "car_rental": "rental_cars",
        "chinese_restaurant": "dining",
        "chocolate_factory": "dining",
        "chocolate_shop": "dining",
        "coffee_shop": "dining",
        "confectionery": "dining",
        "deli": "dining",
        "dessert_restaurant": "dining",
        "dessert_shop": "dining",
        "diner": "dining",
        "dog_cafe": "dining",
        "donut_shop": "dining",
        "fast_food_restaurant": "dining",
        "fine_dining_restaurant": "dining",
        "food_court": "dining",
        "french_restaurant": "dining",
        "greek_restaurant": "dining",
        "hamburger_restaurant": "dining",
        "ice_cream_shop": "dining",
        "indian_restaurant": "dining",
        "indonesian_restaurant": "dining",
        "italian_restaurant": "dining",
        "japanese_restaurant": "dining",
        "juice_shop": "dining",
        "korean_restaurant": "dining",
        "lebanese_restaurant": "dining",
        "meal_delivery": "dining",
        "meal_takeaway": "dining",
        "mediterranean_restaurant": "dining",
        "mexican_restaurant": "dining",
        "middle_eastern_restaurant": "dining",
        "pizza_restaurant": "dining",
        "pub": "dining",
        "ramen_restaurant": "dining",
        "restaurant": "dining",
        "sandwich_shop": "dining",
        "seafood_restaurant": "dining",
        "spanish_restaurant": "dining",
        "steak_house": "dining",
        "sushi_restaurant": "dining",
        "tea_house": "dining",
        "thai_restaurant": "dining",
        "turkish_restaurant": "dining",
        "vegan_restaurant": "dining",
        "vegetarian_restaurant": "dining",
        "vietnamese_restaurant": "dining",
        "wine_bar": "dining",
        "pharmacy": "drugstore",
        "drugstore": "drugstore",
        "convenience_store": "drugstore",
        "airport": "other_travel",
        "extended_stay_hotel": "hotels",
        "lodging": "hotels",
        "hotel": "hotels",
        "bed_and_breakfast": "hotels",
        "budget_japanese_inn": "hotels",
        "inn": "hotels",
        "japanese_inn": "hotels",
        "motel": "hotels",
        "resort_hotel": "hotels",
        "train_station": "transit",
        "bus_station": "transit",
        "subway_station": "transit",
        "light_rail_station": "transit",
        "transit_station": "transit",
        "gas_station": "gas",
        "asian_grocery_store": "groceries",
        "grocery_store": "groceries",
        "grocery_or_supermarket": "groceries"
    ]

    private let topCardVisibility: CGFloat = 50 // Height of visible card top in stack
    private let maxCards = 8
    private let cardHeight: CGFloat = 200
    private let virtualCardSpacing: CGFloat = 10 // Space between virtual card and card stack
    private let fixedStackHeight: CGFloat = 300 // Fixed height for the entire card stack area
    private let stripSpacing: CGFloat = 8 // Spacing around the black info strip

    init() {
        print("💡 WalletView initialized")
    }

    private func isVirtualCard(_ card: Card) -> Bool {
        return card.issuer == "Virtual" && card.cardType == "Debit Card"
    }
    
    // Format multiplier percentage
    private func formatMultiplier(_ value: Double) -> String {
        // Check if the decimal part is zero
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))%" // Display as integer
        } else {
            return "\(String(format: "%.1f", value))%" // Display with one decimal place
        }
    }
    
    // Convert WalletCard to Card for UI display
    private func convertToCardArray(_ walletCards: [WalletCard]) -> [Card] {
        return walletCards.map { walletCard in
            Card(
                issuer: walletCard.issuer,
                cardType: walletCard.cardType,
                rewards: walletCard.rewards.mapValues { Int($0) },
                imgURL: walletCard.imgURL
            )
        }
    }
    
    // Update the selected card info from the WalletCard
    private func updateSelectedCardInfo(walletCard: WalletCard) {
        // Determine the reward rate for the current category
        let rewardMultiplier: Double
        
        if currentCategory != "Category" {
            rewardMultiplier = walletCard.getRewardRate(for: currentCategory.lowercased()) ?? 1.0
        } else {
            rewardMultiplier = 1.0 // Default
        }
        
        // Update the binding values
        hasSelectedVirtualCard = (walletCard.issuer != "Virtual")
        selectedCardInfo = SelectedCardInfo(
            issuer: walletCard.issuer, 
            cardType: walletCard.cardType, 
            multiplier: rewardMultiplier,
            imgURL: walletCard.imgURL
        )
        
        // Force refresh
        refreshCardStack()
    }

    // Force a refresh of the card stack
    private func refreshCardStack() {
        refreshCounter += 1
        print("💳 Refreshing card stack, counter: \(refreshCounter)")
        
        // Reload cards from WalletManager
        cards = convertToCardArray(walletManager.walletCards)
        
        // Ensure the Virtual card is always available
        if !cards.contains(where: { isVirtualCard($0) }) {
            cards.append(Card(issuer: "Virtual", cardType: "Debit Card"))
        }
    }

    // Create a card view for the stack with all necessary modifiers
    @ViewBuilder
    private func cardStackItem(card: Card, index: Int) -> some View {
        CardView(
            card: card,
            onDelete: {
                withAnimation(.spring()) {
                    // Track card deletion analytics before actually deleting
                    UserAnalytics.shared.trackCardDeleted(issuer: card.issuer, cardType: card.cardType)
                    
                    if let indexToRemove = cards.firstIndex(where: { $0.id == card.id }) {
                        cards.remove(at: indexToRemove)
                    }
                    walletManager.deleteCard(issuer: card.issuer, cardType: card.cardType)
                    refreshCardStack() // Force refresh after deletion
                }
            },
            showDeleteButton: false, // Disable individual delete buttons
            buttonsAtTop: true
        )
        .padding(.horizontal)
        // Position each card with the appropriate offset
        .offset(y: CGFloat(index) * topCardVisibility)
        // Z-index ensures newer cards (higher indices) appear on top
        .zIndex(Double(index))
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        ))
        .matchedGeometryEffect(id: card.id, in: animation)
        .id("card-\(card.id)-\(refreshCounter)") // Force refresh on change
    }
    
    // Create info strip view to simplify the body
    @ViewBuilder
    private func infoStripView() -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.5))
            .frame(height: 40)
            .overlay(infoStripContent())
            .cornerRadius(20)
            .padding(.horizontal)
            .transition(.opacity)
    }
    
    // Extract the info strip content
    @ViewBuilder
    private func infoStripContent() -> some View {
        HStack {
            // Card name on the left
            Text("\(selectedCardInfo.issuer) \(selectedCardInfo.cardType)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.leading, 15)
            
            Spacer()
            
            // Switch card button
            Button(action: {
                showCardSelectionSheet = true
            }) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.trailing, 8)
            }
            
            // Reward multiplier on the right with conditional formatting
            Text(formatMultiplier(selectedCardInfo.multiplier))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.green)
                .padding(.trailing, 15)
        }
        .padding(.vertical, 5)
    }

    // Create an updated info strip view that's blue and clickable for location options
    @ViewBuilder
    private func walletInfoStripView() -> some View {
        HStack(spacing: 12) {
            // Left-aligned wallet info strip (smaller width)
            Rectangle()
                .fill(Color.black)
                .frame(width: 300, height: 40)
                .overlay(walletInfoStripContent())
                .cornerRadius(20)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(), value: selectedCardInfo.issuer)

            
            // Green circular wallet button
            Button(action: {
                openAppleWallet()
            }) {
                Image(systemName: "wallet.bifold")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.green)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    // Content for the wallet info strip
    @ViewBuilder
    private func walletInfoStripContent() -> some View {
        HStack {
            // Card name on the left
            Text("\(selectedCardInfo.issuer) \(selectedCardInfo.cardType)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.leading, 15)
            
            Spacer()

            // Switch card button
            Button(action: {
                showCardSelectionSheet = true
            }) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.trailing, 8)
            }
            
            // Reward multiplier on the right
            Text(formatMultiplier(selectedCardInfo.multiplier))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .padding(.trailing, 15)
        }
        .padding(.vertical, 5)
    }
    
    // Function to open Apple Wallet
    private func openAppleWallet() {
        print("📱 Opening Apple Wallet from WalletView")
        
        // Track payment usage analytics before resetting
        if hasSelectedVirtualCard && selectedCardInfo.issuer != "Virtual" {
            // Get the current category, defaulting to "Other" if none selected
            let currentCategoryForAnalytics = WalletManager.shared.selectedCategory?.isEmpty == false ? 
                WalletManager.shared.selectedCategory! : "Other"
            
            // Track the payment usage
            UserAnalytics.shared.trackPaymentUsage(
                category: currentCategoryForAnalytics,
                issuer: selectedCardInfo.issuer,
                cardType: selectedCardInfo.cardType
            )
            
            print("📊 Tracked payment usage: \(currentCategoryForAnalytics) with \(selectedCardInfo.issuer) \(selectedCardInfo.cardType)")
        }
        
        // Reset the category in WalletManager
        WalletManager.shared.selectedCategory = ""
        
        // Reset the virtual card state
        withAnimation(.spring()) {
            hasSelectedVirtualCard = false
            selectedCardInfo = SelectedCardInfo()
        }
        
        // Force refresh to update UI
        refreshCardStack()
        
        // Using URL scheme to open Apple Wallet
        if let walletURL = URL(string: "shoebox://") {
            UIApplication.shared.open(walletURL, options: [:]) { success in
                if !success {
                    print("📱 Could not open Apple Wallet")
                } else {
                    print("📱 Successfully opened Apple Wallet")
                }
            }
        }
    }

    // Function to handle device location request from walletInfoStripView
    private func getDeviceLocation() {
        // Start getting location
        locationManager.getLocation()
        
        // No need for delay here - we'll use the onChange handler instead
    }

    // Function to search for nearby places based on coordinates
    private func searchNearbyPlacesFromCoordinates(_ coordinatesString: String) {
        // Parse coordinates string in format "latitude, longitude"
        let components = coordinatesString.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        
        guard components.count == 2,
              let latitude = Double(components[0]),
              let longitude = Double(components[1]) else {
            print("📱 WalletView - Error parsing coordinates: \(coordinatesString)")
            return
        }
        
        print("📱 WalletView - Got coordinates: \(latitude), \(longitude)")
        
        // Save the coordinates for use when selecting a business
        latitudeInput = String(latitude)
        longitudeInput = String(longitude)
        
        // Set the flag to trigger the VirtualCardView to show nearby places
        showNearbyPlacesInVirtualCardView = true
    }

    // Manual coordinate input view
    private var manualCoordinateInputView: some View {
        VStack(spacing: 16) {
            Text("Enter Coordinates")
                .font(.headline)
                .padding(.top)
            
            VStack(spacing: 16) {
                // Latitude input with separate negative toggle
                VStack(alignment: .leading, spacing: 8) {
                    Text("Latitude:")
                        .font(.subheadline)
                    
                    HStack {
                        // Negative toggle
                        Toggle(isOn: Binding(
                            get: { latitudeInput.hasPrefix("-") },
                            set: { newValue in
                                if newValue {
                                    if !latitudeInput.hasPrefix("-") {
                                        latitudeInput = "-" + latitudeInput
                                    }
                                } else {
                                    if latitudeInput.hasPrefix("-") {
                                        latitudeInput.removeFirst()
                                    }
                                }
                            }
                        )) {
                            Text("Negative")
                                .font(.caption)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .frame(width: 120)
                        
                        TextField("37.7749", text: $latitudeInput)
                            .keyboardType(.numbersAndPunctuation)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                .padding(.horizontal)
                
                // Longitude input with separate negative toggle
                VStack(alignment: .leading, spacing: 8) {
                    Text("Longitude:")
                        .font(.subheadline)
                    
                    HStack {
                        // Negative toggle
                        Toggle(isOn: Binding(
                            get: { longitudeInput.hasPrefix("-") },
                            set: { newValue in
                                if newValue {
                                    if !longitudeInput.hasPrefix("-") {
                                        longitudeInput = "-" + longitudeInput
                                    }
                                } else {
                                    if longitudeInput.hasPrefix("-") {
                                        longitudeInput.removeFirst()
                                    }
                                }
                            }
                        )) {
                            Text("Negative")
                                .font(.caption)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .frame(width: 120)
                        
                        TextField("122.4194", text: $longitudeInput)
                            .keyboardType(.numbersAndPunctuation)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                .padding(.horizontal)
            }
            
            HStack {
                Button("Cancel") {
                    showCoordinateInput = false
                }
                .buttonStyle(.bordered)
                
                Button("Use Coordinates") {
                    useManualCoordinates()
                    showCoordinateInput = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(latitudeInput.isEmpty || longitudeInput.isEmpty)
            }
            .padding()
            
            Button("Search Nearby Places") {
                useManualCoordinates()
                showPlaceSearch = true
                showCoordinateInput = false
            }
            .buttonStyle(.borderedProminent)
            .disabled(latitudeInput.isEmpty || longitudeInput.isEmpty)
            .padding(.bottom)
        }
    }
    
    // Process manually entered coordinates
    private func useManualCoordinates() {
        guard !latitudeInput.isEmpty, !longitudeInput.isEmpty else { return }
        
        // Try to convert to numeric values
        if let lat = Double(latitudeInput), let lon = Double(longitudeInput) {
            // Store the coordinates for use in searching
            // For now, we'll just launch the place search which will handle finding businesses at these coordinates
            showPlaceSearch = true
            
            // Print to console for debugging
            print("📱 Manual coordinates entered: \(lat), \(lon)")
        } else {
            print("📱 Invalid coordinates format")
        }
    }

    var body: some View {
        // Get all non-virtual cards
        let otherCards = cards.filter { !isVirtualCard($0) }
        let virtualCard = cards.first(where: { isVirtualCard($0) }) ?? Card(issuer: "Virtual", cardType: "Debit Card")

        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Title and Buttons in a styled container
                ZStack {
                    // Background rounded rectangle
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(UIColor.darkGray).opacity(0.3))
                        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                        .frame(height: 50)
                    
                    // Header content
                    HStack {
                        Text("Wallet")
                             .font(.system(size: 24))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                        
                        Spacer()
 
                        if let category = walletManager.selectedCategory, !category.isEmpty && category != "Category" {
                            Text(category)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                                .padding(.vertical, 5)
                                .padding(.horizontal, 10)
                                .cornerRadius(8)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                                .id("category-\(refreshCounter)") // Force refresh when category changes
                        }
                        
                        Spacer()
                        
                        // Search button
                        Button(action: {
                            // Set the flag to trigger the place search
                            showPlaceSearch = true
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .padding(8)
                                
                                .clipShape(Circle())
                        }
                        .padding(.horizontal, 4)
                        
                        // Add Button
                        Button(action: {
                            if cards.count < maxCards {
                                showAddCardSheet = true
                            } else {
                                showMaxCardsAlert = true
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        }
                        .padding(.leading, 4)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 15)
                }
                .frame(height: 40)
                .padding(.horizontal)
                .padding(.top, 30)
                .padding(.bottom, 20)
                .background(Color.black)
                .zIndex(100)
                
                // Scrollable content
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        // Virtual card at the top with space below
                        VirtualCardView(
                            hasSelectedCard: $hasSelectedVirtualCard,
                            selectedCardInfo: $selectedCardInfo,
                            locationManager: locationManager,
                            showNearbyPlaces: $showNearbyPlacesInVirtualCardView
                        )
                        .padding(.horizontal)
                        .matchedGeometryEffect(id: virtualCard.id, in: animation)
                        .id("virtualCard-\(refreshCounter)") // Force refresh on change
                        .onChange(of: selectedCardInfo) { _, newInfo in
                            // Update currentCategory when category changes in VirtualCardView
                            if let category = walletManager.selectedCategory {
                                currentCategory = category
                                print("📊 Category updated from VirtualCardView: \(category)")
                                
                                // Force refresh to update the header UI
                                refreshCounter += 1
                            }
                        }
                        .onAppear { 
                            // We can't directly access the VirtualCardView instance here
                            // so we'll rely on the sheet approach instead
                        }
                        
                        // Black info strip under virtual card (if a card is selected)
                        if hasSelectedVirtualCard {
                            // Add spacing between virtual card and info strip
                            Spacer().frame(height: stripSpacing)
                            
                            // Use the green wallet strip if it's a real card, otherwise use the normal gray strip
                            if selectedCardInfo.issuer != "Virtual" {
                                walletInfoStripView()
                            } else {
                                infoStripView()
                            }
                            
                            // Add spacing between info strip and card stack
                            Spacer().frame(height: stripSpacing)
                        } else {
                            // If no card is selected, add normal spacing between virtual card and stack
                            Spacer().frame(height: virtualCardSpacing)
                        }
                        
                        // Combined card stack container with hamburger menu at top
                        VStack(spacing: 0) {
                            // Hamburger menu header inside the card container
                            HStack() {
                                
                                

                                Spacer()

                                Button(action: {
                                    showDeleteMenu = true
                                }) {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.system(size: 22))
                                        .foregroundColor(.white)
                                }
                                .padding(.trailing)
                            }
                            
                            .offset(y: 30)
                            // Card stack directly below the hamburger menu with no padding
                            ZStack() {
                                if !otherCards.isEmpty {
                                    // Render cards using the extracted card stack item function
                                    ForEach(Array(otherCards.indices), id: \.self) { index in
                                        cardStackItem(card: otherCards[index], index: index)
                                    }
                                } else if refreshCounter > 0 { // Only show this if we've done at least one refresh
                                    // Show text when no cards are available
                                    Text("No cards added yet")
                                        .foregroundColor(.gray)
                                        .padding(.top, 40)
                                }
                            }
                            
                            .padding(.top, ) // No top padding to position right below header
                            .frame(height: fixedStackHeight - 35) // Adjust for hamburger menu height
                        }
                        
                        .frame(height: fixedStackHeight)
                        .id("cardStack-\(refreshCounter)") // Force refresh on change
                        
                        // Add additional space at the bottom for better scrolling
                        Spacer(minLength: 140)
                    }
                    .padding(.top, 5)
                    
                    
                }
                // Improve scroll behavior
                .scrollIndicators(.visible)
            }
        }
        .sheet(isPresented: $showAddCardSheet) {
            AddCardView(cards: $cards)
                .presentationDetents([.fraction(0.5)]) // Half sheet presentation
                .onDisappear {
                    refreshCardStack() // Refresh when sheet is dismissed
                }
        }
        .sheet(isPresented: $showCardSelectionSheet) {
            // Updated card selection sheet with enhanced functionality
            EnhancedCardSelectionSheet(
                currentCategory: currentCategory,
                currentCardIssuer: selectedCardInfo.issuer,
                currentCardType: selectedCardInfo.cardType,
                onCardSelected: { walletCard in
                    updateSelectedCardInfo(walletCard: walletCard)
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showDeleteMenu) {
            // Simplified delete menu to improve build performance
            SimpleDeleteCardsMenu(cards: $cards)
                .presentationDetents([.medium])
                .onDisappear {
                    refreshCardStack() // Refresh when returning from delete menu
                }
        }
        .sheet(isPresented: $showCoordinateInput) {
            // Coordinate input view
            manualCoordinateInputView
                .presentationDetents([.fraction(0.4)])
        }
        .sheet(isPresented: $showPlaceSearch) {
            // Use the business search controller directly
            BusinessSearchController { place in
                // Print the selected place details to console
                print("📱 Selected Business: \(place.name ?? "Unnamed")")
                
                if let address = place.formattedAddress {
                    print("📱 Address: \(address)")
                }
                
                // Print the place coordinates
                let coordinates = place.coordinate
                print("📱 Coordinates: \(coordinates.latitude), \(coordinates.longitude)")
                
                // Get the place types and find the matching reward category
                if let types = place.types, !types.isEmpty {
                    print("Original Type A Category: \(types[0])")
                    print("📱 Business Types: \(types.joined(separator: ", "))")
                    
                    // Find the proper mapped category using our category mapping
                    var mappedCategory: String = "other"
                    
                    // First try to map the primary type
                    if let mappedValue = placeTypeToRewardCategory[types[0]] {
                        mappedCategory = mappedValue
                    } 
                    
                    
                    print("📱 Mapped Reward Category: \(mappedCategory)")
                    
                    // Find best card for this business using the mapped category
                    if let bestCardInfo = walletManager.findBestCardForBusiness(
                        businessName: place.name ?? "",
                        category: mappedCategory
                    ) {
                        let bestCard = bestCardInfo.0
                        let rewardRate = bestCardInfo.1
                        
                        print("📱 Best Card: \(bestCard.issuer) \(bestCard.cardType)")
                        print("📱 Reward Rate: \(rewardRate)x points/cash back")
                        
                        // If we have a business-specific category from a co-branded card match, use it
                        if let businessCategory = bestCardInfo.2 {
                            print("📱 Using business-specific category: \(businessCategory)")
                            walletManager.selectedCategory = businessCategory
                            currentCategory = businessCategory
                        } else {
                            // Otherwise use the mapped category from the place type
                            print("📱 Using mapped category: \(mappedCategory.capitalized)")
                            walletManager.selectedCategory = mappedCategory.replacingOccurrences(of: "_", with: " ").capitalized
                            currentCategory = mappedCategory.capitalized
                        }
                        
                        // Update binding values
                        withAnimation(.spring()) {
                            hasSelectedVirtualCard = true
                            selectedCardInfo = SelectedCardInfo(
                                issuer: bestCard.issuer,
                                cardType: bestCard.cardType,
                                multiplier: rewardRate,
                                imgURL: bestCard.imgURL
                            )
                        }
                    } else {
                        print("📱 No specific card recommended for this business/category")
                        
                        // Reset to default if no recommendation
                        withAnimation(.spring()) {
                            hasSelectedVirtualCard = false
                            selectedCardInfo = SelectedCardInfo()
                        }
                    }
                } else {
                    print("📱 Business Types: Not available")
                    
                    // Reset to default if no types
                    withAnimation(.spring()) {
                        hasSelectedVirtualCard = false
                        selectedCardInfo = SelectedCardInfo()
                    }
                }
                
                // Update category if available
                if let category = walletManager.selectedCategory {
                    currentCategory = category
                    print("📊 Category updated from search: \(category)")
                }
                
                // Force refresh to update UI
                refreshCardStack()
            }
            .ignoresSafeArea()
        }
        .alert("Maximum Cards Reached", isPresented: $showMaxCardsAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You've reached the maximum limit of \(maxCards) cards. Please remove a card before adding a new one.")
        }
        .onAppear {
            refreshCardStack() // Load cards on appear
            
            // Get current category from WalletManager if available
            if let category = walletManager.selectedCategory {
                currentCategory = category
            }
        }
        // Monitor location updates
        .onChange(of: locationManager.coordinates) { _, newCoordinates in
            // Only trigger if this is not the default placeholder or loading text
            if !newCoordinates.contains("Tap to get location") && 
               !newCoordinates.contains("Getting location...") &&
               !locationManager.isLoading {
                // Parse coordinates and trigger place search
                print("📱 WalletView - Location updated: \(newCoordinates)")
                searchNearbyPlacesFromCoordinates(newCoordinates)
            }
        }
        // Monitor changes to WalletManager's cards
        .onChange(of: walletManager.walletCards) { _, newWalletCards in
            refreshCardStack() // Refresh when card data changes
        }
    }
}

// Simplified card deletion menu for better build performance
struct SimpleDeleteCardsMenu: View {
    @Binding var cards: [Card]
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var walletManager = WalletManager.shared
    @State private var refreshTrigger = UUID() // Add a refresh trigger
    
    // Helper function to check if a card is the virtual card
    private func isVirtualCard(_ card: Card) -> Bool {
        return card.issuer == "Virtual" && card.cardType == "Debit Card"
    }
    
    // Function to correctly delete a card
    private func deleteCard(_ card: Card) {
        // Track card deletion analytics before actually deleting
        UserAnalytics.shared.trackCardDeleted(issuer: card.issuer, cardType: card.cardType)
        
        // First delete from WalletManager (backend)
        walletManager.deleteCard(issuer: card.issuer, cardType: card.cardType)
        
        // Then update the cards array (UI)
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            cards.remove(at: index)
        }
        
        // Generate a new UUID to force view refresh
        refreshTrigger = UUID()
        
        // Log the deletion
        print("Deleted card: \(card.issuer) \(card.cardType)")
        print("Remaining cards: \(cards.count)")
    }
    
    // Helper to create a preview of the card
    @ViewBuilder
    private func cardPreview(for card: Card) -> some View {
        if let imgURL = card.imgURL, !imgURL.isEmpty {
            // Use a simplified image loader
            Color.gray.opacity(0.3) // Placeholder
                .overlay(
                    AsyncImage(url: URL(string: imgURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        case .failure(_):
                            cardGradient(for: card)
                        case .empty:
                            ProgressView().scaleEffect(0.7)
                        @unknown default:
                            cardGradient(for: card)
                        }
                    }
                )
        } else {
            cardGradient(for: card)
        }
    }
    
    // Helper to create a gradient for cards without images
    @ViewBuilder
    private func cardGradient(for card: Card) -> some View {
        LinearGradient(
            gradient: Gradient(colors: card.gradientColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Card row item component
    @ViewBuilder
    private func cardRowItem(for card: Card) -> some View {
        HStack(spacing: 12) {
            // Card image or gradient
            cardPreview(for: card)
                .frame(width: 50, height: 30)
                .cornerRadius(6)
            
            // Card details
            Text("\(card.issuer) \(card.cardType)")
                .font(.headline)
            
            Spacer()
            
            // Delete button
            Button(action: {
                withAnimation {
                    deleteCard(card)
                }
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
    
    // Empty state view
    @ViewBuilder
    private func emptyStateView() -> some View {
        Text("No cards to manage")
            .foregroundColor(.gray)
            .italic()
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
    }
    
    var body: some View {
        NavigationView {
            List {
                // Only show non-virtual cards
                let displayCards = cards.filter { !isVirtualCard($0) }
                
                if displayCards.isEmpty {
                    emptyStateView()
                } else {
                    ForEach(displayCards, id: \.id) { card in
                        cardRowItem(for: card)
                    }
                }
            }
            .id(refreshTrigger) // Force refresh when this changes
            .navigationTitle("Manage Cards")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Enhanced card selection sheet matching the VirtualCardView implementation
struct EnhancedCardSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var walletManager = WalletManager.shared
    var currentCategory: String
    var currentCardIssuer: String
    var currentCardType: String
    var onCardSelected: (WalletCard) -> Void
    
    @State private var selectedCardId: UUID? = nil
    
    // Sort cards by reward rate for the current category
    private func sortedCardsByRewardRate() -> [WalletCard] {
        // Filter out the virtual card
        let realCards = walletManager.walletCards.filter { $0.issuer != "Virtual" }
        
        // Determine current category
        let category = currentCategory != "Category" ? currentCategory.lowercased() : "other"
        
        // Sort cards by reward rate for the current category
        return realCards.sorted { (card1, card2) in
            let rate1 = card1.getRewardRate(for: category) ?? 1.0
            let rate2 = card2.getRewardRate(for: category) ?? 1.0
            return rate1 > rate2  // Descending order
        }
    }
    
    // Format multiplier percentage
    private func formatMultiplier(_ value: Double) -> String {
        // Check if the decimal part is zero
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))%" // Display as integer
        } else {
            return "\(String(format: "%.1f", value))%" // Display with one decimal place
        }
    }
    
    // Card preview component
    @ViewBuilder
    private func cardPreview(for card: WalletCard) -> some View {
        if let imageURL = card.imgURL, !imageURL.isEmpty {
            AsyncImage(url: URL(string: imageURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .failure(_), .empty:
                    // Fallback to gradient if image loading fails
                    cardGradient(for: card)
                @unknown default:
                    cardGradient(for: card)
                }
            }
        } else {
            // Use the card's gradient colors if no image is available
            cardGradient(for: card)
        }
    }
    
    // Card gradient helper
    @ViewBuilder
    private func cardGradient(for card: WalletCard) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: card.gradientColors),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    // Reward rate text component
    @ViewBuilder
    private func rewardRateText(for card: WalletCard) -> some View {
        if currentCategory != "Category" {
            let rewardRate = card.getRewardRate(for: currentCategory.lowercased()) ?? 1.0
            let categoryDisplay = currentCategory
            
            Text("\(formatMultiplier(rewardRate)) on \(categoryDisplay)")
                .font(.caption)
                .foregroundColor(.green)
        } else {
            Text("1% base rewards")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    // Card row component
    @ViewBuilder
    private func cardRow(for card: WalletCard) -> some View {
        HStack {
            // Card image or gradient representation
            cardPreview(for: card)
                .frame(width: 60, height: 40)
                .cornerRadius(5)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(card.issuer) \(card.cardType)")
                    .font(.headline)
                
                // Calculate and display reward info
                rewardRateText(for: card)
            }
            
            Spacer()
            
            // Check mark if card is selected
            if let selectedId = selectedCardId, selectedId == card.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 8)
    }
    
    var body: some View {
        NavigationView {
            List {
                // Filter out the virtual card and sort by reward rate for current context
                ForEach(sortedCardsByRewardRate()) { card in
                    Button(action: {
                        // Update selected card
                        selectedCardId = card.id
                        
                        // Call the callback with the selected card
                        onCardSelected(card)
                        
                        // Dismiss the sheet
                        dismiss()
                    }) {
                        cardRow(for: card)
                    }
                }
            }
            .navigationTitle("Switch Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Find the currently selected card if any
                if currentCardIssuer != "Virtual" && !currentCardIssuer.isEmpty {
                    if let card = walletManager.walletCards.first(where: { 
                        $0.issuer == currentCardIssuer && $0.cardType == currentCardType 
                    }) {
                        selectedCardId = card.id
                        print("Found initially selected card: \(card.issuer) \(card.cardType)")
                    }
                }
            }
        }
    }
}

#Preview {
    WalletView()
        .preferredColorScheme(.dark)
}
