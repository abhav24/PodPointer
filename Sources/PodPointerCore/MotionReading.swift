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
