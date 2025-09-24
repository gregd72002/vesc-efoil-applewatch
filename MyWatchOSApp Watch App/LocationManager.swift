//
//  LocationManager.swift
//  MyWatchOSApp
//
//  Created by Gregory Dymarek on 11/08/2025.
//

import CoreLocation

/*
enum GPSSpeedUnit: String, CaseIterable, Identifiable {
    case kph = "kph"
    case mph = "mph"
    case ms = "ms"
    case knots = "knots"
    
    var id: GPSSpeedUnit { self }
    //var id: String { rawValue }
}*/

enum GPSSpeedUnit: String, CaseIterable, Identifiable {
    case kph
    case mph
    case ms
    case knots
    
    var id: GPSSpeedUnit { self }
}

// LocationManager to handle CoreLocation updates
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var speedUnit: GPSSpeedUnit = .ms
    @Published var speed: Double = 0.0 // Speed in kph
    @Published var isTracking: Bool = false // Tracks whether location updates are active
    
    override init() {
        let x = UserDefaults.standard.string(forKey: "GPS_SPEEDUNIT")
        self.speedUnit = GPSSpeedUnit(rawValue: (x ?? "ms"))!
        
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        //locationManager.distanceFilter = 10 // Update every 10 meters
        print("requesting location authorization")
        locationManager.requestWhenInUseAuthorization()

    }
    
    func isEnabled() -> Bool {
        return (UserDefaults.standard.string(forKey: "GPS_ENABLED") == "true")
    }
    
    func toggleStatus(status: Bool) {
        UserDefaults.standard.set(status.description, forKey: "GPS_ENABLED")
        if (status) {
            start()
        } else {
            stop()
        }
    }
    
    func start() {
        if (isTracking) { return }
        print("LocationManager: start")
        locationManager.startUpdatingLocation()
        isTracking = true
    }
    
    func stop() {
        if (!isTracking) { return }
        print("LocationManager: stop")
        locationManager.stopUpdatingLocation()
        speed = 0.0
        isTracking = false
    }

    func setSpeedUnit(_ unit: GPSSpeedUnit) {
        UserDefaults.standard.set(unit.rawValue, forKey: "GPS_SPEEDUNIT")
        speedUnit = unit
    }
    
    func getSpeedUnit() -> GPSSpeedUnit {
        return self.speedUnit
    }
    
    // CLLocationManagerDelegate method
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        var speed = max(location.speed, 0) //meters per second by the API
        
        if (speedUnit == .ms) {} //speed = speed
        else if (speedUnit == .kph) {
            speed *= 3.6;
        } else if (speedUnit == .mph) {
            speed *= 2.23694
        } else if (speedUnit == .knots) {
            speed *= 1.94384
        }

        DispatchQueue.main.async {
            self.speed = speed
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isTracking = false
            self.speed = 0.0
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("location access granted")
            if (isEnabled()) {
                start()
            }
        case .denied, .restricted:
            speed = 0.0
            isTracking = false
            print("Location access denied or restricted")
        default:
            break
        }
    }
}
