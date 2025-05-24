//
//  BusinessSearchController.swift
//  Boost
//
//  Created for Business Search Feature
//

import SwiftUI
import GooglePlaces
import UIKit
import Combine

// SwiftUI wrapper for the custom business search controller
struct BusinessSearchController: UIViewControllerRepresentable {
    var onBusinessSelected: (GMSPlace) -> Void
    
    func makeUIViewController(context: Context) -> CustomBusinessSearchViewController {
        let controller = CustomBusinessSearchViewController()
        controller.onPlaceSelected = onBusinessSelected
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CustomBusinessSearchViewController, context: Context) {
        // No updates needed
    }
}

// Custom view controller that provides a fully tailored search experience
class CustomBusinessSearchViewController: UIViewController {
    // Callback for when a place is selected
    var onPlaceSelected: ((GMSPlace) -> Void)?
    
    // UI components
    private lazy var searchBar: UISearchBar = {
        let bar = UISearchBar()
        bar.placeholder = "Search for businesses"
        bar.delegate = self
        bar.showsCancelButton = true
        bar.searchBarStyle = .minimal
        bar.tintColor = UIColor(red: 0.5, green: 0, blue: 0.5, alpha: 1.0) // Purple
        return bar
    }()
    
    private lazy var tableView: UITableView = {
        let table = UITableView()
        table.register(UITableViewCell.self, forCellReuseIdentifier: "BusinessCell")
        table.delegate = self
        table.dataSource = self
        return table
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // Places API components
    private var token: GMSAutocompleteSessionToken?
    private let placesClient = GMSPlacesClient.shared()
    
    // Data
    private var predictions: [GMSAutocompletePrediction] = []
    private var uniqueBusinessNames: [String: GMSAutocompletePrediction] = [:]
    private var filteredPredictions: [GMSAutocompletePrediction] = []
    
    // Debouncing search
    private var searchWorkItem: DispatchWorkItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        resetToken()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchBar.becomeFirstResponder() // Automatically focus the search bar
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add search bar at the top
        view.addSubview(searchBar)
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // Add table view for results
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Add loading indicator
        view.addSubview(loadingIndicator)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // Reset the session token (should be done for each new search session)
    private func resetToken() {
        token = GMSAutocompleteSessionToken.init()
    }
    
    // Extract just the business name from a prediction
    private func extractBusinessName(from prediction: GMSAutocompletePrediction) -> String {
        var businessName = prediction.attributedPrimaryText.string
        
        // Further clean up the name - remove text after comma, dash, etc.
        let separators = CharacterSet(charactersIn: ",-–(")
        if let cleanerName = businessName.components(separatedBy: separators).first {
            businessName = cleanerName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return businessName
    }
    
    // Perform the search with debouncing
    private func performSearch(query: String) {
        // Cancel any pending search
        searchWorkItem?.cancel()
        
        // Show loading if this is the first search
        if predictions.isEmpty {
            loadingIndicator.startAnimating()
        }
        
        // Create a new work item for this search
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, !query.isEmpty else { return }
            
            // Create filter for businesses only
            let filter = GMSAutocompleteFilter()
            filter.types = ["establishment"]
            
            // Perform the search
            self.placesClient.findAutocompletePredictions(
                fromQuery: query,
                filter: filter,
                sessionToken: self.token
            ) { [weak self] (predictions, error) in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.loadingIndicator.stopAnimating()
                    
                    // Handle any errors
                    if let error = error {
                        print("Place autocomplete error: \(error.localizedDescription)")
                        return
                    }
                    
                    // Process results if available
                    if let predictions = predictions {
                        self.processPredictions(predictions)
                    }
                }
            }
        }
        
        // Store the work item and schedule after a delay
        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
    
    // Process predictions and filter for unique business names
    private func processPredictions(_ predictions: [GMSAutocompletePrediction]) {
        self.predictions = predictions
        self.uniqueBusinessNames.removeAll()
        
        // Keep only the first instance of each business name
        for prediction in predictions {
            let businessName = extractBusinessName(from: prediction)
            if uniqueBusinessNames[businessName] == nil {
                uniqueBusinessNames[businessName] = prediction
            }
        }
        
        // Update filtered predictions list with only unique businesses
        self.filteredPredictions = Array(uniqueBusinessNames.values)
        
        // Reload the table on the main thread
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    // Fetch full place details when a prediction is selected
    private func fetchPlaceDetails(for prediction: GMSAutocompletePrediction) {
        loadingIndicator.startAnimating()
        
        let placeFields: GMSPlaceField = [.name, .formattedAddress, .coordinate, 
                                          .types, .rating, .placeID]
        
        placesClient.fetchPlace(fromPlaceID: prediction.placeID,
                               placeFields: placeFields,
                               sessionToken: token) { [weak self] (place, error) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.loadingIndicator.stopAnimating()
                
                if let error = error {
                    print("Error fetching place details: \(error.localizedDescription)")
                    return
                }
                
                if let place = place {
                    // Place fetched successfully, pass to callback
                    self.onPlaceSelected?(place)
                    
                    // Dismiss this view controller
                    self.dismiss(animated: true)
                    
                    // Reset token for next session
                    self.resetToken()
                }
            }
        }
    }
}

// MARK: - UISearchBarDelegate
extension CustomBusinessSearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            // Clear results if search field is empty
            predictions = []
            filteredPredictions = []
            uniqueBusinessNames.removeAll()
            tableView.reloadData()
            loadingIndicator.stopAnimating()
        } else {
            performSearch(query: searchText)
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        dismiss(animated: true)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - UITableViewDataSource
extension CustomBusinessSearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredPredictions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BusinessCell", for: indexPath)
        
        // Configure the cell
        if indexPath.row < filteredPredictions.count {
            let prediction = filteredPredictions[indexPath.row]
            
            // Display only the business name (not address)
            let businessName = extractBusinessName(from: prediction)
            
            // Update cell
            cell.textLabel?.text = businessName
            cell.detailTextLabel?.text = nil  // No address/detail text
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension CustomBusinessSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.row < filteredPredictions.count {
            let selectedPrediction = filteredPredictions[indexPath.row]
            fetchPlaceDetails(for: selectedPrediction)
        }
    }
} 