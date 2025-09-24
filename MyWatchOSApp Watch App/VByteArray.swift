import Foundation

struct VByteArray {
    public var data: Data

    init() {
        self.data = Data()
    }

    init(data: Data) {
        self.data = data
    }

    private func roundDouble(_ x: Double) -> Double {
        x < 0.0 ? ceil(x - 0.5) : floor(x + 0.5)
    }

    mutating func vbAppendInt64(_ number: Int64) {
        let bytes = withUnsafeBytes(of: number.bigEndian) { Data($0) }
        data.append(bytes)
    }

    mutating func vbAppendUInt64(_ number: UInt64) {
        let bytes = withUnsafeBytes(of: number.bigEndian) { Data($0) }
        data.append(bytes)
    }

    mutating func vbAppendInt32(_ number: Int32) {
        let bytes = withUnsafeBytes(of: number.bigEndian) { Data($0) }
        data.append(bytes)
    }

    mutating func vbAppendUInt32(_ number: UInt32) {
        let bytes = withUnsafeBytes(of: number.bigEndian) { Data($0) }
        data.append(bytes)
    }

    mutating func vbAppendInt16(_ number: Int16) {
        let bytes = withUnsafeBytes(of: number.bigEndian) { Data($0) }
        data.append(bytes)
    }

    mutating func vbAppendUInt16(_ number: UInt16) {
        let bytes = withUnsafeBytes(of: number.bigEndian) { Data($0) }
        data.append(bytes)
        
        //data.append(UInt8(number >> 8))
        //data.append(UInt8(number & 0xFF))
        
    }

    mutating func vbAppendInt8(_ number: Int8) {
        data.append(UInt8(bitPattern: number))
    }

    mutating func vbAppendUInt8(_ number: UInt8) {
        data.append(number)
    }

    mutating func vbAppendDouble64(_ number: Double, scale: Double) {
        vbAppendInt64(Int64(roundDouble(number * scale)))
    }

    mutating func vbAppendDouble32(_ number: Double, scale: Double) {
        vbAppendInt32(Int32(roundDouble(number * scale)))
    }

    mutating func vbAppendDouble16(_ number: Double, scale: Double) {
        vbAppendInt16(Int16(roundDouble(number * scale)))
    }

    mutating func vbAppendDouble32Auto(_ number: Double) {
        // Set subnormal numbers to 0
        var number = number
        if abs(number) < 1.5e-38 {
            number = 0.0
        }

        var exponent: Int32 = 0
        let fraction = frexp(number, &exponent)
        let fractionAbs = abs(fraction)
        var fractionScaled: UInt32 = 0

        if fractionAbs >= 0.5 {
            fractionScaled = UInt32((fractionAbs - 0.5) * 2.0 * 8_388_608.0)
            exponent += 126
        }

        var result = ((UInt32(exponent) & 0xFF) << 23) | (fractionScaled & 0x7FFFFF)
        if fraction < 0 {
            result |= 1 << 31;
        }

        vbAppendUInt32(result)
    }

    mutating func vbAppendDouble64Auto(_ number: Double) {
        let n = Float(number)
        let err = Float(number - Double(n))
        vbAppendDouble32Auto(Double(n))
        vbAppendDouble32Auto(Double(err))
    }

    mutating func vbAppendString(_ str: String) {
        if let stringData = str.data(using: .utf8) {
            data.append(stringData)
            data.append(0)
        } else {
            data.append(0)
        }
    }

    mutating func vbPopFrontInt64() -> Int64 {
        guard data.count >= 8 else { return 0 }

        //print("data startIndex\(data.startIndex)")
        
        var res: Int64 = 0
            res |= Int64(data[data.startIndex]) << 56
            res |= Int64(data[data.startIndex + 1]) << 48
            res |= Int64(data[data.startIndex + 2]) << 40
            res |= Int64(data[data.startIndex + 3]) << 32
            res |= Int64(data[data.startIndex + 4]) << 24
            res |= Int64(data[data.startIndex + 5]) << 16
            res |= Int64(data[data.startIndex + 6]) << 8
            res |= Int64(data[data.startIndex + 7])
        
        data.removeFirst(8)
        return res
    }

    mutating func vbPopFrontUInt64() -> UInt64 {
        guard data.count >= 8 else { return 0 }

        //print("data startIndex\(data.startIndex)")
        
        var res: UInt64 = 0
            res |= UInt64(data[data.startIndex]) << 56
            res |= UInt64(data[data.startIndex + 1]) << 48
            res |= UInt64(data[data.startIndex + 2]) << 40
            res |= UInt64(data[data.startIndex + 3]) << 32
            res |= UInt64(data[data.startIndex + 4]) << 24
            res |= UInt64(data[data.startIndex + 5]) << 16
            res |= UInt64(data[data.startIndex + 6]) << 8
            res |= UInt64(data[data.startIndex + 7])
        
        data.removeFirst(8)
        return res
    }

    mutating func vbPopFrontInt32() -> Int32 {
        guard data.count >= 4 else { return 0 }
        
        //print("data startIndex\(data.startIndex)")
        
        var res: Int32 = 0
        res |= Int32(data[data.startIndex]) << 24
        res |= Int32(data[data.startIndex + 1]) << 16
        res |= Int32(data[data.startIndex + 2]) << 8
        res |= Int32(data[data.startIndex + 3])
        
        data.removeFirst(4)
        return res
    }

    mutating func vbPopFrontUInt32() -> UInt32 {
        
        guard data.count >= 4 else { return 0 }
        
        //print("data startIndex\(data.startIndex)")
        
        var res: UInt32 = 0
        res |= UInt32(data[data.startIndex]) << 24
        res |= UInt32(data[data.startIndex + 1]) << 16
        res |= UInt32(data[data.startIndex + 2]) << 8
        res |= UInt32(data[data.startIndex + 3])

        data.removeFirst(4)
        return res
    }

    mutating func vbPopFrontInt16() -> Int16 {
        guard data.count >= 2 else { return 0 }
        
        //print("data startIndex\(data.startIndex)")
        
        let res = Int16(data[data.startIndex]) << 8 |
                  Int16(data[data.startIndex+1])
        
        data.removeFirst(2)
        return res
    }

    mutating func vbPopFrontUInt16() -> UInt16 {
        guard data.count >= 2 else { return 0 }

        //print("data startIndex\(data.startIndex)")
        
        let res = UInt16(data[data.startIndex]) << 8 |
                  UInt16(data[data.startIndex+1])
        
        data.removeFirst(2)
        return res
    }

    mutating func vbPopFrontInt8() -> Int8 {
        guard !data.isEmpty else { return 0 }
        let value = Int8(bitPattern: data.removeFirst())
        return value
    }

    mutating func vbPopFrontUInt8() -> UInt8 {
        guard !data.isEmpty else { return 0 }
        let value = data.removeFirst()
        return value
    }

    mutating func vbPopFrontDouble64(scale: Double) -> Double {
        Double(vbPopFrontInt64()) / scale
    }

    mutating func vbPopFrontDouble32(scale: Double) -> Double {
        Double(vbPopFrontInt32()) / scale
    }

    mutating func vbPopFrontDouble16(scale: Double) -> Double {
        Double(vbPopFrontInt16()) / scale
    }

    mutating func vbPopFrontDouble32Auto() -> Double {
        let result = vbPopFrontUInt32()
        let exponent = Int32((result >> 23) & 0xFF)
        let fraction = Int32(result & 0x7FFFFF)
        let negative = (result & (1 << 31)) != 0

        var f: Float = 0.0
        if exponent != 0 || fraction != 0 {
            f = Float(fraction) / (8_388_608.0 * 2.0) + 0.5
            f = ldexpf(f, (exponent - 126))
        }
        
        return negative ? -Double(f) : Double(f)
    }

    mutating func vbPopFrontDouble64Auto() -> Double {
        let n = vbPopFrontDouble32Auto()
        let err = vbPopFrontDouble32Auto()
        return n + err
    }

    mutating func vbPopFrontString() -> String {
        guard !data.isEmpty else { return "" }
        guard let nullIndex = data.firstIndex(of: 0) else { return "" }
        let stringData = data.prefix(nullIndex)
        data.removeFirst(nullIndex + 1)
        return String(data: stringData, encoding: .utf8) ?? ""
    }
}
