# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **swift-storybook**, an iOS library that creates a catalog-style UI component viewer similar to Storybook for web development. The library dynamically discovers and displays SwiftUI previews at runtime, making it easy to view and test UI components in isolation.

## Architecture

### Core Components

- **StorybookKit**: Main library containing the core storybook functionality
- **StorybookKitTextureSupport**: Optional extension for AsyncDisplayKit/Texture framework support  
- **StorybookMacrosPlugin**: Swift macros for enhanced functionality using Swift Syntax

### Key Architecture Patterns

- **Runtime Preview Discovery**: Uses runtime introspection to automatically find and load `#Preview` definitions across the app and linked modules
- **Modular Design**: Separates core functionality from optional extensions (like Texture support)
- **Swift Package Manager**: Modern SPM structure with macro support
- **Cross-Module Support**: Works with app executables, dynamic frameworks, and static libraries

### Runtime Preview System

The library uses a sophisticated system to discover previews at runtime:
- Scans loaded modules for preview definitions
- Uses `machOLoader.swift` for low-level binary introspection 
- Automatically organizes previews by module and name
- Supports both SwiftUI and Texture-based components

## Development Commands

### Building
```bash
# Build the library
swift build

# Build with release configuration  
swift build -c release

# Build tests
swift build --build-tests
```

### Testing
```bash
# Run all tests
swift test

# Run tests with verbose output
swift test -v

# Run specific test target
swift test --filter StorybookMacrosTests
```

### Demo App Development
The `Development/` folder contains an Xcode project for testing:
```bash
# Open the demo project
open Development/Storybook.xcodeproj
```

### CocoaPods Publishing
```bash
# Publish to CocoaPods trunk (maintainers only)
make trunk
```

## Code Organization

### Sources Structure
- `StorybookKit/`: Core library code
  - `Primitives/`: Basic building blocks (Book, BookPage, BookPreview, etc.)
  - `Compositions/`: Higher-level UI components  
  - `Internals/`: Runtime discovery and hosting logic
- `StorybookMacrosPlugin/`: Swift macro implementations
- `StorybookKitTextureSupport/`: Texture framework integration

### Key Files
- `Storybook.swift`: Main entry point view
- `BookGenerator.swift`: Utility functions for generating sample content
- `machOLoader.swift`: Low-level binary inspection for preview discovery
- `PreviewRegistryWrapper.swift`: Interface to SwiftUI's preview system

## Platform Support

- iOS 16.0+
- macCatalyst 15.0+ 
- macOS 10.15+
- Swift 6.0+ (with backward compatibility for Swift 5)

## Dependencies

- **TextureBridging**: AsyncDisplayKit/Texture integration
- **TextureSwiftSupport**: Texture Swift utilities
- **SwiftUISupport**: SwiftUI helper utilities
- **ResultBuilderKit**: Result builder patterns
- **swift-syntax**: Swift macro infrastructure
- **swift-macro-testing**: Macro testing utilities

## Integration Notes

### Static Library Linking
When using with statically linked libraries, you may need the `-all_load` linker flag to ensure all preview symbols are loaded into the binary.

### Preview Discovery
The library automatically discovers `#Preview` definitions, but previews must be properly named and accessible at runtime. The discovery process works across:
- App executable modules
- Dynamic framework modules  
- Static library modules (with proper linking)

## Testing Strategy

The project uses Swift Testing framework for macro tests. Tests are located in `StorybookMacrosTests/` and focus on validating the Swift macro transformations.