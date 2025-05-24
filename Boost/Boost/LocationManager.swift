//
//  LocationManager.swift
//  Boost
//
//  Created for location services
//

import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    // The central CLLocationManager instance
    private let locationManager = CLLocationManager()
    
    // Published properties to be observed by the SwiftUI views
    @Published var locationStatus: CLAuthorizationStatus?
    @Published var lastLocation: CLLocation?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Initialize location manager with desired settings
    override init() {
        super.init()
        
        // Set up the location manager
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.pausesLocationUpdatesAutomatically = true
        
        // Set initial authorization status
        if #available(iOS 14.0, *) {
            locationStatus = locationManager.authorizationStatus
        } else {
            locationStatus = CLLocationManager.authorizationStatus()
        }
        
        print("📍 LocationManager initialized with status: \(locationStatus?.description ?? "unknown")")
    }
    
    // Request location permissions from user
    func requestPermission() {
        isLoading = true
        
        // Ensure we're on the main thread
        DispatchQueue.main.async {
            print("📍 Actively requesting permissions, current status: \(self.locationStatus?.description ?? "unknown")")
            self.locationManager.requestWhenInUseAuthorization()
        }
        
        print("📍 Requesting location permissions")
    }
    
    // A more forceful way to trigger the permission alert
    func forceTriggerPermissionAlert() {
        isLoading = true
        print("📍 Forcing permission alert with a location request")
        
        // First, make sure we're requesting permission
        DispatchQueue.main.async {
            self.locationManager.requestWhenInUseAuthorization()
            
            // Then immediately try to get location
            // This will force the system to show the alert if not already determined
            if self.locationStatus == .notDetermined {
                self.locationManager.requestLocation()
                
                // As a backup, start and immediately stop updates
                // This sometimes triggers the permission dialog when other methods fail
                self.locationManager.startUpdatingLocation()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.locationManager.stopUpdatingLocation()
                }
            }
        }
    }
    
    // Get the user's current location (one-time request)
    func requestLocation() {
        guard locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways else {
            print("📍 Not authorized yet, requesting permission first")
            requestPermission()
            
            // If we're in the not determined state, also force trigger
            if locationStatus == .notDetermined {
                forceTriggerPermissionAlert()
            }
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Ensure we're on the main thread
        DispatchQueue.main.async {
            self.locationManager.requestLocation()
        }
        
        print("📍 Requesting current location")
    }
    
    // Start continuous location updates
    func startLocationUpdates() {
        guard locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways else {
            requestPermission()
            return
        }
        
        isLoading = true
        errorMessage = nil
        locationManager.startUpdatingLocation()
        
        print("📍 Started continuous location updates")
    }
    
    // Stop continuous location updates
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        isLoading = false
        
        print("📍 Stopped location updates")
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    // Handle authorization status changes
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if #available(iOS 14.0, *) {
            locationStatus = manager.authorizationStatus
        } else {
            locationStatus = CLLocationManager.authorizationStatus()
        }
        
        print("📍 Location authorization status changed: \(locationStatus?.description ?? "unknown")")
        
        // If authorized, automatically request location
        if locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways {
            print("📍 Authorization granted, requesting location now")
            locationManager.requestLocation()
        } else if locationStatus == .denied || locationStatus == .restricted {
            errorMessage = "Location access was denied or restricted. Please enable location in Settings."
            isLoading = false
        }
    }
    
    // For iOS < 14 compatibility
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        locationStatus = status
        
        print("📍 Location authorization status changed (legacy): \(status.description)")
        
        // If authorized, automatically request location
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            print("📍 Authorization granted (legacy), requesting location now")
            locationManager.requestLocation()
        } else if status == .denied || status == .restricted {
            errorMessage = "Location access was denied or restricted. Please enable location in Settings."
            isLoading = false
        }
    }
    
    // Handle new location data
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Set the last known location
        lastLocation = location
        isLoading = false
        
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        print("📍 Location updated - Latitude: \(latitude), Longitude: \(longitude)")
    }
    
    // Handle location errors
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
        
        // Handle error based on its type
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                errorMessage = "Location access was denied by the user"
            case .locationUnknown:
                errorMessage = "Unable to determine your location"
            default:
                errorMessage = "Location error: \(error.localizedDescription)"
            }
        } else {
            errorMessage = "Location error: \(error.localizedDescription)"
        }
        
        print("📍 Location error: \(errorMessage ?? "unknown error")")
    }
}

// MARK: - Helper Extensions
extension CLAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined:
            return "Not Determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorizedAlways:
            return "Authorized Always"
        case .authorizedWhenInUse:
            return "Authorized When In Use"
        @unknown default:
            return "Unknown"
        }
    }
} 