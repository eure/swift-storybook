// swift-tools-version:6.0
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
    .library(name: "StorybookKitTextureSupport", targets: ["StorybookKitTextureSupport"]),
  ],
  dependencies: [
    .package(url: "https://github.com/FluidGroup/TextureBridging.git", from: "3.2.1"),
    .package(url: "https://github.com/FluidGroup/TextureSwiftSupport.git", from: "3.20.1"),
    .package(url: "https://github.com/FluidGroup/swiftui-support", from: "0.4.1"),
    .package(url: "https://github.com/FluidGroup/ResultBuilderKit", from: "1.3.0"),
    .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.1"),
    .package(url: "https://github.com/pointfreeco/swift-macro-testing.git", from: "0.5.2"),
  ],
  targets: [
    .target(
      name: "StorybookKit",
      dependencies: [
        "StorybookMacrosPlugin",
        .product(name: "SwiftUISupport", package: "swiftui-support"),
        "ResultBuilderKit",
      ]
    ),
    .macro(
      name: "StorybookMacrosPlugin",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ]
    ),
    .testTarget(
      name: "StorybookMacrosTests",
      dependencies: [
        "StorybookMacrosPlugin",
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
        .product(name: "MacroTesting", package: "swift-macro-testing"),
      ]
    ),
    .target(
      name: "StorybookKitTextureSupport",
      dependencies: [
        .product(name: "TextureSwiftSupport", package: "TextureSwiftSupport"),
        .product(name: "TextureBridging", package: "TextureBridging"),
        "StorybookKit",
      ]
    ),
  ],
  swiftLanguageModes: [.v6, .v5]
)
