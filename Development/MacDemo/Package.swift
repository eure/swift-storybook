// swift-tools-version:6.3
import PackageDescription

/// A native macOS host that discovers previews from its own executable.
let package = Package(
  name: "StorybookMacDemo",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "StorybookMacDemo", targets: ["StorybookMacDemo"]),
  ],
  dependencies: [
    .package(name: "Storybook", path: "../.."),
  ],
  targets: [
    .executableTarget(
      name: "StorybookMacDemo",
      dependencies: [
        .product(name: "StorybookKit", package: "Storybook"),
      ]
    ),
  ]
)
