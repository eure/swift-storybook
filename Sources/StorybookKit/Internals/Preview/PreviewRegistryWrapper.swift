import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import StorybookC

/// Resolves a discovered preview registry into Storybook content on the current platform.
@available(iOS 17.0, macOS 14.0, *)
struct PreviewRegistryWrapper: Comparable {

  let previewType: any DeveloperToolsSupport.PreviewRegistry.Type
  let module: String

  init(_ previewType: any DeveloperToolsSupport.PreviewRegistry.Type) {
    self.previewType = previewType
    self.module = previewType.fileID.components(separatedBy: "/").first!
  }

  var fileID: String { previewType.fileID }
  var line: Int { previewType.line }
  var column: Int { previewType.column }
  
  @MainActor
  var displayName: String? {
    guard let rawPreview = try? previewType.makePreview() else {
      return nil
    }
    let preview: FieldReader = .init(rawPreview)
    return preview["displayName"]
  }

  @MainActor
  var makeView: (@MainActor () -> any View) {
    guard let rawPreview = try? previewType.makePreview() else {
      return { EmptyView() }
    }
    let preview: FieldReader = .init(rawPreview)
    let title: String? = preview["displayName"]
    guard let source: FieldReader = preview["source"] ?? preview["dataSource"] else {
      return { unsupportedPreview("Storybook could not read the preview source.", title: title) }
    }
    if let reason = unsupportedStructureReason(in: source) {
      return { unsupportedPreview(reason, title: title) }
    }
    switch source.typeName {

    case "DeveloperToolsSupport.Preview.DataSource": // iOS 26 / macOS 26
      switch source["preview", "contentCategory", "rawValue"] as String {
      case "SwiftUI.View":
        let makeBody: MakeFunctionWrapper<any SwiftUI.View> = .init(source["preview", "structure", "singlePreview", "makeBody"])
        return {
          VStack {
            AnyView(makeBody())
              .toolbar {
                ToolbarItem(placement: sourceLocationPlacement) {
                  Menu {
                    Button {
                      copySourceLocation()
                    } label: {
                      Text("\(fileID):\(line)")
                        .font(.caption.monospacedDigit())
                    }
                  } label: {
                    Image(systemName: "info.circle")
                  }

                }
              }
          }
        }

      #if canImport(UIKit)
      case "UIKit.View": // includes UIViewControllers
        switch source["preview"]!.typeName {
        case "DeveloperToolsSupport.DefaultPreviewSource<__C.UIView>":
          let makeBody: MakeFunctionWrapper<UIKit.UIView> = .init(source["preview", "structure", "singlePreview", "makeBody"])
          return {
            BookPreview(
              fileID,
              line,
              title: title.flatMap({ $0.isEmpty ? nil : $0 }),
              viewBlock: { _ in
                makeBody()
              }
            )
          }

        case "DeveloperToolsSupport.DefaultPreviewSource<__C.UIViewController>":
          let makeBody: MakeFunctionWrapper<UIKit.UIViewController> = .init(source["preview", "structure", "singlePreview", "makeBody"])
          return {
            BookPresent(
              title: title.flatMap({ $0.isEmpty ? nil : $0 }) ?? source.typeName,
              presentingViewControllerBlock: {
                makeBody()
              }
            )
          }

        case let previewTypeName:
          return {
            VStack {
              if let title, !title.isEmpty {
                Text(title)
                  .font(.system(size: 17, weight: .semibold))
              }
              Text("Failed to load preview (preview.typeName = \(previewTypeName))")
                .foregroundStyle(Color.red)
                .font(.caption.monospacedDigit())
              Text("\(fileID):\(line)")
                .font(.caption.monospacedDigit())
              BookSpacer(height: 16)
            }
          }
        }

      #elseif canImport(AppKit)
      case "AppKit.View": // includes NSViewControllers
        switch source["preview"]!.typeName {
        case "DeveloperToolsSupport.DefaultPreviewSource<__C.NSView>":
          let makeBody: MakeFunctionWrapper<NSView> = .init(source["preview", "structure", "singlePreview", "makeBody"])
          return {
            BookPreview(
              fileID,
              line,
              title: title.flatMap({ $0.isEmpty ? nil : $0 }),
              viewBlock: { _ in
                makeBody()
              }
            )
          }

        case "DeveloperToolsSupport.DefaultPreviewSource<__C.NSViewController>":
          let makeBody: MakeFunctionWrapper<NSViewController> = .init(source["preview", "structure", "singlePreview", "makeBody"])
          return {
            BookPresent(
              title: title.flatMap({ $0.isEmpty ? nil : $0 }) ?? source.typeName,
              presentingViewControllerBlock: {
                makeBody()
              }
            )
          }

        case let previewTypeName:
          return {
            VStack {
              if let title, !title.isEmpty {
                Text(title)
                  .font(.system(size: 17, weight: .semibold))
              }
              Text("Failed to load preview (preview.typeName = \(previewTypeName))")
                .foregroundStyle(Color.red)
                .font(.caption.monospacedDigit())
              Text("\(fileID):\(line)")
                .font(.caption.monospacedDigit())
              BookSpacer(height: 16)
            }
          }
        }

      #endif

      case let contentCategory:
        return {
          VStack {
            if let title, !title.isEmpty {
              Text(title)
                .font(.system(size: 17, weight: .semibold))
            }
            Text("Failed to load preview (DeveloperToolsSupport.PreviewSourceContentCategory = \(contentCategory))")
              .foregroundStyle(Color.red)
              .font(.caption.monospacedDigit())
            Text("\(fileID):\(line)")
              .font(.caption.monospacedDigit())
            BookSpacer(height: 16)
          }
        }

      }

    case "DeveloperToolsSupport.DefaultPreviewSource<SwiftUI.ViewPreviewBody>": // iOS 18 / macOS 15
      let makeBody: MakeFunctionWrapper<any SwiftUI.View> = .init(source["structure", "singlePreview", "makeBody"])
      return {
        VStack {
          AnyView(makeBody())
            .toolbar {
              ToolbarItem(placement: sourceLocationPlacement) {
                Menu {
                  Button {
                    copySourceLocation()
                  } label: {
                    Text("\(fileID):\(line)")
                      .font(.caption.monospacedDigit())
                  }
                } label: {
                  Image(systemName: "info.circle")
                }

              }
            }
        }
      }

    #if canImport(UIKit)
    case "DeveloperToolsSupport.DefaultPreviewSource<__C.UIView>": // iOS 18
      let makeBody: MakeFunctionWrapper<UIView> = .init(source["structure", "singlePreview", "makeBody"])
      return {
        BookPreview(
          fileID,
          line,
          title: title.flatMap({ $0.isEmpty ? nil : $0 }),
          viewBlock: { _ in
            makeBody()
          }
        )
      }

    case "DeveloperToolsSupport.DefaultPreviewSource<__C.UIViewController>": // iOS 18
      let makeBody: MakeFunctionWrapper<UIViewController> = .init(source["structure", "singlePreview", "makeBody"])
      return {
        BookPresent(
          title: title.flatMap({ $0.isEmpty ? nil : $0 }) ?? source.typeName,
          presentingViewControllerBlock: {
            makeBody()
          }
        )
      }

    #elseif canImport(AppKit)
    case "DeveloperToolsSupport.DefaultPreviewSource<__C.NSView>": // macOS 15
      let makeBody: MakeFunctionWrapper<NSView> = .init(source["structure", "singlePreview", "makeBody"])
      return {
        BookPreview(
          fileID,
          line,
          title: title.flatMap({ $0.isEmpty ? nil : $0 }),
          viewBlock: { _ in
            makeBody()
          }
        )
      }

    case "DeveloperToolsSupport.DefaultPreviewSource<__C.NSViewController>": // macOS 15
      let makeBody: MakeFunctionWrapper<NSViewController> = .init(source["structure", "singlePreview", "makeBody"])
      return {
        BookPresent(
          title: title.flatMap({ $0.isEmpty ? nil : $0 }) ?? source.typeName,
          presentingViewControllerBlock: {
            makeBody()
          }
        )
      }

    #endif

    case "SwiftUI.ViewPreviewSource": // iOS 17 / macOS 14
      let makeView: MakeFunctionWrapper<any SwiftUI.View> = .init(source["makeView"])
      return {
        VStack {
          if let title, !title.isEmpty {
            Text(title)
              .font(.system(size: 17, weight: .semibold))
          }
          AnyView(makeView())
          Text("\(fileID):\(line)")
            .font(.caption.monospacedDigit())
          BookSpacer(height: 16)
        }
      }

    #if canImport(UIKit)
    case "UIKit.UIViewPreviewSource": // iOS 17
      let makeView: MakeFunctionWrapper<UIView> = .init(nonSendable: source["makeView"])
      return {
        BookPreview(
          fileID,
          line,
          title: title.flatMap({ $0.isEmpty ? nil : $0 }),
          viewBlock: { _ in
            makeView()
          }
        )
      }

    case "UIKit.UIViewControllerPreviewSource": // iOS 17
      let makeViewController: MakeFunctionWrapper<UIViewController> = .init(nonSendable: source["makeViewController"])
      return {
        BookPresent(
          title: title.flatMap({ $0.isEmpty ? nil : $0 }) ?? source.typeName,
          presentingViewControllerBlock: {
            makeViewController()
          }
        )
      }

    #elseif canImport(AppKit)
    case "AppKit.NSViewPreviewSource": // macOS 14
      let makeView: MakeFunctionWrapper<NSView> = .init(nonSendable: source["makeView"])
      return {
        BookPreview(
          fileID,
          line,
          title: title.flatMap({ $0.isEmpty ? nil : $0 }),
          viewBlock: { _ in
            makeView()
          }
        )
      }

    case "AppKit.NSViewControllerPreviewSource": // macOS 14
      let makeViewController: MakeFunctionWrapper<NSViewController> = .init(nonSendable: source["makeViewController"])
      return {
        BookPresent(
          title: title.flatMap({ $0.isEmpty ? nil : $0 }) ?? source.typeName,
          presentingViewControllerBlock: {
            makeViewController()
          }
        )
      }

    #endif

    case let sourceTypeName:
      return {
        VStack {
          if let title, !title.isEmpty {
            Text(title)
              .font(.system(size: 17, weight: .semibold))
          }
          Text("Failed to load preview (\(sourceTypeName))")
            .foregroundStyle(Color.red)
            .font(.caption.monospacedDigit())
          Text("\(fileID):\(line)")
            .font(.caption.monospacedDigit())
          BookSpacer(height: 16)
        }
      }
    }
  }

  @MainActor
  func makeViewPortPreview() -> StorybookViewPortPreview {
    guard let rawPreview = try? previewType.makePreview() else {
      return .unsupported("Storybook could not create the preview source.")
    }
    let preview: FieldReader = .init(rawPreview)
    guard let source: FieldReader = preview["source"] ?? preview["dataSource"] else {
      return .unsupported("Storybook could not read the preview source.")
    }
    if let reason = unsupportedStructureReason(in: source) {
      return .unsupported(reason)
    }

    switch source.typeName {
    case "DeveloperToolsSupport.Preview.DataSource": // iOS 26 / macOS 26
      switch source["preview", "contentCategory", "rawValue"] as String {
      case "SwiftUI.View":
        let makeBody: MakeFunctionWrapper<any SwiftUI.View> = .init(source["preview", "structure", "singlePreview", "makeBody"])
        return .viewport { AnyView(makeBody()) }

      #if canImport(UIKit)
      case "UIKit.View":
        switch source["preview"]!.typeName {
        case "DeveloperToolsSupport.DefaultPreviewSource<__C.UIView>":
          let makeBody: MakeFunctionWrapper<UIView> = .init(source["preview", "structure", "singlePreview", "makeBody"])
          return .uiView(makeBody.callAsFunction)

        case "DeveloperToolsSupport.DefaultPreviewSource<__C.UIViewController>":
          let makeBody: MakeFunctionWrapper<UIViewController> = .init(source["preview", "structure", "singlePreview", "makeBody"])
          return .presentedViewController(makeBody.callAsFunction)

        default:
          return .unsupported("This UIKit preview source is not supported.")
        }

      #elseif canImport(AppKit)
      case "AppKit.View":
        switch source["preview"]!.typeName {
        case "DeveloperToolsSupport.DefaultPreviewSource<__C.NSView>":
          let makeBody: MakeFunctionWrapper<NSView> = .init(source["preview", "structure", "singlePreview", "makeBody"])
          return .nsView(makeBody.callAsFunction)

        case "DeveloperToolsSupport.DefaultPreviewSource<__C.NSViewController>":
          let makeBody: MakeFunctionWrapper<NSViewController> = .init(source["preview", "structure", "singlePreview", "makeBody"])
          return .presentedViewController(makeBody.callAsFunction)

        default:
          return .unsupported("This AppKit preview source is not supported.")
        }

      #endif

      default:
        return .unsupported("This preview content category is not supported.")
      }

    case "DeveloperToolsSupport.DefaultPreviewSource<SwiftUI.ViewPreviewBody>": // iOS 18 / macOS 15
      let makeBody: MakeFunctionWrapper<any SwiftUI.View> = .init(source["structure", "singlePreview", "makeBody"])
      return .viewport { AnyView(makeBody()) }

    #if canImport(UIKit)
    case "DeveloperToolsSupport.DefaultPreviewSource<__C.UIView>": // iOS 18
      let makeBody: MakeFunctionWrapper<UIView> = .init(source["structure", "singlePreview", "makeBody"])
      return .uiView(makeBody.callAsFunction)

    case "DeveloperToolsSupport.DefaultPreviewSource<__C.UIViewController>": // iOS 18
      let makeBody: MakeFunctionWrapper<UIViewController> = .init(source["structure", "singlePreview", "makeBody"])
      return .presentedViewController(makeBody.callAsFunction)

    #elseif canImport(AppKit)
    case "DeveloperToolsSupport.DefaultPreviewSource<__C.NSView>": // macOS 15
      let makeBody: MakeFunctionWrapper<NSView> = .init(source["structure", "singlePreview", "makeBody"])
      return .nsView(makeBody.callAsFunction)

    case "DeveloperToolsSupport.DefaultPreviewSource<__C.NSViewController>": // macOS 15
      let makeBody: MakeFunctionWrapper<NSViewController> = .init(source["structure", "singlePreview", "makeBody"])
      return .presentedViewController(makeBody.callAsFunction)

    #endif

    case "SwiftUI.ViewPreviewSource": // iOS 17 / macOS 14
      let makeView: MakeFunctionWrapper<any SwiftUI.View> = .init(source["makeView"])
      return .viewport { AnyView(makeView()) }

    #if canImport(UIKit)
    case "UIKit.UIViewPreviewSource": // iOS 17
      let makeView: MakeFunctionWrapper<UIView> = .init(
        nonSendable: source["makeView"]
      )
      return .uiView(makeView.callAsFunction)

    case "UIKit.UIViewControllerPreviewSource": // iOS 17
      let makeViewController: MakeFunctionWrapper<UIViewController> = .init(
        nonSendable: source["makeViewController"]
      )
      return .presentedViewController(makeViewController.callAsFunction)

    #elseif canImport(AppKit)
    case "AppKit.NSViewPreviewSource": // macOS 14
      let makeView: MakeFunctionWrapper<NSView> = .init(
        nonSendable: source["makeView"]
      )
      return .nsView(makeView.callAsFunction)

    case "AppKit.NSViewControllerPreviewSource": // macOS 14
      let makeViewController: MakeFunctionWrapper<NSViewController> = .init(
        nonSendable: source["makeViewController"]
      )
      return .presentedViewController(makeViewController.callAsFunction)

    #endif

    default:
      return .unsupported("This preview source is not supported.")
    }
  }

  /// Rejects unsupported runtime layouts before extracting their erased view factory.
  ///
  /// A parameterized `#Preview` uses a grouped structure instead of `singlePreview`.
  /// Keep that preview visible as unsupported without terminating registry discovery.
  private func unsupportedStructureReason(in source: FieldReader) -> String? {
    let contentSource: FieldReader
    if source.typeName == "DeveloperToolsSupport.Preview.DataSource" {
      guard let nestedSource = source["preview"],
        nestedSource.value(at: "contentCategory", "rawValue") is String
      else {
        return "This preview data source is not supported."
      }
      contentSource = nestedSource
    } else {
      contentSource = source
    }

    if contentSource.typeName.hasPrefix("DeveloperToolsSupport.DefaultPreviewSource<"),
      contentSource.value(at: "structure", "singlePreview", "makeBody") == nil
    {
      return "This preview structure is not supported. Storybook requires a single preview."
    }
    return nil
  }

  @MainActor
  private func unsupportedPreview(_ reason: String, title: String?) -> some View {
    VStack {
      if let title, !title.isEmpty {
        Text(title)
          .font(.system(size: 17, weight: .semibold))
      }
      Text(reason)
        .foregroundStyle(Color.red)
        .font(.caption.monospacedDigit())
      Text("\(fileID):\(line)")
        .font(.caption.monospacedDigit())
      BookSpacer(height: 16)
    }
  }

  /// Uses the native trailing toolbar position for source-location information.
  private var sourceLocationPlacement: ToolbarItemPlacement {
    #if os(macOS)
    .primaryAction
    #else
    .topBarTrailing
    #endif
  }

  @MainActor
  private func copySourceLocation() {
    let location = "\(fileID):\(line)"
    #if canImport(UIKit)
    UIPasteboard.general.string = location
    #elseif canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(location, forType: .string)
    #endif
  }

  // MARK: Comparable

  static func < (lhs: PreviewRegistryWrapper, rhs: PreviewRegistryWrapper) -> Bool {
    if lhs.module == rhs.module {
      return lhs.line < rhs.line
    }
    return lhs.module < rhs.module
  }


  // MARK: Equatable

  static func == (lhs: PreviewRegistryWrapper, rhs: PreviewRegistryWrapper) -> Bool {
    lhs.line == rhs.line && lhs.module == rhs.module
  }


  // MARK: - FieldReader

  /// Reads the reflected preview source fields supplied by the platform runtime.
  private struct FieldReader {

    let instance: Any
    let typeName: String

    init(_ instance: Any) {
      self.instance = instance
      self.typeName = String(reflecting: type(of: instance))
      let mirror: Mirror = .init(reflecting: instance)
      self.fields = .init(
        uniqueKeysWithValues: mirror.children.compactMap { (label, value) in
          label.map({ ($0, value) })
        }
      )
    }

    subscript<T>(_ key: String, _ nextKeys: String...) -> T {
      if nextKeys.isEmpty {
        return fields[key]! as! T
      }
      else {
        return Self.traverse(from: fields[key]!, nextKeys: nextKeys) as! T
      }
    }

    subscript(_ key: String, _ nextKeys: String...) -> FieldReader? {
      fields[key].map {
        .init(Self.traverse(from: $0, nextKeys: nextKeys))
      }
    }

    /// Returns nil when a runtime field path is absent, including unknown enum cases.
    func value(at keys: String...) -> Any? {
      guard let firstKey = keys.first, var value = fields[firstKey] else {
        return nil
      }
      for key in keys.dropFirst() {
        guard let child = Mirror(reflecting: value).children.first(where: { $0.label == key }) else {
          return nil
        }
        value = child.value
      }
      return value
    }

    private let fields: [String: Any]

    private static func traverse<C: Collection<String>>(from first: Any, nextKeys: C) -> Any {
      if let key = nextKeys.first {
        let mirror: Mirror = .init(reflecting: first)
        return self.traverse(
          from: mirror.children.first(where: { $0.label == key })!.value,
          nextKeys: nextKeys.dropFirst()
        )
      }
      else {
        return first
      }
    }
  }


  // MARK: - MakeFunctionWrapper

  /// Invokes an erased preview factory while preserving its main-actor isolation.
  @MainActor
  private struct MakeFunctionWrapper<T> {

    typealias Closure = @MainActor @Sendable () -> T
    private let closure: Closure

    init(_ closure: Any) {
      self.closure = unsafeBitCast(
        closure,
        to: Closure.self
      )
    }
    
    @available(iOS, introduced: 17.0, obsoleted: 18.0)
    @available(macCatalyst, unavailable)
    @available(macOS, introduced: 14.0, obsoleted: 15.0)
    init(nonSendable closure: Any) where T: AnyObject {
      self.closure = {
        Self.invokeNonSendableClosure(closure)
      }
    }

    func callAsFunction() -> T {
      closure()
    }

    private static func invokeNonSendableClosure(_ closure: Any) -> T where T: AnyObject {
      func invoke<Closure>(_ closure: Closure) -> T {
        let functionSize = MemoryLayout<UnsafeRawPointer>.stride
        let contextSize = MemoryLayout<UnsafeRawPointer?>.stride
        precondition(
          MemoryLayout<Closure>.size == functionSize + contextSize,
          "Unexpected Swift closure representation"
        )
        let (function, context) = withUnsafeBytes(of: closure) {
          (
            $0.load(as: UnsafeRawPointer.self),
            $0.load(
              fromByteOffset: functionSize,
              as: UnsafeRawPointer?.self
            )
          )
        }
        let result = StorybookInvokeLegacyObjectClosure(function, context)!
        return Unmanaged<T>.fromOpaque(result).takeRetainedValue()
      }
      return _openExistential(closure, do: invoke)
    }

  }
}
