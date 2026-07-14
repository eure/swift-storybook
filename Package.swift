// swift-tools-version:6.3
import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "Storybook",
  platforms: [
    .iOS(.v16),
    .macCatalyst(.v15),
    .macOS(.v10_15),
  ],
  products: [
    .library(name: "StorybookKit", targets: ["StorybookKit"]),
  ],
  dependencies: [
  ],
  targets: [
    .target(
      name: "StorybookKit",
      dependencies: [
      ]
    ),
  ],
  swiftLanguageModes: [.v6, .v5]
)
