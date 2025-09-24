//
//  Packet.swift
//  MyWatchOSApp Watch App
//
//  Created by Gregory Dymarek on 10/07/2025.
//

import Foundation

class Packet {
    // MARK: - Properties
    private let maxPacketLen: Int = 10000
    private var rxReadPtr: Int = 0
    private var rxWritePtr: Int = 0
    private var bytesLeft: Int = 0
    private let bufferLen: Int
    private var rxBuffer: [UInt8]
    
    // Callbacks for data events
    var packetReceived: ((Data) -> Void)?
    
    // CRC16 table
    private static let crc16Tab: [UInt16] = [
        0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50a5, 0x60c6, 0x70e7,
        0x8108, 0x9129, 0xa14a, 0xb16b, 0xc18c, 0xd1ad, 0xe1ce, 0xf1ef,
        0x1231, 0x0210, 0x3273, 0x2252, 0x52b5, 0x4294, 0x72f7, 0x62d6,
        0x9339, 0x8318, 0xb37b, 0xa35a, 0xd3bd, 0xc39c, 0xf3ff, 0xe3de,
        0x2462, 0x3443, 0x0420, 0x1401, 0x64e6, 0x74c7, 0x44a4, 0x5485,
        0xa56a, 0xb54b, 0x8528, 0x9509, 0xe5ee, 0xf5cf, 0xc5ac, 0xd58d,
        0x3653, 0x2672, 0x1611, 0x0630, 0x76d7, 0x66f6, 0x5695, 0x46b4,
        0xb75b, 0xa77a, 0x9719, 0x8738, 0xf7df, 0xe7fe, 0xd79d, 0xc7bc,
        0x48c4, 0x58e5, 0x6886, 0x78a7, 0x0840, 0x1861, 0x2802, 0x3823,
        0xc9cc, 0xd9ed, 0xe98e, 0xf9af, 0x8948, 0x9969, 0xa90a, 0xb92b,
        0x5af5, 0x4ad4, 0x7ab7, 0x6a96, 0x1a71, 0x0a50, 0x3a33, 0x2a12,
        0xdbfd, 0xcbdc, 0xfbbf, 0xeb9e, 0x9b79, 0x8b58, 0xbb3b, 0xab1a,
        0x6ca6, 0x7c87, 0x4ce4, 0x5cc5, 0x2c22, 0x3c03, 0x0c60, 0x1c41,
        0xedae, 0xfd8f, 0xcdec, 0xddcd, 0xad2a, 0xbd0b, 0x8d68, 0x9d49,
        0x7e97, 0x6eb6, 0x5ed5, 0x4ef4, 0x3e13, 0x2e32, 0x1e51, 0x0e70,
        0xff9f, 0xefbe, 0xdfdd, 0xcffc, 0xbf1b, 0xaf3a, 0x9f59, 0x8f78,
        0x9188, 0x81a9, 0xb1ca, 0xa1eb, 0xd10c, 0xc12d, 0xf14e, 0xe16f,
        0x1080, 0x00a1, 0x30c2, 0x20e3, 0x5004, 0x4025, 0x7046, 0x6067,
        0x83b9, 0x9398, 0xa3fb, 0xb3da, 0xc33d, 0xd31c, 0xe37f, 0xf35e,
        0x02b1, 0x1290, 0x22f3, 0x32d2, 0x4235, 0x5214, 0x6277, 0x7256,
        0xb5ea, 0xa5cb, 0x95a8, 0x8589, 0xf56e, 0xe54f, 0xd52c, 0xc50d,
        0x34e2, 0x24c3, 0x14a0, 0x0481, 0x7466, 0x6447, 0x5424, 0x4405,
        0xa7db, 0xb7fa, 0x8799, 0x97b8, 0xe75f, 0xf77e, 0xc71d, 0xd73c,
        0x26d3, 0x36f2, 0x0691, 0x16b0, 0x6657, 0x7676, 0x4615, 0x5634,
        0xd94c, 0xc96d, 0xf90e, 0xe92f, 0x99c8, 0x89e9, 0xb98a, 0xa9ab,
        0x5844, 0x4865, 0x7806, 0x6827, 0x18c0, 0x08e1, 0x3882, 0x28a3,
        0xcb7d, 0xdb5c, 0xeb3f, 0xfb1e, 0x8bf9, 0x9bd8, 0xabbb, 0xbb9a,
        0x4a75, 0x5a54, 0x6a37, 0x7a16, 0x0af1, 0x1ad0, 0x2ab3, 0x3a92,
        0xfd2e, 0xed0f, 0xdd6c, 0xcd4d, 0xbdaa, 0xad8b, 0x9de8, 0x8dc9,
        0x7c26, 0x6c07, 0x5c64, 0x4c45, 0x3ca2, 0x2c83, 0x1ce0, 0x0cc1,
        0xef1f, 0xff3e, 0xcf5d, 0xdf7c, 0xaf9b, 0xbfba, 0x8fd9, 0x9ff8,
        0x6e17, 0x7e36, 0x4e55, 0x5e74, 0x2e93, 0x3eb2, 0x0ed1, 0x1ef0
    ]
    
    // MARK: - Initialization
    init() {
        bufferLen = maxPacketLen + 8
        rxBuffer = [UInt8](repeating: 0, count: bufferLen)
    }
    
    deinit {
        // No need to explicitly deallocate rxBuffer in Swift (handled by ARC)
    }
    
    // MARK: - Public Methods
    func preparePacket(data: Data) -> Data {
        var toSend = Data()
        
        guard !data.isEmpty, data.count <= maxPacketLen else {
            return toSend
        }
        
        print("Preparing packet: \(data.hexEncodedString(upperCase: true))")
        
        let lenTot = data.count
        
        if lenTot <= 255 {
            toSend.append(2)
            toSend.append(UInt8(lenTot))
        } else if lenTot <= 65535 {
            toSend.append(3)
            toSend.append(UInt8(lenTot >> 8))
            toSend.append(UInt8(lenTot & 0xFF))
        } else {
            toSend.append(4)
            toSend.append(UInt8((lenTot >> 16) & 0xFF))
            toSend.append(UInt8((lenTot >> 8) & 0xFF))
            toSend.append(UInt8(lenTot & 0xFF))
        }
        
        let crc = crc16(data: data)
        toSend.append(data)
        toSend.append(UInt8(crc >> 8))
        toSend.append(UInt8(crc & 0xFF))
        toSend.append(3)
        
        return toSend
    }
    
    func resetState() {
        rxReadPtr = 0
        rxWritePtr = 0
        bytesLeft = 0
    }
    
    func processData(data: Data) {
        var decodedPackets: [Data] = []
        
        //print("Packet: packetReceived start")
        
        for rxData in data {
            var dataLen = rxWritePtr - rxReadPtr
            
            // Out of space
            if dataLen >= bufferLen {
                rxWritePtr = 0
                rxReadPtr = 0
                bytesLeft = 0
                rxBuffer[rxWritePtr] = rxData
                rxWritePtr += 1
                continue
            }
            
            // Shift buffer if out of space
            if rxWritePtr >= bufferLen {
                rxBuffer[0..<dataLen] = rxBuffer[rxReadPtr..<(rxReadPtr + dataLen)]
                rxReadPtr = 0
                rxWritePtr = dataLen
            }
            
            rxBuffer[rxWritePtr] = rxData
            rxWritePtr += 1
            dataLen += 1
            
            // print("rxReadPtr: \(rxReadPtr)")
            // print("rxWritePtr: \(rxWritePtr)")
            // print("rxBuffer len: \(dataLen)")
            // print("bytesLeft: \(bytesLeft)")
            
            if bytesLeft > 1 {
                bytesLeft -= 1
                continue
            }
            
            // Try decoding packets
            while true {
                let b = Array(rxBuffer[rxReadPtr..<(rxReadPtr+dataLen)])
                let res = tryDecodePacket(buffer: b, bytesLeft: &bytesLeft, decodedPackets: &decodedPackets)
                //print("try decode returned: \(res)")
                // More data needed
                if res == -2 {
                    break
                }
                
                if res > 0 {
                    dataLen -= res
                    rxReadPtr += res
                } else if res == -1 {
                    // Invalid packet, move forward
                    rxReadPtr += 1
                    dataLen -= 1
                }
            }
            
            // Nothing left, reset pointers
            if dataLen == 0 {
                rxReadPtr = 0
                rxWritePtr = 0
            }
        }
        
        for packet in decodedPackets {
            //print("Packet: packetReceived OK")
            packetReceived?(packet)
        }
    }
    
    // MARK: - Private Methods
    private func crc16(data: Data) -> UInt16 {
        var cksum: UInt16 = 0
        for byte in data {
            let index = ((cksum >> 8) ^ UInt16(byte)) & 0xFF
            cksum = Packet.crc16Tab[Int(index)] ^ (cksum << 8)
        }
        return cksum
    }
    
    private func tryDecodePacket(buffer: Array<UInt8>, bytesLeft: inout Int, decodedPackets: inout [Data]) -> Int {
        bytesLeft = 0
        let inLen = buffer.count
        
        guard inLen > 0 else {
            bytesLeft = 1
            return -2
        }
        
        //print("try decode: \(buffer.hexEncodedString())")

        let dataStart = buffer[0]
        let isLen8b = dataStart == 2
        let isLen16b = dataStart == 3
        let isLen24b = dataStart == 4
        
        // No valid start byte
        guard isLen8b || isLen16b || isLen24b else {
            return -1
        }
        
        // Not enough data to determine length
        guard inLen >= Int(dataStart) else {
            bytesLeft = Int(dataStart) - inLen
            return -2
        }
        
        var len: Int = 0
        
        if isLen8b {
            len = Int(buffer[1])
            // No support for zero length packets
            guard len >= 1 else {
                return -1
            }
        } else if isLen16b {
            len = (Int(buffer[1]) << 8) | Int(buffer[2])
            // A shorter packet should use less length bytes
            guard len >= 255 else {
                return -1
            }
        } else if isLen24b {
            len = (Int(buffer[1]) << 16) | (Int(buffer[2]) << 8) | Int(buffer[3])
            // A shorter packet should use less length bytes
            guard len >= 65535 else {
                return -1
            }
        }
        
        // Too long packet
        guard len <= maxPacketLen else {
            return -1
        }
        
        // Need more data to determine rest of packet
        guard inLen >= (len + Int(dataStart) + 3) else {
            bytesLeft = (len + Int(dataStart) + 3) - inLen
            return -2
        }
        
        // Invalid stop byte
        guard buffer[len + Int(dataStart) + 2] == 3 else {
            return -1
        }
        
        let crcCalc = crc16(data: Data(buffer[Int(dataStart)..<(Int(dataStart) + len)]))
        let crcRx = (UInt16(buffer[len + Int(dataStart)]) << 8) | UInt16(buffer[len + Int(dataStart) + 1])
        
        if crcCalc == crcRx {
            let res = Data(buffer[Int(dataStart)..<(Int(dataStart) + len)])
            decodedPackets.append(res)
            return len + Int(dataStart) + 3
        } else {
            return -1
        }
    }
}
