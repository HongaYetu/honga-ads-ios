// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HongaAds",
    platforms: [
        .iOS(.v14),
    ],
    products: [
        .library(name: "HongaAds", targets: ["HongaAds"]),
    ],
    targets: [
        .target(name: "HongaAds", path: "Sources/HongaAds"),
    ]
)
