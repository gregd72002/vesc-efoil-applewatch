//
//  BLuetoothManager.swift
//  MyWatchOSApp Watch App
//
//  Created by Gregory Dymarek on 09/07/2025.
//

import Foundation
import CoreBluetooth

var DEBUG = true

let userDefaults = UserDefaults.standard

enum btStateEnum {
    case off, start, scanning, scanningIdle, connecting, connected
}

enum BluetoothError: Error {
    case timeout
    case connectTimeout
    case bluetoothNotAvailable
}

extension Data {
    /// Returns a hexadecimal string representation of the Data.
    /// - Parameter upperCase: A boolean indicating whether to use uppercase (A-F) or lowercase (a-f) hexadecimal digits. Default is `false` (lowercase).
    func hexEncodedString(upperCase: Bool = false) -> String {
        let format = upperCase ? "%02hhX" : "%02hhx"
        return self.map { String(format: format, $0) }.joined(separator: " ")
    }
}

extension Array where Element == UInt8 {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhX", $0) }.joined(separator: " ")
    }
}

extension ArraySlice where Element == UInt8 {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhX", $0) }.joined(separator: " ")
    }
}


class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var centralManager: CBCentralManager!
    private var vescTimer: Timer?
    private var vescTimerCounter: UInt = 0
    private var connectTimer: Timer?
    private let connectTimeoutInterval: TimeInterval = 15.0 // 15 seconds timeout for connecting
    
    @Published var state = btStateEnum.start
    @Published var peripherals: [CBPeripheral] = []
    
    private var vesc: CBPeripheral!
    private var char: CBCharacteristic!

    private let packet: Packet = Packet()
    @Published var vescRtStats = VESCRtStats()
    @Published var vescStats = VESCStats()

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
        packet.packetReceived = self.packetReceived
        
        vescTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.vescLoop()
        }
        print("BluetoothManager INIT")
    }
    
    func restart(withNewDevice:Bool=false) {
        print("BluetoothManager RESET")
        
        if (withNewDevice) {
            UserDefaults.standard.removeObject(forKey: "VESC_UUID")
        }
        
        if (centralManager.isScanning) { //we are still scanning
            stopScanning()
        }
    
        if (vesc != nil) {
            centralManager.cancelPeripheralConnection(vesc)
            vesc = nil
        }
        
        if (char != nil) {
            char = nil
        }
        
        peripherals.removeAll()
        startScanning()
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
            state = .start
            retrievePeripheral(withDeviceID: UserDefaults.standard.string(forKey: "VESC_UUID") ?? "")
        case .poweredOff:
            print("Bluetooth is powered off")
            state = .off
        case .unauthorized:
            print("Bluetooth is not authorized.")
            state = .off
        case .unsupported:
            print("Bluetooth is not supported.")
            state = .off
        default:
            print("Bluetooth state unknown. What State should we use??! \(central.state)")
            state = .off
        }
    }
    
    func retrievePeripheral(withDeviceID deviceID: String) {
        guard let uuid = UUID(uuidString: deviceID) else {
            print("Invalid UUID")
            startScanning()
            return
        }
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
        if let peripheral = peripherals.first {
            print("Retrieved peripheral: \(peripheral.name ?? "Unnamed"). Reconnecting...")
            connectPeripheral(peripheral: peripheral)
        } else {
            print("Peripheral not found; may need to scan.")
            startScanning()
        }
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("Bluetooth not on?")
            return
        }
        
        let serviceUUIDs = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
        centralManager.scanForPeripherals(withServices: [serviceUUIDs], options: nil)
        //centralManager.scanForPeripherals(withServices: nil, options: nil)
        state = .scanning
    }
    
    public func stopScanning() {
        if (!centralManager.isScanning) {
            print("we are not scanning but you think we are?!")
            state = .scanningIdle
            return
        }
        
        print("stopScanning")
        centralManager.stopScan()
        state = .scanningIdle
    }
    
    
   func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
       if !peripherals.contains(peripheral) {
           peripherals.append(peripheral)
           print("Discovered peripheral: \(peripheral.name ?? "Unnamed Peripheral")")
       }
       
       let savedPeripheral = UserDefaults.standard.string(forKey: "VESC_UUID")
       if (peripheral.identifier.uuidString == savedPeripheral) {
           print("Found saved VESC! Reconnecting...")
           stopScanning()
           connectPeripheral(peripheral: peripheral)
       }
   }

    func connectPeripheral(peripheral: CBPeripheral) {
        if (centralManager.isScanning) { //we are still scanning
            stopScanning()
        }
        
        print("connecting to: \(peripheral.name ?? "[Unknown]")")
        
        state = .connecting
        /*
        switch(centralManager.state){
        case .poweredOn:
            print("poweredOn")
        case .poweredOff:
            print("poweredOff")
        case .resetting:
            print("resetting")
        case .unauthorized:
            print("unauthorized")
        case .unknown:
            print("unknown")
        case .unsupported:
            print("unsupported")
        default:
            print("unknown?")
            break
        }
        */
        vesc = peripheral
        // Set connection options
        let options: [String: Any] = [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
        ]
        centralManager.connect(vesc, options: options)
        
        // Set up connect timeout timer
        connectTimer = Timer.scheduledTimer(withTimeInterval: connectTimeoutInterval, repeats: false) { [weak self] _ in
            print("Timing out on connect")
            self?.handleConnectCompletion(.failure(BluetoothError.connectTimeout))
        }

    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("didConnect:" + (peripheral.name ?? "Unnamed Peripheral"))
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // Handle failed connection
        print("Check!! Failed to connect to peripheral: \(peripheral.name ?? "Unknown")")
        print("Error: \(error.debugDescription)")
        stopConnecting()
    }

    
    // Internal function to handle connect completion
    private func handleConnectCompletion(_ result: Result<CBPeripheral, Error>) {
        switch result {
        case .success(let peripheral):
            print("Successfully connected to peripheral: \(peripheral.name ?? "Unknown")")
            UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: "VESC_UUID")
            connectTimer?.invalidate()
            connectTimer = nil
            state = .connected
            packet.resetState()
        case .failure(let error):
            stopConnecting()
            print("Failed to connect to peripheral: \(error)")
            restart()
        }
    }

    
    private func stopConnecting() {
        if (vesc != nil) {
            centralManager.cancelPeripheralConnection(vesc)
        }

        connectTimer?.invalidate()
        connectTimer = nil
        vesc = nil
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("didDiscoverServices:" + (peripheral.name ?? "Unnamed Peripheral"))
         let currentDate = Date()
          if let services = peripheral.services {
              _ = services.map({ (service: CBService) in
               debugPrint("\(currentDate) - peripheral is \(peripheral) and service is \(service)")
                peripheral.discoverCharacteristics(nil, for: service)
              })
          } else if let error = error {
             debugPrint("\(currentDate) - error in didDiscoverServices Error:- \(error.localizedDescription)")
              state = .start
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let writeCharUuid = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
        
        print("didDiscoverCharacteristicsFor:" + (peripheral.name ?? "Unnamed Peripheral"))
        if let error = error {
            print("Error discovering characteristics for service \(service.uuid): \(error.localizedDescription)")
            state = .start
            return
        }

        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            print("Discovered characteristic: \(characteristic.uuid)")
            print(characteristic.description)
            
            peripheral.setNotifyValue(true, for: characteristic)
            
            if (characteristic.uuid == writeCharUuid) {
                char = characteristic
                print("Found VESC write characteristic")
                handleConnectCompletion(.success(peripheral))
                
                vescLoop()
            }
            
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        //print("didUpdateValueFor:" + (characteristic.uuid.uuidString) + " Length: " + (characteristic.value?.count.description ?? "nil"))
        //let d = characteristic.value ?? Data()
        //print("Value: \(d.hexEncodedString(upperCase: true))")
        packet.processData(data: characteristic.value ?? Data())
    }
    
    func writeDataToCharacteristic(data: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType, completion: ((Error?) -> Void)? = nil) {
        vesc.writeValue(data, for: characteristic, type: type)
    }

    
    func sendData(data: Data) {
        
        if (vesc == nil) {
            print("No vesc")
            return
        }
        
        switch(vesc.state){
        case .disconnected:
            print("disconnected")
            restart()
            break
        case .connecting:
            print("connecting")
            break
        case .connected:
            //print("connected")
            break
        case .disconnecting:
            print("disconnecting")
            break
        default:
            print("unknown?")
            break
        }
        
        let d = packet.preparePacket(data: data)
        //print("Writing len: \(d.count)")
          
        
        if (char == nil) {
            print("Write characteristic not found")
            return
        }
        
        writeDataToCharacteristic(data: d, for: char, type: .withoutResponse) { error in
                if let error = error {
                    print("Error writing data: \(error)")
                } else {
                    print("Data written successfully")
                }
            }
    }
    

    func packetReceived(data: Data) {
        //print("Packet received: \(data.hexEncodedString(upperCase: true))")
        var vb = VByteArray(data: data)
        let id = vb.vbPopFrontUInt8()
    
        print("id: \(id)")

        if (id == 50)  { //COMM_GET_VALUES_SELECTIVE
            let mask = vb.vbPopFrontUInt32();

            //print ("mask: \(String(format: "%08X", mask))")
            
            if (mask & (1 << 0)) != 0 {
                let ret = vb.vbPopFrontDouble16(scale: 10.0)
                vescRtStats.updateStats(mosTemperature: ret)
                //print("VESC Temp C: \(ret)")
            }
            
            if (mask & (1 << 3)) != 0 {
                let ret = vb.vbPopFrontDouble32(scale: 100.0)
                vescRtStats.updateStats(inputCurrent: ret)
                //print("inputCurrent: \(ret)")
            }
            
            if (mask & (1 << 7)) != 0 {
                let ret = vb.vbPopFrontDouble32(scale: 1.0)
                vescRtStats.updateStats(rpm: ret)
                //print("RPM: \(ret)")
            }
            
            if (mask & (1 << 8)) != 0 {
                let ret = vb.vbPopFrontDouble16(scale: 10.0)
                vescRtStats.updateStats(batteryVoltage: ret)
                //print("Current Volts in: \(ret)")
            }
            
            if (mask & (1 << 11)) != 0 {
                let ret = vb.vbPopFrontDouble32(scale: 10000.0)
                vescRtStats.updateStats(wattHours: ret)
                //print("Watt-hours: \(ret)")
            }
        } else if (id == 128) { //COMM_GET_STATS
            
            let mask = vb.vbPopFrontUInt32();
            
            if (mask & (1 << 2)) != 0 {
                let ret = vb.vbPopFrontDouble32Auto()
                vescStats.updateStats(avgPower: ret)
                //print("avgPower: \(ret)")
            }
            
            if (mask & (1 << 3)) != 0 {
                let ret = vb.vbPopFrontDouble32Auto()
                vescStats.updateStats(maxPower: ret)
                //print("maxPower: \(ret)")
            }
            
            if (mask & (1 << 4)) != 0 {
                let ret = vb.vbPopFrontDouble32Auto()
                vescStats.updateStats(avgCurrent: ret)
                //print("avgCurrent: \(ret)")
            }
            
            if (mask & (1 << 5)) != 0 {
                let ret = vb.vbPopFrontDouble32Auto()
                vescStats.updateStats(maxCurrent: ret)
                //print("maxCurrent: \(ret)")
            }
            
            if (mask & (1 << 6)) != 0 {
                let ret = vb.vbPopFrontDouble32Auto()
                vescStats.updateStats(avgMosTemperature: ret)
                //print("avgMosTemperature: \(ret)")
            }
            
            if (mask & (1 << 7)) != 0 {
                let ret = vb.vbPopFrontDouble32Auto()
                vescStats.updateStats(maxMosTemperature: ret)
                //print("maxMosTemperature: \(ret)")
            }
            
            if (mask & (1 << 10)) != 0 {
                let ret = vb.vbPopFrontDouble32Auto()
                vescStats.updateStats(runTime: ret)
                //print("runTime: \(ret)")
            }
        }
    }
    
    func vescLoop() {
        if (char == nil) {
            return
        }
        
        self.vescTimerCounter+=1
        
        var vb = VByteArray()
        var mask: UInt32 = 0
        vb.vbAppendUInt8(50); //COMM_GET_VALUES_SELECTIVE
        mask = 0
        mask = mask | UInt32(1) << 11 //watt-hours
        mask = mask | UInt32(1) << 8 //voltage in
        mask = mask | UInt32(1) << 7 //rpm
        mask = mask | UInt32(1) << 3 //inputCurrent
        mask = mask | 1 //mos temp
        vb.vbAppendUInt32(mask);
        self.sendData(data: vb.data);
        
        if (self.vescTimerCounter%5 != 0) {return;} // only get stats below every 10 seconds (the loop runs every 2 sec)
        
        vb = VByteArray()
        var mask1: UInt16 = 0
        vb.vbAppendUInt8(128); //COMM_GET_STATS
        mask1 = 0
        mask1 = mask1 | UInt16(1) << 10 //time
        mask1 = mask1 | UInt16(1) << 7
        mask1 = mask1 | UInt16(1) << 6
        mask1 = mask1 | UInt16(1) << 5
        mask1 = mask1 | UInt16(1) << 4
        mask1 = mask1 | UInt16(1) << 3
        mask1 = mask1 | UInt16(1) << 2
        
        vb.vbAppendUInt16(UInt16(mask1));
        
        self.sendData(data: vb.data);
    }
    
    
    
   }
    //https://medium.com/simform-engineering/introduction-to-ble-with-ios-swift-47be4465a7fc
//https://medium.com/@cbartel/ios-scan-and-connect-to-a-ble-peripheral-in-the-background-731f960d520d
//https://medium.com/@ios_guru/creating-a-watch-app-with-core-bluetooth-framework-4a94ba6e8645
//https://learn.adafruit.com/build-a-bluetooth-app-using-swift-5?view=all
//https://github.com/vedderb/bldc_uart_comm_stm32f4_discovery

//https://medium.com/@premajanoti/common-challenges-in-integrating-bluetooth-low-energy-ble-in-ios-with-swift-63918460090e



//https://github.com/vedderb/vesc_tool/blob/master/bleuart.cpp
