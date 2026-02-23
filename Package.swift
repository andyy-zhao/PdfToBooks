// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BookReader",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "BookReader", targets: ["BookReader"])
    ],
    targets: [
        .executableTarget(
            name: "BookReader",
            path: "Sources/BookReader"
        )
    ]
)
