//
//  VescStats.swift
//  MyWatchOSApp Watch App
//
//  Created by Gregory Dymarek on 10/08/2025.
//

import Foundation
import Observation

@Observable
class VESCRtStats: ObservableObject {
    // MARK: - Properties
    var batteryVoltage: Double = 0.0
    var inputCurrent: Double = 0.0
    var mosTemperature: Double = 0.0
    var wattHours: Double = 0.0
    var rpm: Double = 0.0
    var isConnected: Bool = false
    private var lastUpdateTimestamp: Date = .distantPast
    
    var timeSinceLastUpdate: TimeInterval {
        return Date().timeIntervalSince(lastUpdateTimestamp)
    }
    
    // MARK: - Initialization
    init() {}
    
    // MARK: - Methods
    func updateStats(
        batteryVoltage: Double? = nil,
        inputCurrent: Double? = nil,
        mosTemperature: Double? = nil,
        wattHours: Double? = nil,
        rpm: Double? = nil,
        isConnected: Bool? = nil
    ) {
        // Update timestamp on every call
        lastUpdateTimestamp = Date()
        
        if let batteryVoltage = batteryVoltage {
            self.batteryVoltage = batteryVoltage
        }
        if let inputCurrent = inputCurrent {
            self.inputCurrent = inputCurrent
        }
        if let mosTemperature = mosTemperature {
            self.mosTemperature = mosTemperature
        }
        if let wattHours = wattHours {
            self.wattHours = wattHours
        }
        if let rpm = rpm {
            self.rpm = rpm
        }
        if let isConnected = isConnected {
            self.isConnected = isConnected
        }
    }
    
    func resetStats() {
        batteryVoltage = 0.0
        inputCurrent = 0.0
        mosTemperature = 0.0
        wattHours = 0.0
        isConnected = false
        rpm = 0.0
        lastUpdateTimestamp = .distantPast
    }
}


@Observable
class VESCStats: ObservableObject {
    // MARK: - Properties
    var runTime: Double = 0.0
    var maxPower: Double = 0.0
    var avgPower: Double = 0.0
    var maxMosTemperature: Double = 0.0
    var avgMosTemperature: Double = 0.0
    var maxCurrent: Double = 0.0
    var avgCurrent: Double = 0.0
    private var lastUpdateTimestamp: Date = .distantPast
    
    var timeSinceLastUpdate: TimeInterval {
        // Calculate time elapsed since last update in seconds
        return Date().timeIntervalSince(lastUpdateTimestamp)
    }
    
    // MARK: - Initialization
    init() {}
    
    // MARK: - Methods
    func updateStats(
        runTime: Double? = nil,
        maxPower: Double? = nil,
        avgPower: Double? = nil,
        maxMosTemperature: Double? = nil,
        avgMosTemperature: Double? = nil,
        maxCurrent: Double? = nil,
        avgCurrent: Double? = nil
    ) {
        // Update timestamp on every call
        lastUpdateTimestamp = Date()
        
        if let runTime = runTime {
            self.runTime = runTime
        }
        if let maxPower = maxPower {
            self.maxPower = maxPower
        }
        if let avgPower = avgPower {
            self.avgPower = avgPower
        }
        if let maxMosTemperature = maxMosTemperature {
            self.maxMosTemperature = maxMosTemperature
        }
        if let avgMosTemperature = avgMosTemperature {
            self.avgMosTemperature = avgMosTemperature
        }
        if let maxCurrent = maxCurrent {
            self.maxCurrent = maxCurrent
        }
        if let avgCurrent = avgCurrent {
            self.avgCurrent = avgCurrent
        }
    }
    
    func resetStats() {
        runTime = 0.0
        maxPower = 0.0
        avgPower = 0.0
        maxMosTemperature = 0.0
        avgMosTemperature = 0.0
        maxCurrent = 0.0
        avgCurrent = 0.0
        lastUpdateTimestamp = .distantPast
    }
}
