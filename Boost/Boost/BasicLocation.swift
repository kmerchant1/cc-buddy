//
//  BasicLocation.swift
//  Boost
//
//  Created for minimal location services
//

import SwiftUI
import CoreLocation

// A minimal location manager focused on getting coordinates
class BasicLocation: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var manager: CLLocationManager?
    
    @Published var coordinates: String = "Tap to get location"
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    override init() {
        super.init()
        // Initialize on main thread to avoid threading issues
        DispatchQueue.main.async {
            self.setupLocationManager()
        }
    }
    
    private func setupLocationManager() {
        manager = CLLocationManager()
        manager?.delegate = self
        manager?.desiredAccuracy = kCLLocationAccuracyBest
        
        // Log current status
        printAuthStatus()
    }
    
    func printAuthStatus() {
        guard let manager = manager else { return }
        
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = manager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        
        let statusText: String
        switch status {
        case .notDetermined:
            statusText = "Not Determined"
        case .restricted:
            statusText = "Restricted"
        case .denied:
            statusText = "Denied"
        case .authorizedWhenInUse:
            statusText = "Authorized When In Use"
        case .authorizedAlways:
            statusText = "Authorized Always"
        @unknown default:
            statusText = "Unknown"
        }
        
        print("📱 Current location authorization status: \(statusText)")
    }
    
    func getLocation() {
        guard let manager = manager else {
            print("📱 Location manager not initialized, setting up now")
            setupLocationManager()
            guard let _ = manager else {
                self.coordinates = "Location manager setup failed"
                return
            }
            return
        }
        
        isLoading = true
        coordinates = "Getting location..."
        errorMessage = nil
        
        // For testing in simulator, you can use this to set a mock location
        #if targetEnvironment(simulator)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // Simulated coordinates (San Francisco)
            self.coordinates = "37.7749, -122.4194"
            self.isLoading = false
        }
        return
        #endif
        
        // Check if location services are enabled
        guard CLLocationManager.locationServicesEnabled() else {
            self.coordinates = "Location services disabled"
            self.isLoading = false
            self.errorMessage = "Please enable location services in Settings"
            print("📱 Location services are disabled on the device")
            return
        }
        
        // Get current authorization status
        let authStatus: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            authStatus = manager.authorizationStatus
        } else {
            authStatus = CLLocationManager.authorizationStatus()
        }
        
        print("📱 Authorization status before request: \(authStatus)")
        
        // Handle based on current authorization status
        switch authStatus {
        case .notDetermined:
            // Request permission asynchronously and wait for callback
            print("📱 Requesting location permission via callback pattern")
            // Request permission - the delegate will handle the response
            DispatchQueue.global().async {
                self.manager?.requestWhenInUseAuthorization()
            }
            return
            
        case .denied, .restricted:
            self.coordinates = "Location access denied"
            self.errorMessage = "Please allow location access in Settings"
            self.isLoading = false
            print("📱 Location access denied or restricted")
            
            // Offer to open settings if permission is denied
            if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(appSettings)
            }
            return
            
        case .authorizedWhenInUse, .authorizedAlways:
            // We have permission, continue with location request
            startLocationUpdates()
            
        @unknown default:
            self.coordinates = "Unknown authorization status"
            self.errorMessage = "Please check location settings"
            self.isLoading = false
            return
        }
    }
    
    private func startLocationUpdates() {
        guard let manager = manager else { return }
        
        print("📱 Starting location updates")
        manager.startUpdatingLocation()
        
        // Set a timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self else { return }
            if self.isLoading {
                self.manager?.stopUpdatingLocation()
                self.isLoading = false
                self.coordinates = "Timed out getting location"
                self.errorMessage = "Location request timed out"
                print("📱 Location request timed out")
            }
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            self.coordinates = "No location data"
            self.isLoading = false
            return
        }
        
        // Stop updates once we get a location
        manager.stopUpdatingLocation()
        
        // Format with more precision and print details for debugging
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let accuracy = location.horizontalAccuracy
        
        self.coordinates = String(format: "%.6f, %.6f", lat, lon)
        self.errorMessage = nil
        
        print("📱 Location: \(coordinates)")
        print("📱 Accuracy: \(accuracy) meters")
        print("📱 Timestamp: \(location.timestamp)")
        
        self.isLoading = false
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📱 Location error: \(error.localizedDescription)")
        
        // Don't stop updates for minor errors like temporary unavailability
        if let clError = error as? CLError {
            switch clError.code {
            case .locationUnknown:
                // This is a temporary error; location updates might resume
                print("📱 Temporary location unavailable, continuing to try")
                return
                
            case .denied:
                self.coordinates = "Location access denied"
                self.errorMessage = "Location permission denied"
                print("📱 Location access denied by user")
                
            case .network:
                self.coordinates = "Network error"
                self.errorMessage = "Check network connection"
                print("📱 Network error getting location")
                
            default:
                self.coordinates = "Error: \(clError.code.rawValue)"
                self.errorMessage = "Location error: \(clError.code.rawValue)"
                print("📱 Location error: \(clError) (code: \(clError.code.rawValue))")
            }
        } else {
            self.coordinates = "Error: \(error.localizedDescription)"
            self.errorMessage = "Location error occurred"
            print("📱 General location error: \(error.localizedDescription)")
        }
        
        // Stop updates for critical errors
        manager.stopUpdatingLocation()
        self.isLoading = false
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if #available(iOS 14.0, *) {
            let status = manager.authorizationStatus
            print("📱 Authorization status changed: \(status.rawValue)")
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                if isLoading {
                    startLocationUpdates()
                }
            case .denied, .restricted:
                self.coordinates = "Location access denied"
                self.errorMessage = "Please enable location in Settings"
                self.isLoading = false
                
                // Offer to open settings
                if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(appSettings)
                }
            case .notDetermined:
                // Still waiting for user decision
                break
            @unknown default:
                break
            }
        }
    }
    
    // For iOS < 14
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("📱 Authorization status changed (legacy): \(status.rawValue)")
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            if isLoading {
                startLocationUpdates()
            }
        case .denied, .restricted:
            self.coordinates = "Location access denied"
            self.errorMessage = "Please enable location in Settings"
            self.isLoading = false
            
            // Offer to open settings
            if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(appSettings)
            }
        case .notDetermined:
            // Still waiting for user decision
            break
        @unknown default:
            break
        }
    }
} 