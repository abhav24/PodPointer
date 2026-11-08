// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PodPointer",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "PodPointer", targets: ["PodPointer"])
    ],
    targets: [
        .target(name: "PodPointerCore"),
        .executableTarget(name: "PodPointer", dependencies: ["PodPointerCore"]),
        .testTarget(name: "PodPointerCoreTests", dependencies: ["PodPointerCore"])
    ]
)
