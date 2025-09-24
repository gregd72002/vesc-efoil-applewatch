//
//  ContentView.swift
//  MyWatchOSApp Watch App
//
//  Created by Gregory Dymarek on 09/07/2025.
//

import SwiftUI

/*
@Observable
class MyDataStore {
    var locationEnabled: Bool = false
    var locationSpeedUnit: GPSSpeedUnit = .ms
    var locationSpeed: Double = 0.0
}
*/

func secondsToHoursMinutesSeconds(_ seconds: Int) -> (Int, Int, Int) {
    return (seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
}

struct ContentView: View {
    @StateObject private var bluetoothManager = BluetoothManager()
    
    var body: some View {
        
        //Home(bluetoothManager: bluetoothManager)
        
        if (bluetoothManager.state == .start) {
            Hello(bluetoothManager: bluetoothManager)
        } else if (bluetoothManager.state == .scanning || bluetoothManager.state == .scanningIdle) {
            Scan(bluetoothManager: bluetoothManager)
        } else if (bluetoothManager.state == .connecting) {
            Connect(bluetoothManager: bluetoothManager)
        } else if (bluetoothManager.state == .off) {
            BTOff()
        } else {
            Home(bluetoothManager: bluetoothManager)
        }
         
    }
}

struct Hello: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        VStack {
            Text("Initializing...")
        }
    }
}

struct BTOff: View {
    var body: some View {
        ZStack {
            Color.red.opacity(0.15)
                .ignoresSafeArea()
            
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 24))
                    .symbolEffect(.pulse, options: .repeating)
                
                Text("Bluetooth Error")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                
                Text("App has no access to Bluetooth!")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct Scan: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    var body: some View {
        VStack {
            Text("Device list")
            Spacer()
            List {
                ForEach(bluetoothManager.peripherals, id: \.identifier) { peripheral in
                    if (peripheral.name != nil) {
                        Button(action: {
                            bluetoothManager.connectPeripheral(peripheral: peripheral)
                        }) {
                            Text(peripheral.name!)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .cornerRadius(10)
                        }
                    }
                }
                
                if (bluetoothManager.state == .scanning) {
                    ProgressView {
                    }.id(UUID())
                }

                Button(action: {
                    bluetoothManager.stopScanning()
                }) {
                    Text("STOP")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    bluetoothManager.restart()
                }) {
                    Text("REFRESH")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle()) // Use plain style for custom appearance
            }
            
        }
    }
}

struct Connect: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    var body: some View {
        Text("Connecting...")
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle(tint: .white))
          .scaleEffect(2.0, anchor: .center) // Makes the spinner larger
          .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
              // Simulates a delay in content loading
              // Perform transition to the next view here
            }
          }
        Button("Cancel...") {
            bluetoothManager.restart(withNewDevice:true)
        }
      }
}
/*
struct Home1: View {
    let p: Packet = Packet()
    @ObservedObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        VStack {
            Text("VESC Stats")
            Text("Battery V: \(String(format: "%.1f", bluetoothManager.vescStats.batteryVoltage))")
            Text("VESC Temp C: \(String(format: "%.1f", bluetoothManager.vescStats.mosTemperature))")
            Text("RPM: \(String(format: "%.f", bluetoothManager.vescStats.rpm))")
            Button("Reset Connection") {
                bluetoothManager.restart(withNewDevice: true)
            }
        }
    }
}
*/

struct Home: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    
    @State private var crownOffset: Double = 0.0
    @State private var tabSelected: Int = 0
    @State private var crownCounter: Double = 0
    @State private var isSettingsPresented = false
    
    @StateObject private var locationManager = LocationManager()
    
    let tabCount = 2
    
    var body: some View {
        
        TabView(selection: $tabSelected) {
            // First View (Live Data)
            ZStack {
                Color.blue.opacity(0.1)
                    .ignoresSafeArea()
                
                VStack(spacing: 3) {
                    Image(systemName: "waveform")
                        .foregroundColor(.red)
                        .font(.system(size: 20))
                    
                    Text("Battery (V): \(String(format: "%.1f", bluetoothManager.vescRtStats.batteryVoltage))")
                    Text("VESC Temp (C): \(String(format: "%.1f", bluetoothManager.vescRtStats.mosTemperature))")
                    Text("RPM: \(String(format: "%.f", bluetoothManager.vescRtStats.rpm))")
                    Text("Current (A): \(String(format: "%.1f", bluetoothManager.vescRtStats.inputCurrent))")
                    Text("Watt-hours: \(String(format: "%.1f", bluetoothManager.vescRtStats.wattHours))")
                    
                    let lag  = bluetoothManager.vescRtStats.timeSinceLastUpdate
                    if (lag < 3600) {
                        Text("Lag (s): \(String(format: "%.f", lag))")
                    } else {
                        Text("Lag (s): N/A")
                    }
                    
                    
                    if (locationManager.isEnabled()) {
                        Text("Speed (\(locationManager.getSpeedUnit().rawValue)): \(String(format: "%.1f", locationManager.speed))")
                    }
                }
                .padding()
            }
            .tag(0)

            // Second View (Stats)
            ZStack {
                Color.purple.opacity(0.1)
                    .ignoresSafeArea()
                
                VStack(spacing: 3) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.purple)
                        .font(.system(size: 20))
                    
                    let (h,m,s) = secondsToHoursMinutesSeconds(Int(bluetoothManager.vescStats.runTime))
                    Text("Run time: \(String(format: "%02d", h)):\(String(format: "%02d", m)):\(String(format: "%02d", s))")
                    Text("Power: \(String(format: "%.f", bluetoothManager.vescStats.avgPower))/\(String(format: "%.f", bluetoothManager.vescStats.maxPower))")
                    Text("Current: \(String(format: "%.f", bluetoothManager.vescStats.avgCurrent))/\(String(format: "%.f", bluetoothManager.vescStats.maxCurrent))")
                    Text("VESC Temp: \(String(format: "%.f", bluetoothManager.vescStats.avgMosTemperature))/\(String(format: "%.f", bluetoothManager.vescStats.maxMosTemperature))")
                    
                }
                .padding()
            }
            .tag(1)
            
            // Third View
            NavigationView {
                ZStack {
                    Color.green.opacity(0.1)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 4) {
                        /*
                        Button(action: {
                            // Water Lock action
                            WKInterfaceDevice.current().enableWaterLock()
                        }) {
                            Image(systemName: "drop.fill")
                                .foregroundColor(Color.blue)
                        }
                        */
                        Button(action: {
                            // Settings action (placeholder)
                            print("Settings tapped")
                            isSettingsPresented = true
                        }) {
                            Text("Settings")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                        }
                    }
                    .padding()
                }
                .sheet(isPresented: $isSettingsPresented) {
                    SettingsView(locationManager: locationManager, bluetoothManager: bluetoothManager)
                }
            }
            
            //.tag(3)
        }
        .tabViewStyle(.page)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusable()
        .digitalCrownRotation(
            detent: $crownOffset,
            from: 0,
            through: 1,
            by: 0.01,
            sensitivity: .medium,
            isContinuous: true,
            onChange: { crownEvent in
                crownCounter += crownEvent.velocity
                if (crownCounter>10.0) {
                    crownCounter=10.0
                    
                    if (tabSelected<tabCount-1) { //still more tabs
                        tabSelected+=1;
                    }
                }
                if (crownCounter<0.0) {
                    crownCounter=0.0
                    
                    if (tabSelected>0) {
                        tabSelected-=1;
                    }
                }

            }
        )
    }
}

struct SettingsView: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var bluetoothManager: BluetoothManager
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var showConfirmation = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("GPS")) {
                    Toggle("Enable GPS", isOn: Binding(
                        get: { locationManager.isEnabled() },
                        set: { newValue in
                            // Custom logic when setting the value
                            print("Setting value to: \(newValue)")
                            locationManager.toggleStatus(status: newValue)
                        }
                    ))
                    Picker("Speed Units", selection: Binding<GPSSpeedUnit>(
                        get: { locationManager.getSpeedUnit() },
                        set: { newValue in
                            locationManager.setSpeedUnit(newValue)
                            
                        })) {
                        ForEach(GPSSpeedUnit.allCases) { unit in
                            Text(unit.rawValue)
                        }
                    }
                }
                
                Button(action: {
                    showConfirmation = true
                }) {
                    Text("Reset pairing")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .alert(isPresented: $showConfirmation) {
                    Alert(
                        title: Text("Reset Confirmation"),
                        message: Text("Are you sure you want to reset Bluetooth pairing?"),
                        primaryButton: .destructive(Text("Reset")) {
                            showConfirmation = false
                            dismiss()
                            // Perform reset action here
                            bluetoothManager.restart(withNewDevice: true)
                            
                        },
                        secondaryButton: .cancel()
                    )
                }
                
                Section {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Settings")
        }
    }
}


#Preview {
    ContentView()
}


//COMM_GET_STATS

/*
 if (mask & (uint32_t(1) << 0)) {
     values.temp_mos = vb.vbPopFrontDouble16(1e1);
 }
 
 if (mask & (uint32_t(1) << 2)) {
     values.current_motor = vb.vbPopFrontDouble32(1e2);
 }
 
 if (mask & (uint32_t(1) << 3)) {
     values.current_in = vb.vbPopFrontDouble32(1e2);
 }
 
 if (mask & (uint32_t(1) << 7)) {
     values.rpm = vb.vbPopFrontDouble32(1e0);
 }
 
 if (mask & (uint32_t(1) << 11)) {
     values.watt_hours = vb.vbPopFrontDouble32(1e4);
 }
 
 if (mask & (uint32_t(1) << 8)) {
     values.v_in = vb.vbPopFrontDouble16(1e1);
 }
 
 */
