#if os(macOS)
import AppKit
import DeveloperToolsSupport
import SwiftUI
import Testing

@testable import StorybookKit

@Suite("macOS preview registry conversion")
struct MacOSPreviewRegistryTests {

  @MainActor
  @Test("A SwiftUI registry retains its name and produces renderable content")
  func swiftUIPreview() {
    let registry = PreviewRegistryWrapper(SwiftUIPreviewRegistry.self)

    #expect(registry.displayName == "SwiftUI registry")
    guard case .viewport(let makeContent) = registry.makeViewPortPreview() else {
      Issue.record("Expected a SwiftUI viewport preview")
      return
    }

    let host = NSHostingView(rootView: makeContent())
    #expect(host.fittingSize == NSSize(width: 120, height: 80))
    _ = registry.makeView()
  }

  @MainActor
  @Test("An NSView registry invokes the native view factory")
  func appKitViewPreview() {
    let registry = PreviewRegistryWrapper(AppKitViewPreviewRegistry.self)

    guard case .nsView(let makeView) = registry.makeViewPortPreview() else {
      Issue.record("Expected an NSView preview")
      return
    }

    let view = makeView()
    #expect(view.identifier?.rawValue == "registry-native-view")
    #expect(view.frame.size == NSSize(width: 120, height: 80))
    _ = registry.makeView()
  }

  @MainActor
  @Test("An NSViewController registry preserves real controller presentation")
  func appKitControllerPreview() {
    let registry = PreviewRegistryWrapper(AppKitControllerPreviewRegistry.self)

    guard case .presentedViewController(let makeController) = registry.makeViewPortPreview() else {
      Issue.record("Expected an NSViewController presentation preview")
      return
    }

    let controller = makeController()
    #expect(controller.title == "registry-native-controller")
    #expect(controller.view.frame.size == NSSize(width: 120, height: 80))
    _ = registry.makeView()
  }

  // Parameterized preview initializers are provided by the SDK shipped with Swift 6.4.
  #if compiler(>=6.4)
  @MainActor
  @Test("A grouped registry reports unsupported content without crashing discovery")
  func groupedPreviewIsUnsupported() {
    guard #available(macOS 27.0, *) else { return }
    let registry = PreviewRegistryWrapper(GroupedPreviewRegistry.self)

    guard case .unsupported(let reason) = registry.makeViewPortPreview() else {
      Issue.record("Expected an unsupported grouped preview")
      return
    }
    #expect(reason.contains("single preview"))

    let host = NSHostingView(rootView: AnyView(registry.makeView()))
    #expect(host.fittingSize.height > 0)
  }

  /// Exercises the platform's grouped source layout without depending on private types.
  @available(macOS 27.0, *)
  private struct GroupedPreviewRegistry: PreviewRegistry {
    static var fileID: String { "Tests/MacOSPreviewRegistryTests.swift" }
    static var line: Int { 4 }
    static var column: Int { 1 }

    @MainActor
    static func makePreview() throws -> Preview {
      Preview("Grouped NSView registry", arguments: [1, 2]) { _ in
        NSView(frame: NSRect(x: 0, y: 0, width: 120, height: 80))
      }
    }
  }

  #endif

  /// Supplies the same registry contract emitted by a SwiftUI `#Preview` declaration.
  private struct SwiftUIPreviewRegistry: PreviewRegistry {
    static var fileID: String { "Tests/MacOSPreviewRegistryTests.swift" }
    static var line: Int { 1 }
    static var column: Int { 1 }

    @MainActor
    static func makePreview() throws -> Preview {
      Preview("SwiftUI registry") {
        Color.red.frame(width: 120, height: 80)
      }
    }
  }

  /// Supplies an AppKit view through the platform's public preview initializer.
  private struct AppKitViewPreviewRegistry: PreviewRegistry {
    static var fileID: String { "Tests/MacOSPreviewRegistryTests.swift" }
    static var line: Int { 2 }
    static var column: Int { 1 }

    @MainActor
    static func makePreview() throws -> Preview {
      Preview("NSView registry") {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 120, height: 80))
        view.identifier = .init("registry-native-view")
        return view
      }
    }
  }

  /// Supplies an AppKit controller through the platform's public preview initializer.
  private struct AppKitControllerPreviewRegistry: PreviewRegistry {
    static var fileID: String { "Tests/MacOSPreviewRegistryTests.swift" }
    static var line: Int { 3 }
    static var column: Int { 1 }

    @MainActor
    static func makePreview() throws -> Preview {
      Preview("NSViewController registry") {
        let controller = NSViewController()
        controller.title = "registry-native-controller"
        controller.view = NSView(frame: NSRect(x: 0, y: 0, width: 120, height: 80))
        return controller
      }
    }
  }
}
#endif
