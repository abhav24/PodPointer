import Foundation

public struct Vector3: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public static let zero = Vector3(x: 0, y: 0, z: 0)

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static func + (left: Vector3, right: Vector3) -> Vector3 {
        Vector3(x: left.x + right.x, y: left.y + right.y, z: left.z + right.z)
    }

    public static func - (left: Vector3, right: Vector3) -> Vector3 {
        Vector3(x: left.x - right.x, y: left.y - right.y, z: left.z - right.z)
    }

    public static func * (vector: Vector3, scale: Double) -> Vector3 {
        Vector3(x: vector.x * scale, y: vector.y * scale, z: vector.z * scale)
    }

    public func dot(_ other: Vector3) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    public var magnitude: Double {
        dot(self).squareRoot()
    }

    public var normalized: Vector3 {
        let length = magnitude
        return length > 0 ? self * (1 / length) : self
    }
}

/// One motion sample from the AirPods inside the case.
public struct MotionReading: Equatable, Sendable {
    /// Radians per second, in the sensor's own frame.
    public var rotationRate: Vector3
    /// In g, with gravity removed.
    public var userAcceleration: Vector3
    /// Seconds.
    public var timestamp: Double

    public init(rotationRate: Vector3, userAcceleration: Vector3, timestamp: Double) {
        self.rotationRate = rotationRate
        self.userAcceleration = userAcceleration
        self.timestamp = timestamp
    }
}
