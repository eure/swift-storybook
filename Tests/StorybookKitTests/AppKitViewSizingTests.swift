#if os(macOS)
import AppKit
import SwiftUI
import Testing

@testable import StorybookKit

/// Exercises the real SwiftUI host so tests catch sizing and layout reentrancy.
@MainActor
@Suite("AppKit preview fitting")
struct AppKitViewSizingTests {

  @Test("BookPreview reflows a wrapping label when the available width narrows")
  func wrappingLabel() async throws {
    _ = NSApplication.shared
    let wideLabel = NSTextField(wrappingLabelWithString: paragraph)
    let narrowLabel = NSTextField(wrappingLabelWithString: paragraph)
    let wideHost = NSHostingView(rootView: BookPreview { _ in wideLabel }.frame(width: 480))
    let narrowHost = NSHostingView(rootView: BookPreview { _ in narrowLabel }.frame(width: 160))
    let wideWindow = makeWindow(host: wideHost, width: 480)
    let narrowWindow = makeWindow(host: narrowHost, width: 160)
    defer { wideWindow.close(); narrowWindow.close() }
    for _ in 0..<4 {
      wideHost.layoutSubtreeIfNeeded()
      narrowHost.layoutSubtreeIfNeeded()
      try await Task.sleep(for: .milliseconds(20))
    }

    #expect(wideLabel.superview != nil)
    #expect(narrowLabel.superview != nil)
    #expect(narrowLabel.frame.height > wideLabel.frame.height)
    #expect(narrowLabel.frame.height > narrowLabel.font!.boundingRectForFont.height)
  }

  @Test("BookPreview applies explicit dimensions to its native view")
  func explicitBookPreview() {
    _ = NSApplication.shared
    let button = NSButton(title: "Continue", target: nil, action: nil)
    let preview = BookPreview { _ in button }
      .previewFrame(width: 420, height: 260)
    let host = NSHostingView(rootView: preview)
    let window = makeWindow(host: host, width: 600)
    defer { window.close() }
    host.layoutSubtreeIfNeeded()

    #expect(button.superview != nil)
    #expect(button.frame.width == 420)
    #expect(button.frame.height == 260)
  }

  @Test("A native view with only an initial frame remains visible")
  func frameOnlyView() {
    _ = NSApplication.shared
    let view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 180))
    let host = NSHostingView(rootView: BookPreview { _ in view }.frame(width: 480))
    let window = makeWindow(host: host, width: 480)
    defer { window.close() }
    host.layoutSubtreeIfNeeded()

    #expect(view.frame.width > 0)
    #expect(view.frame.height >= 180)
  }

  private func makeWindow(host: NSView, width: CGFloat) -> NSWindow {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: width, height: 500),
      styleMask: [.borderless], backing: .buffered, defer: false
    )
    window.isReleasedWhenClosed = false
    window.contentView = host
    return window
  }

  private var paragraph: String {
    String(repeating: "Native text must wrap to fit the available preview width. ", count: 4)
  }
}
#endif
