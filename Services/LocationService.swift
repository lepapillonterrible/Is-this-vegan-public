// LocationService.swift
// IsThisVegan
//
// A lightweight wrapper around CoreLocation to provide the current country code.
// Used to give the AI context about local food norms (e.g., "Vegetarian" in India vs Thailand).
//
// Privacy: This service only requests "When In Use" authorization and only
// exposes the ISO country code, not the precise coordinates.

import CoreLocation
import SwiftUI

/// Providing current location context for analysis.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    
    // MARK: - Published State
    
    /// The current ISO country code (e.g., "US", "TH", "IN").
    /// Nil if location is unknown, denied, or not yet determined.
    var currentCountryCode: String? = nil
    
    /// User-friendly name of the current country (e.g., "Thailand").
    var currentCountryName: String? = nil
    
    /// The most recent precise location (for CloudKit tagging).
    var lastKnownLocation: CLLocation? = nil
    
    /// Authorization status for UI handling.
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // MARK: - Internal
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    // MARK: - Lifecycle
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers // Low accuracy is fine for country
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - Public API
    
    /// Request permission and start updating location.
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// Refresh location (one-shot).
    func updateLocation() {
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.requestLocation()
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        } else {
            currentCountryCode = nil
            currentCountryName = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        self.lastKnownLocation = location
        
        // Reverse geocode to get the country code
        // This is async, but we don't need to await it for the delegate.
        // We just update the published properties when done.
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self, let placemark = placemarks?.first, error == nil else {
                return
            }
            
            // ISO country code (e.g., "TH")
            if let code = placemark.isoCountryCode {
                self.currentCountryCode = code
            }
            
            // Localized country name (e.g., "Thailand")
            if let name = placemark.country {
                self.currentCountryName = name
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[LocationService] Failed to find location: \(error.localizedDescription)")
    }
}
