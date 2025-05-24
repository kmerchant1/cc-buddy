//
//  VirtualCardView.swift
//  Boost
//
//  Created for Best Card Feature
//

import SwiftUI
import CoreLocation
import GooglePlaces

// Controller for handling place autocomplete
struct PlaceAutocompleteController: UIViewControllerRepresentable {
    var onPlaceSelected: (GMSPlace) -> Void
    
    // Coordinator to act as the delegate
    class Coordinator: NSObject, GMSAutocompleteViewControllerDelegate {
        var parent: PlaceAutocompleteController
        
        init(_ parent: PlaceAutocompleteController) {
            self.parent = parent
        }
        
        // MARK: - GMSAutocompleteViewControllerDelegate
        
        func viewController(_ viewController: GMSAutocompleteViewController, didAutocompleteWith place: GMSPlace) {
            // Call the completion handler with the selected place
            parent.onPlaceSelected(place)
            
            // Dismiss the controller
            viewController.dismiss(animated: true)
        }
        
        func viewController(_ viewController: GMSAutocompleteViewController, didFailAutocompleteWithError error: Error) {
            print("📱 Place Autocomplete Error: \(error.localizedDescription)")
            viewController.dismiss(animated: true)
        }
        
        func wasCancelled(_ viewController: GMSAutocompleteViewController) {
            viewController.dismiss(animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> GMSAutocompleteViewController {
        let autocompleteController = GMSAutocompleteViewController()
        autocompleteController.delegate = context.coordinator
        
        // Configure the autocomplete filter
        let filter = GMSAutocompleteFilter()
        filter.types = ["establishment"] // Focus on businesses
        autocompleteController.autocompleteFilter = filter
        
        // Customize UI if needed
        UINavigationBar.appearance().tintColor = UIColor(red: 0.5, green: 0, blue: 0.5, alpha: 1.0) // Purple
        
        return autocompleteController
    }
    
    func updateUIViewController(_ uiViewController: GMSAutocompleteViewController, context: Context) {
        // Updates to the controller if needed
    }
}

struct VirtualCardView: View {
    @State private var selectedCategory: String = "Category"
    @StateObject private var locationManager = BasicLocation()
    @State private var showLocationTooltip = false
    @State private var showCoordinateInput = false
    @State private var latitudeInput: String = ""
    @State private var longitudeInput: String = ""
    @State private var placeResults: [GMSPlace] = []
    @State private var showPlaceSearch = false
    @State private var selectedPlace: GMSPlace?
    @State private var showNearbyPlacesSheet = false
    @State private var topNearbyPlaces: [GMSPlace] = []
    @State private var selectedCard: WalletCard? = nil
    @State private var showWalletButton: Bool = false
    @State private var showLocationOptions = false
    @State private var bestMultiplier: Double = 0.0  // Store the best multiplier for display
    @State private var showCardSelectionSheet = false // For card switching UI
    @State private var mappedCategory: String = "" // Add this to store the mapped category for display
    @State private var isSearchingNearbyPlaces: Bool = false // Track loading state for nearby places search
    @State private var isUpdatingFromPlaceSelection: Bool = false // Flag to prevent loops
    @State private var hasSelectedBusiness: Bool = false // Track if a business has been selected
    
    // Public properties to expose currently selected card information
    @Binding var hasSelectedCard: Bool
    @Binding var selectedCardInfo: SelectedCardInfo
    
    // Add a binding for the parent to control showing nearby places
    @Binding private var showNearbyPlacesFromParent: Bool
    
    // Default initializer with empty bindings for standalone usage (like in previews)
    init() {
        self._hasSelectedCard = .constant(false)
        self._selectedCardInfo = .constant(SelectedCardInfo())
        self._showNearbyPlacesFromParent = .constant(false)
    }
    
    // Initializer with bindings to pass data up to parent views
    init(hasSelectedCard: Binding<Bool>, selectedCardInfo: Binding<SelectedCardInfo>, showNearbyPlaces: Binding<Bool>? = nil) {
        self._hasSelectedCard = hasSelectedCard
        self._selectedCardInfo = selectedCardInfo
        self._showNearbyPlacesFromParent = showNearbyPlaces ?? .constant(false)
    }
    
    // Initializer that also accepts an external location manager for sharing
    init(hasSelectedCard: Binding<Bool>, selectedCardInfo: Binding<SelectedCardInfo>, locationManager: BasicLocation? = nil, showNearbyPlaces: Binding<Bool>? = nil) {
        self._hasSelectedCard = hasSelectedCard
        self._selectedCardInfo = selectedCardInfo
        
        if let locationManager = locationManager {
            self._locationManager = StateObject(wrappedValue: locationManager)
        }
        
        // Store the showNearbyPlaces binding if provided
        self._showNearbyPlacesFromParent = showNearbyPlaces ?? .constant(false)
    }
    
    // Replace with your actual API key
    private let googlePlacesAPIKey = "AIzaSyB9Ra-r1SKi0_B60CBvgXKr7xu04hTT6po"
    
    // Mapping from place types to reward categories
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
        "catering_service": "dining",
        "chinese_restaurant": "dining",
        "chocolate_factory": "dining",
        "chocolate_shop": "dining",
        "coffee_shop": "dining",
        "car_rental": "rental_cars",
        "confectionery": "dining",
        "deli": "dining",
        "dessert_restaurant": "dining",
        "dessert_shop": "dining",
        "diner": "dining",
        "dog_cafe": "dining",
        "donut_shop": "dining",
        "fast_food_restaurant": "dining",
        "fine_dining_restaurant": "dining",
        "food": "dining",
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
    
    // Helper to format the multiplier percentage
    private func formatMultiplier(_ value: Double) -> String {
        // Check if the decimal part is zero
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))%" // Display as integer
        } else {
            return "\(String(format: "%.1f", value))%" // Display with one decimal place
        }
    }
    
    var body: some View {
        // Card itself (now acts as a location button)
        ZStack(alignment: .bottom) {
            // Card background - dynamic based on selected card or selectedCardInfo
            if let selectedCard = selectedCard, let imageURL = selectedCard.imgURL, !imageURL.isEmpty {
                // Use the selected card image as background if available (from location-based selection)
                CardBackgroundWithImage(imageURL: imageURL)
            } else if let imageURL = selectedCardInfo.imgURL, !imageURL.isEmpty {
                // Use the selectedCardInfo image if available (from card switching)
                CardBackgroundWithImage(imageURL: imageURL)
            } else if let selectedCard = selectedCard {
                // Use the card's gradient colors if no image is available
                cardGradientBackground(for: selectedCard)
            } else if hasSelectedCard {
                // Use gradient based on issuer from selectedCardInfo
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: getGradientColorsForIssuer(selectedCardInfo.issuer)),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)
                    .shadow(radius: 10)
            } else {
                // Default gradient if no card is selected
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black, Color.gray.opacity(1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)
                    .shadow(radius: 10)
            }
            
            // Card content overlay
            VStack(spacing: 0) {
                // Top section
                HStack {
                    Spacer()
                }
                .padding(.top, 10)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: 200)
            
            // Loading indicator for location
            if locationManager.isLoading {
                VStack {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                            .padding(.top, 15)
                            .padding(.leading, 15)
                        Spacer()
                    }
                    Spacer()
                }
                .frame(height: 200)
                .zIndex(101)
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture(perform: {
            // Always execute the nearby businesses feature when VirtualCardView is tapped
            print("📱 VirtualCardView tapped - Getting device location for nearby businesses")
            getDeviceLocation()
        })

        .onAppear {
            print("📱 Virtual Card appeared")
            setupGooglePlaces()
            
            // Initialize with the virtual card or use existing selection
            if !hasSelectedCard {
                self.selectedCard = WalletCard.virtualCard
                self.showWalletButton = false // Keep for backward compatibility
                self.bestMultiplier = 0.0
            } else {
                // If a card is already selected (from parent view), show the wallet button
                self.showWalletButton = selectedCardInfo.issuer != "Virtual" // Keep for backward compatibility
                
                // Update mapped category if available from WalletManager
                if let category = WalletManager.shared.selectedCategory {
                    self.mappedCategory = category.lowercased()
                }
            }
        }
        .sheet(isPresented: $showCoordinateInput) {
            manualCoordinateInputView
                .presentationDetents([.fraction(0.4)])
        }
        .sheet(isPresented: $showPlaceSearch) {
            BusinessSearchController { place in
                handleSelectedPlace(place)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showNearbyPlacesSheet) {
            nearbyPlaceSelectionView
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showCardSelectionSheet) {
            cardSelectionView
                .presentationDetents([.medium])
        }
        .onChange(of: selectedCardInfo) { _, newInfo in
            // Update wallet button visibility when selectedCardInfo changes
            if hasSelectedCard && newInfo.issuer != "Virtual" {
                self.showWalletButton = true // Keep for backward compatibility
            } else if newInfo.issuer == "Virtual" {
                self.showWalletButton = false // Keep for backward compatibility
            }
        }
        .onChange(of: hasSelectedCard) { _, isSelected in
            // Reset card state when parent resets selection
            if !isSelected {
                withAnimation(.spring()) {
                    self.selectedCard = WalletCard.virtualCard
                    self.showWalletButton = false // Keep for backward compatibility
                    self.bestMultiplier = 0.0
                    // Reset the business selection flag
                    self.hasSelectedBusiness = false
                    print("📱 Card selection reset from parent view")
                }
            }
        }
        // Add a listener for the showNearbyPlacesFromParent flag
        .onChange(of: showNearbyPlacesFromParent) { _, shouldShow in
            // Don't show nearby places if a business has already been selected
            if hasSelectedBusiness {
                print("📱 Skipping nearby places from parent - business already selected")
                // Reset the flag immediately
                DispatchQueue.main.async {
                    showNearbyPlacesFromParent = false
                }
                return
            }
            
            if shouldShow {
                // Only process if we have valid coordinates
                if !locationManager.coordinates.contains("Tap to get location") && 
                   !locationManager.coordinates.contains("Getting location...") &&
                   !locationManager.isLoading {
                    // Parse coordinates and search for nearby places
                    print("📱 Showing nearby places from parent request")
                    searchNearbyPlacesFromCoordinates(locationManager.coordinates)
                    
                    // Reset the flag after processing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showNearbyPlacesFromParent = false
                    }
                }
            }
        }
        // Add a listener for location coordinate changes to trigger nearby places search
        .onChange(of: locationManager.coordinates) { _, newCoordinates in
            // Don't trigger if a business has already been selected
            if hasSelectedBusiness {
                return
            }
            
            // Don't process coordinates with the SELECTED prefix
            if newCoordinates.hasPrefix("SELECTED:") {
                print("📱 Skipping nearby places search for selected business coordinates")
                return
            }
            
            // Only trigger if this is not the default placeholder or loading text
            // AND we are not currently updating from a place selection
            if !newCoordinates.contains("Tap to get location") && 
               !newCoordinates.contains("Getting location...") &&
               !locationManager.isLoading &&
               !isUpdatingFromPlaceSelection {
                // Parse coordinates and search for nearby places
                print("📱 Device location updated: \(newCoordinates)")
                searchNearbyPlacesFromCoordinates(newCoordinates)
            }
        }
    }
    
    // Handle the selected place from autocomplete
    public func handleSelectedPlace(_ place: GMSPlace) {
        self.selectedPlace = place
        
        // Set flags to prevent triggering nearby places search again
        isUpdatingFromPlaceSelection = true
        hasSelectedBusiness = true
        
        // Dismiss nearby places sheet immediately
        showNearbyPlacesSheet = false
        
        // Print the selected place details to console
        print("📱 Selected Business: \(place.name ?? "Unnamed")")
        
        if let address = place.formattedAddress {
            print("📱 Address: \(address)")
        }
        
        // Print the place coordinates
        let coordinates = place.coordinate
        print("📱 Coordinates: \(coordinates.latitude), \(coordinates.longitude)")
        
        // Print business types/categories
        if let types = place.types, !types.isEmpty {
            print("Original Type A Category: \(types[0])")
            print("📱 Business Types: \(types.joined(separator: ", "))")
            
            // Find a matching reward category
            var matchedCategory: String? = nil
            
            // First check if any of the place types exactly match our mapping dictionary keys
            
            matchedCategory = placeTypeToRewardCategory[types[0]] 
            if matchedCategory == nil {
                matchedCategory = "other"
            }
            
            if let category = matchedCategory {
                print("Original Type A Category: \(types[0])")
                print("📱 Mapped Reward Category: \(category)")
                
                // Store the mapped category in WalletManager and local state
                WalletManager.shared.selectedCategory = category.capitalized
                self.mappedCategory = category // Store locally even though we don't display it
                
                // Find and recommend thee best card for this business and category
                if let bestCardInfo = WalletManager.shared.findBestCardForBusiness(
                    businessName: place.name ?? "",
                    category: category
                ) {
                    let bestCard = bestCardInfo.0
                    let rewardRate = bestCardInfo.1
                    
                    print("📱 Best Card Recommendation: \(bestCard.issuer) \(bestCard.cardType)")
                    print("📱 Reward Rate: \(rewardRate)x points/cash back")
                    
                    // Set the selected card, show the wallet button, and store multiplier
                    withAnimation(.spring()) {
                        self.selectedCard = bestCard
                        self.showWalletButton = true // Keep for backward compatibility
                        self.bestMultiplier = rewardRate // Store the multiplier
                        
                        // Update bindings for parent view
                        self.hasSelectedCard = true
                        self.selectedCardInfo = SelectedCardInfo(
                            issuer: bestCard.issuer, 
                            cardType: bestCard.cardType, 
                            multiplier: rewardRate,
                            imgURL: bestCard.imgURL
                        )
                    }
                } else {
                    print("📱 No specific card recommended for this business/category")
                    
                    // Reset to default virtual card if no recommendation
                    withAnimation(.spring()) {
                        self.selectedCard = WalletCard.virtualCard
                        self.showWalletButton = false // Keep for backward compatibility
                        self.bestMultiplier = 0.0
                        
                        // Update bindings for parent view
                        self.hasSelectedCard = false
                        self.selectedCardInfo = SelectedCardInfo()
                    }
                }
            }
        } else {
            print("📱 Business Types: Not available")
            
            // Reset to default virtual card
            withAnimation(.spring()) {
                self.selectedCard = WalletCard.virtualCard
                self.showWalletButton = false // Keep for backward compatibility
                self.bestMultiplier = 0.0
                
                // Update bindings for parent view
                self.hasSelectedCard = false
                self.selectedCardInfo = SelectedCardInfo()
            }
        }
        
        // Print additional useful information
        if place.rating != 0 {
            print("📱 Rating: \(place.rating)/5.0")
        }
        
        // Print place ID
        if let placeID = place.placeID {
            print("📱 Place ID: \(placeID)")
        }
        
        // Update location manager with the place coordinates
        // Use a special prefix to indicate this is from a place selection
        // and should not trigger the nearby places UI
        let coordinateString = String(format: "SELECTED:%.6f, %.6f", coordinates.latitude, coordinates.longitude)
        locationManager.coordinates = coordinateString
        
        // Reset the update flag after a delay to allow the update to complete
        // Use a slightly longer delay to ensure all UI updates are complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isUpdatingFromPlaceSelection = false
            print("📱 Reset isUpdatingFromPlaceSelection flag")
        }
    }
    
    // Initialize Google Places
    private func setupGooglePlaces() {
        GMSPlacesClient.provideAPIKey(googlePlacesAPIKey)
        print("📱 Google Places initialized")
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
                searchNearbyPlaces()
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
        
        // Reset the business selection flag when entering new coordinates
        hasSelectedBusiness = false
        
        // Try to convert to numeric values
        if let lat = Double(latitudeInput), let lon = Double(longitudeInput) {
            let coordinateString = String(format: "%.6f, %.6f", lat, lon)
            locationManager.coordinates = coordinateString
            locationManager.errorMessage = nil
            
            // Print to console for debugging
            print("📱 Manual coordinates entered: \(coordinateString)")
        } else {
            locationManager.errorMessage = "Invalid coordinates format"
        }
    }
    
    // View for selecting a nearby place
    private var nearbyPlaceSelectionView: some View {
        NavigationView {
            ZStack {
                List {
                    ForEach(topNearbyPlaces, id: \.placeID) { place in
                        Button(action: {
                            handleSelectedPlace(place)
                            showNearbyPlacesSheet = false
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(place.name ?? "Unnamed Place")
                                    .font(.headline)
                                
                                if let address = place.formattedAddress {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    if place.rating > 0 {
                                        HStack(spacing: 2) {
                                            Text(String(format: "%.1f", place.rating))
                                                .font(.caption)
                                            
                                            Image(systemName: "star.fill")
                                                .foregroundColor(.yellow)
                                                .font(.caption)
                                        }
                                    }
                                    
                                    if let types = place.types, !types.isEmpty {
                                        Spacer()
                                        
                                        // Show the category that we mapped to
                                        let rawCategory = placeTypeToRewardCategory[types[0]] ?? "other"
                                        
                                        Text(rawCategory.capitalized)
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.2))
                                            .cornerRadius(4)
                                        
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                // Show loading indicator when searching
                if isSearchingNearbyPlaces {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                            .padding(.bottom, 10)
                        
                        Text("Discovering nearby businesses...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                        
                        Text("This might take a moment")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground).opacity(0.9))
                    .edgesIgnoringSafeArea(.all)
                } else if topNearbyPlaces.isEmpty && !isSearchingNearbyPlaces {
                    // Show empty state message when no places found
                    VStack(spacing: 10) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                            .padding(.bottom, 10)
                        
                        Text("No businesses found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Try a different location or search radius")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Nearby Businesses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showNearbyPlacesSheet = false
                    }
                }
            }
        }
    }
    
    // View for selecting a card from wallet
    private var cardSelectionView: some View {
        NavigationView {
            List {
                // Filter out the virtual card and sort by reward rate for current context
                ForEach(sortedCardsByRewardRate()) { card in
                    Button(action: {
                        withAnimation(.spring()) {
                            self.selectedCard = card
                            // Find the reward rate for the current category or place
                            let rewardMultiplier: Double
                            if let place = selectedPlace {
                                if let types = place.types, !types.isEmpty {
                                    let matchedCategory = placeTypeToRewardCategory[types[0]] ?? "other"
                                    self.mappedCategory = matchedCategory // Update the mapped category for display
                                    rewardMultiplier = card.getRewardRate(for: matchedCategory) ?? 1.0
                                } else {
                                    rewardMultiplier = 1.0 // Default
                                }
                            } else if !mappedCategory.isEmpty {
                                rewardMultiplier = card.getRewardRate(for: mappedCategory) ?? 1.0
                            } else {
                                rewardMultiplier = 1.0 // Default
                            }
                            self.bestMultiplier = rewardMultiplier
                            self.showWalletButton = (card.issuer != "Virtual") // Keep for backward compatibility
                            
                            // Update parent bindings as well
                            self.hasSelectedCard = (card.issuer != "Virtual")
                            self.selectedCardInfo = SelectedCardInfo(
                                issuer: card.issuer,
                                cardType: card.cardType,
                                multiplier: rewardMultiplier,
                                imgURL: card.imgURL
                            )
                        }
                        showCardSelectionSheet = false
                    }) {
                        HStack {
                            // Card image or gradient representation
                            if let imageURL = card.imgURL, !imageURL.isEmpty {
                                AsyncImage(url: URL(string: imageURL)) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 60, height: 40)
                                            .cornerRadius(5)
                                    case .failure(_), .empty:
                                        // Fallback to gradient if image loading fails
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: card.gradientColors),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 60, height: 40)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            } else {
                                // Use the card's gradient colors if no image is available
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: card.gradientColors),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 60, height: 40)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(card.issuer) \(card.cardType)")
                                    .font(.headline)
                                
                                // Calculate and display reward info
                                Group {
                                    if let place = selectedPlace {
                                        if let types = place.types, !types.isEmpty {
                                            let matchedCategory = placeTypeToRewardCategory[types[0]] ?? "other"
                                            let rewardRate = card.getRewardRate(for: matchedCategory) ?? 1.0
                                            Text("\(formatMultiplier(rewardRate)) on \(matchedCategory.capitalized)")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        } else {
                                            Text("1% base rewards")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    } else if !mappedCategory.isEmpty {
                                        let rewardRate = card.getRewardRate(for: mappedCategory) ?? 1.0
                                        Text("\(formatMultiplier(rewardRate)) on \(mappedCategory.capitalized)")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    } else {
                                        Text("1% base rewards")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Check mark if card is selected - using simpler conditions
                            let isSelectedViaLocalState = selectedCard?.id == card.id
                            let isSelectedViaParentBinding = hasSelectedCard && 
                                                         selectedCardInfo.issuer == card.issuer && 
                                                         selectedCardInfo.cardType == card.cardType
                            
                            if isSelectedViaLocalState || isSelectedViaParentBinding {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Switch Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showCardSelectionSheet = false
                    }
                }
            }
        }
    }
    
    // Sort cards by reward rate for the current context
    private func sortedCardsByRewardRate() -> [WalletCard] {
        // Filter out the virtual card
        let realCards = WalletManager.shared.walletCards.filter { $0.issuer != "Virtual" }
        
        // Determine current category or context
        let currentCategory: String
        if let place = selectedPlace, let types = place.types, !types.isEmpty {
            currentCategory = placeTypeToRewardCategory[types[0]] ?? "other"
            // Update the mapped category for display
            self.mappedCategory = currentCategory
        } else if !mappedCategory.isEmpty {
            currentCategory = mappedCategory
        } else {
            currentCategory = "other"
        }
        
        // Sort cards by reward rate for the current category
        return realCards.sorted { (card1, card2) in
            let rate1 = card1.getRewardRate(for: currentCategory) ?? 1.0
            let rate2 = card2.getRewardRate(for: currentCategory) ?? 1.0
            return rate1 > rate2  // Descending order
        }
    }
    
    // Search for nearby places using Google Places API
    private func searchNearbyPlaces() {
        guard let lat = Double(latitudeInput), let lon = Double(longitudeInput) else {
            locationManager.errorMessage = "Invalid coordinates format"
            return
        }
        
        // Reset the business selection flag when initiating a new search
        hasSelectedBusiness = false
        
        // Clear previous results
        placeResults = []
        topNearbyPlaces = []
        
        // Set loading state
        isSearchingNearbyPlaces = true
        
        print("📱 Starting nearby search at coordinates: \(lat), \(lon)")
        
        // Show selection sheet immediately (will show loading state)
        showNearbyPlacesSheet = true
        
        // Define the search area (1000 meter diameter circle)
        let coordinates = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let circularLocationRestriction = GMSPlaceCircularLocationOption(coordinates, 100) // 100m radius
        
        // Specify the fields to return in the GMSPlace object for each place
        let placeProperties = [
            GMSPlaceProperty.name,
            GMSPlaceProperty.formattedAddress,
            GMSPlaceProperty.coordinate,
            GMSPlaceProperty.types,
            GMSPlaceProperty.rating,
            GMSPlaceProperty.placeID,
        ].map { $0.rawValue }
        
        // Create the search request
        var request = GMSPlaceSearchNearbyRequest(
            locationRestriction: circularLocationRestriction,
            placeProperties: placeProperties
        )
        
        // Set types of places to search for - let's focus on businesses
        let excludedTypes = ["shopping_mall"]
        request.excludedTypes = excludedTypes
        request.rankPreference = .popularity // Sort by popularity. i think this is default
        
        // Define callback for handling search results
        let callback: GMSPlaceSearchNearbyResultCallback = { results, error in
            // Update on main thread since this affects UI
            DispatchQueue.main.async {
                // Set loading state to false
                self.isSearchingNearbyPlaces = false
                
                if let error = error {
                    print("📱 Places API Error: \(error.localizedDescription)")
                    return
                }
                
                guard let results = results as? [GMSPlace] else {
                    print("📱 No places found or invalid results format")
                    return
                }
                
                // Store results and print to console
                self.placeResults = results
                
                // Get top 10 (or fewer if less than 10 are returned)
                let topPlaces = Array(results.prefix(10))
                self.topNearbyPlaces = topPlaces
                
                print("📱 Found \(results.count) places near \(lat), \(lon), showing top \(topPlaces.count):")
                
                for (index, place) in topPlaces.enumerated() {
                    print("📱 #\(index+1) - \(place.name ?? "Unnamed")")
                    if let placeID = place.placeID {
                        print("📱    Place ID: \(placeID)")
                    }
                    if let address = place.formattedAddress {
                        print("📱    Address: \(address)")
                    }
                    if let types = place.types {
                        print("📱    Types: \(types.joined(separator: ", "))")
                    }
                    if place.rating != 0 {
                        print("📱    Rating: \(place.rating)/5.0")
                    }
                    
                    let placeCoord = place.coordinate
                    print("📱    Coordinates: \(placeCoord.latitude), \(placeCoord.longitude)")
                    print("") // Empty line for separation
                }
            }
        }
        
        // Execute the search
        GMSPlacesClient.shared().searchNearby(with: request, callback: callback)
    }
    
    // Add a helper function for creating the card gradient background
    private func cardGradientBackground(for card: WalletCard) -> some View {
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
    
    // Add a function to open Apple Wallet and reset the card state
    private func openAppleWallet() {
        // Track payment usage analytics before resetting
        if hasSelectedCard && selectedCardInfo.issuer != "Virtual" {
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
            self.hasSelectedCard = false
            self.selectedCardInfo = SelectedCardInfo()
            
            // Reset other state variables
            self.selectedCard = WalletCard.virtualCard
            self.showWalletButton = false
            self.bestMultiplier = 0.0
            self.mappedCategory = ""
            self.hasSelectedBusiness = false
        }
        
        // Using URL scheme to open Apple Wallet
        if let walletURL = URL(string: "shoebox://") {
            UIApplication.shared.open(walletURL, options: [:]) { success in
                if !success {
                    print("📱 Could not open Apple Wallet")
                }
                else {
                    print("📱 Opened Apple Wallet")
                }
            }
        }
    }
    
    // Helper function to render card background with image
    @ViewBuilder
    private func CardBackgroundWithImage(imageURL: String) -> some View {
        AsyncImage(url: URL(string: imageURL)) { phase in
            switch phase {
            case .empty:
                // Loading state with subtle pulse animation
                gradientFallback(for: selectedCard ?? WalletCard.virtualCard)
                    .transition(.identity)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(radius: 10)
                    .transition(
                        .asymmetric(
                            insertion: 
                                .opacity
                                .combined(with: .scale(scale: 0.9, anchor: .center))
                                .combined(with: .offset(y: 20))
                                .animation(.spring(response: 0.4, dampingFraction: 0.8)),
                            removal: 
                                .opacity
                                .combined(with: .scale(scale: 0.95))
                                .animation(.easeOut(duration: 0.2))
                        )
                    )
            case .failure(_):
                // Fallback to gradient if image loading fails
                gradientFallback(for: selectedCard ?? WalletCard.virtualCard)
                    .overlay(
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.system(size: 30))
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            
            @unknown default:
                gradientFallback(for: selectedCard ?? WalletCard.virtualCard)
            }
        }
        .id(imageURL) // Force view refresh when URL changes
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: imageURL)
    }
    
    // Helper function for gradient fallback
    @ViewBuilder
    private func gradientFallback(for card: WalletCard) -> some View {
        if card.issuer == "Virtual" {
            // Default virtual card gradient
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black, Color.gray.opacity(1)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)
                .shadow(radius: 10)
        } else {
            cardGradientBackground(for: card)
        }
    }
    
    // Helper function to get gradient colors for an issuer
    private func getGradientColorsForIssuer(_ issuer: String) -> [Color] {
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
        case "virtual":
            return [Color.black, Color.gray.opacity(1)]
        default:
            return [Color.black, Color.gray.opacity(0.8)]
        }
    }
    
    // Public function to trigger search from outside
    public func triggerPlaceSearch() {
        showPlaceSearch = true
    }
    
    // Search for nearby places using coordinates provided by the location manager
    private func searchNearbyPlacesFromCoordinates(_ coordinatesString: String) {
        // Don't search if we're currently updating from a place selection
        if isUpdatingFromPlaceSelection {
            print("📱 Skipping nearby places search - currently updating from selection")
            return
        }
        
        // Don't search if a business has already been selected
        if hasSelectedBusiness {
            print("📱 Skipping nearby places search - business already selected")
            // Ensure the sheet is not shown
            if showNearbyPlacesSheet {
                showNearbyPlacesSheet = false
                print("📱 Forcing nearby places sheet to close")
            }
            return
        }
        
        // Don't process coordinates with the SELECTED prefix
        if coordinatesString.hasPrefix("SELECTED:") {
            print("📱 Skipping nearby places search for selected business coordinates")
            return
        }
        
        // Parse coordinates string in format "latitude, longitude"
        let components = coordinatesString.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        
        guard components.count == 2,
              let latitude = Double(components[0]),
              let longitude = Double(components[1]) else {
            print("📱 Error parsing coordinates: \(coordinatesString)")
            return
        }
        
        // Store as temporary inputs so we can reuse the existing search function
        self.latitudeInput = String(latitude)
        self.longitudeInput = String(longitude)
        
        print("📱 Searching for nearby places at coordinates: \(latitude), \(longitude)")
        
        // Use the existing nearby places search function
        searchNearbyPlaces()
    }
    
    // Function to handle device location request from location options
    private func getDeviceLocation() {
        // Reset the business selection flag when explicitly requesting location
        hasSelectedBusiness = false
        
        // Start getting location
        locationManager.getLocation()
    }
}

struct BottomRoundedRectangle: Shape {
    var radius: CGFloat = 20

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.bottomLeft, .bottomRight],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    VirtualCardView()
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
} 
