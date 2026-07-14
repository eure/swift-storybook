//
// Copyright (c) 2024 Eureka, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import MachO
import DeveloperToolsSupport

extension Book {

  // MARK: Internal

  /// Should match `StorybookPageMacro._magicSubstring`
  static let _magicSubstring: String = "__🤖🛠️_StorybookMagic_"

  static func findAllBookProviders(
    filterByStorybookPageMacro: Bool = false
  ) -> [any BookProvider.Type]? {
    let moduleName = Bundle.main.bundleURL.deletingPathExtension().lastPathComponent
    guard !moduleName.isEmpty else {
      return nil
    }
    var results: [any BookProvider.Type] = []
    for imageIndex in 0 ..< _dyld_image_count() {
      self.findAllBookProviders(
        inImageIndex: .init(imageIndex),
        filterByStorybookPageMacro: filterByStorybookPageMacro,
        results: &results
      )
    }
    return results
  }

  @available(iOS 17.0, *)
  static func findAllPreviews(
    excludeStorybookPageMacro: Bool = true
  ) -> [PreviewRegistryWrapper]? {
    let moduleName = Bundle.main.bundleURL.deletingPathExtension().lastPathComponent
    guard !moduleName.isEmpty else {
      return nil
    }
    var results: [PreviewRegistryWrapper] = []
    for imageIndex in 0 ..< _dyld_image_count() {
      self.findAllPreviews(
        inImageIndex: .init(imageIndex),
        excludeStorybookPageMacro: excludeStorybookPageMacro,
        results: &results
      )
    }
    return results
  }

  private static func findAllBookProviders(
    inImageIndex imageIndex: UInt32,
    filterByStorybookPageMacro: Bool,
    results: inout [any BookProvider.Type]
  ) {
    // Follows same approach here:  https://github.com/apple/swift-testing/blob/main/Sources/TestingInternals/Discovery.cpp#L318
    guard
      let headerRawPtr: UnsafeRawPointer = _dyld_get_image_header(imageIndex)
        .map(UnsafeRawPointer.init(_:))
    else {
      return
    }
    let headerPtr = headerRawPtr.assumingMemoryBound(
      to: mach_header_64.self
    )
    // https://derekselander.github.io/dsdump/
    var size: UInt = 0
    guard
      let sectionRawPtr = getsectiondata(
        headerPtr,
        SEG_TEXT,
        "__swift5_types",
        &size
      )
      .map(UnsafeRawPointer.init(_:))
    else {
      return
    }
    let capacity: Int = .init(size) / MemoryLayout<SwiftTypeMetadataRecord>.size
    let sectionPtr = sectionRawPtr.assumingMemoryBound(
      to: SwiftTypeMetadataRecord.self
    )
    for index in 0 ..< capacity {
      let record = sectionPtr.advanced(by: index)
      guard
        let contextDescriptor = record.pointee.contextDescriptor(
          from: record
        )
      else {
        continue
      }
      guard !contextDescriptor.pointee.isGeneric() else {
        continue
      }
      guard
        contextDescriptor.pointee.kind().canConformToProtocol,
        !filterByStorybookPageMacro || contextDescriptor.nameContains(self._magicSubstring)
      else {
        continue
      }
      let metadataClosure = contextDescriptor.resolveValue(for: \.metadataAccessFunction)
      let metadata = metadataClosure(0xFF)
      guard
        let metadataAccessFunction = metadata.value
      else {
        continue
      }
      let anyType = unsafeBitCast(
        metadataAccessFunction,
        to: Any.Type.self
      )
      guard let bookProviderType = anyType as? any BookProvider.Type else {
        continue
      }
      results.append(bookProviderType)
    }
  }

  @available(iOS 17.0, *)
  private static func findAllPreviews(
    inImageIndex imageIndex: UInt32,
    excludeStorybookPageMacro: Bool,
    results: inout [PreviewRegistryWrapper]
  ) {
    // Follows same approach here:  https://github.com/apple/swift-testing/blob/main/Sources/TestingInternals/Discovery.cpp#L318
    guard
      let headerRawPtr: UnsafeRawPointer = _dyld_get_image_header(imageIndex)
        .map(UnsafeRawPointer.init(_:))
    else {
      return
    }
    let headerPtr = headerRawPtr.assumingMemoryBound(
      to: mach_header_64.self
    )
    // https://derekselander.github.io/dsdump/
    var size: UInt = 0
    guard
      let sectionRawPtr = getsectiondata(
        headerPtr,
        SEG_TEXT,
        "__swift5_types",
        &size
      )
      .map(UnsafeRawPointer.init(_:))
    else {
      return
    }
    let capacity: Int = .init(size) / MemoryLayout<SwiftTypeMetadataRecord>.size
    let sectionPtr = sectionRawPtr.assumingMemoryBound(
      to: SwiftTypeMetadataRecord.self
    )
    for index in 0 ..< capacity {
      let record = sectionPtr.advanced(by: index)
      guard
        let contextDescriptor = record.pointee.contextDescriptor(
          from: record
        )
      else {
        continue
      }
      guard !contextDescriptor.pointee.isGeneric() else {
        continue
      }
      guard
        case .structType = contextDescriptor.pointee.kind(),
        contextDescriptor.nameContains("PreviewRegistry"),
        !excludeStorybookPageMacro || !contextDescriptor.nameContains(self._magicSubstring)
      else {
        continue
      }
      let metadataClosure = contextDescriptor.resolveValue(for: \.metadataAccessFunction)
      let metadata = metadataClosure(0xFF)
      guard
        let metadataAccessFunction = metadata.value
      else {
        continue
      }
      let anyType = unsafeBitCast(
        metadataAccessFunction,
        to: Any.Type.self
      )
      guard
        let previewType = anyType as? DeveloperToolsSupport.PreviewRegistry.Type
      else {
        continue
      }
      results.append(.init(previewType))
    }
  }
}

extension UnsafePointer where Pointee: SwiftLayoutPointer {

  fileprivate func resolvePointer<U>(for keyPath: KeyPath<Pointee, SwiftRelativePointer<U>>) -> UnsafePointer<U> {
    let base: UnsafeRawPointer = .init(self)
    let fieldOffset = MemoryLayout<Pointee>.offset(of: keyPath)!
    let relativePointer = self.pointee[keyPath: keyPath]
    return base
      .advanced(by: fieldOffset)
      .advanced(by: .init(relativePointer.offset))
      .assumingMemoryBound(to: U.self)
  }

  fileprivate func resolveValue<U>(for keyPath: KeyPath<Pointee, SwiftRelativePointer<U>>) -> U {
    let base: UnsafeRawPointer = .init(self)
    let fieldOffset = MemoryLayout<Pointee>.offset(of: keyPath)!
    let relativePointer = self.pointee[keyPath: keyPath]
    let pointer = base
      .advanced(by: fieldOffset)
      .advanced(by: .init(relativePointer.offset))
    return unsafeBitCast(pointer, to: U.self)
  }
}

extension UnsafePointer where Pointee == SwiftTypeContextDescriptor {
  fileprivate func nameContains(_ string: String) -> Bool {
    string.withCString(
      {
        let nameCString = self.resolvePointer(for: \.name)
        return nil != strstr(nameCString, $0)
      }
    )
  }
}

fileprivate protocol SwiftLayoutPointer {
  static var maskValue: Int32 { get }
}

extension SwiftLayoutPointer {
  fileprivate static var maskValue: Int32 {
    return 0
  }
}

fileprivate struct SwiftRelativePointer<T> {

  var offset: Int32 = 0

  func pointer(
    from base: UnsafeRawPointer,
    vmAddrSlide: Int
  ) -> UnsafePointer<T>? {
    let maskedOffset: Int = .init(offset)
    guard maskedOffset != 0 else {
      return nil
    }
    return base
      .advanced(by: -vmAddrSlide)
      .advanced(by: maskedOffset)
      .assumingMemoryBound(to: T.self)
  }
}

extension SwiftRelativePointer where T: SwiftLayoutPointer {

  func value() -> Int32 {
    offset & T.maskValue
  }

  func pointer(
    from base: UnsafeRawPointer
  ) -> UnsafePointer<T>? {
    let maskedOffset: Int = .init(offset & ~T.maskValue)
    guard maskedOffset != 0 else {
      return nil
    }
    return base
      .advanced(by: maskedOffset)
      .assumingMemoryBound(to: T.self)
  }
}

fileprivate struct SwiftTypeMetadataRecord: SwiftLayoutPointer {

  var pointer: SwiftRelativePointer<SwiftTypeContextDescriptor>

  func contextDescriptor(
    from base: UnsafeRawPointer
  ) -> UnsafePointer<SwiftTypeContextDescriptor>? {
    switch pointer.value() {
    case 0:
      return pointer.pointer(from: base)

    case 1:
      // Untested
      return pointer.pointer(from: base).map {
        let indirection: UnsafeRawPointer = .init($0)
        return indirection
          .assumingMemoryBound(to: UnsafePointer<SwiftTypeContextDescriptor>.self)
          .pointee
      }

    default:
      return nil
    }
  }
}

fileprivate struct SwiftTypeContextDescriptor: SwiftLayoutPointer {
  var flags: UInt32 = 0
  var parent: SwiftRelativePointer<UInt8> = .init()
  var name: SwiftRelativePointer<CChar> = .init()
  var metadataAccessFunction: SwiftRelativePointer<(@convention(thin) (Int) -> MetadataAccessResponse)> = .init()

  func isGeneric() -> Bool {
    return (flags & 0x80) != 0
  }

  func kind() -> Kind {
    // https://github.com/blacktop/go-macho/blob/master/types/swift/types.go#L589
    return .init(rawValue: flags & 0x1F)
  }

  struct MetadataAccessResponse: SwiftLayoutPointer {
    var value: UnsafeRawPointer?
    var state: Int = 0
  }

  static let maskValue: Int32 = .init(MemoryLayout<Int32>.alignment - 1)

  struct Kind: RawRepresentable, Equatable {
    static let module: Self = .init(rawValue: 0)
    static let `extension`: Self = .init(rawValue: 1)
    static let anonymous: Self = .init(rawValue: 2)
    static let `protocol`: Self = .init(rawValue: 3)
    static let opaqueType: Self = .init(rawValue: 4)

    static let typesStart: Self = .init(rawValue: 16)

    static let classType: Self = .init(rawValue: Self.typesStart.rawValue)
    static let structType: Self = .init(rawValue: Self.typesStart.rawValue + 1)
    static let enumType: Self = .init(rawValue: Self.typesStart.rawValue + 2)

    static let typesEnd: Self = .init(rawValue: 31)

    let rawValue: UInt32

    init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    var canConformToProtocol: Bool {
      return (Self.typesStart.rawValue ... Self.typesEnd.rawValue).contains(self.rawValue)
    }
  }
}
