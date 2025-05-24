//
//  SimpleLocationManager.swift
//  Boost
//
//  Created for simplified location services
//

import Foundation
import CoreLocation
import SwiftUI

/// A simpler implementation of location manager focused on showing the permission dialog
class SimpleLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    // Single manager instance
    private let manager = CLLocationManager()
    
    // Published properties for SwiftUI
    @Published var location: CLLocation?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        printDebugInfo()
    }
    
    // Print useful debug information
    func printDebugInfo() {
        if #available(iOS 14.0, *) {
            let status = manager.authorizationStatus
            printAuthStatus(status)
        } else {
            let status = CLLocationManager.authorizationStatus()
            printAuthStatus(status)
        }
        
        #if DEBUG
        print("🗺️ DEBUG - Location Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("🗺️ DEBUG - Location Available: \(CLLocationManager.locationServicesEnabled())")
        print("🗺️ DEBUG - Location Manager: \(manager)")
        print("🗺️ DEBUG - Please verify Info.plist has these keys:")
        print("    - NSLocationWhenInUseUsageDescription")
        print("    - NSLocationAlwaysAndWhenInUseUsageDescription")
        #endif
    }
    
    private func printAuthStatus(_ status: CLAuthorizationStatus) {
        let statusString: String
        switch status {
        case .notDetermined:
            statusString = "Not Determined"
        case .restricted:
            statusString = "Restricted"
        case .denied:
            statusString = "Denied"
        case .authorizedAlways:
            statusString = "Authorized Always"
        case .authorizedWhenInUse:
            statusString = "Authorized When In Use"
        @unknown default:
            statusString = "Unknown"
        }
        print("🗺️ Current location authorization status: \(statusString) (raw: \(status.rawValue))")
    }
    
    // This method will trigger the permission dialog
    func requestLocationPermission() {
        print("🗺️ Requesting location permission")
        isLoading = true
        
        // Make sure we're on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.printDebugInfo()
            
            // Request permission
            self.manager.requestWhenInUseAuthorization()
            
            // iOS requires an actual reason to request location to show the dialog
            // So we immediately request location as well
            self.manager.requestLocation()
            
            // Sometimes need a more immediate reason to request location
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🗺️ Following up with additional location request")
                self.manager.startUpdatingLocation()
                
                // Stop after a brief period
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.manager.stopUpdatingLocation()
                }
            }
        }
    }
    
    // CLLocationManagerDelegate methods
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            print("🗺️ Got location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            self.location = location
            self.isLoading = false
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("🗺️ Location error: \(error.localizedDescription)")
        self.errorMessage = error.localizedDescription
        self.isLoading = false
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        print("🗺️ Authorization status changed: \(status.rawValue)")
        
        // If authorized, immediately request location
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        }
    }
    
    // Legacy method for iOS < 14
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("🗺️ Authorization status changed (legacy): \(status.rawValue)")
        
        // If authorized, immediately request location
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        }
    }
} 