#if os(macOS)
import AppKit
import SwiftUI
import Testing

@testable import StorybookKit

@Suite("Native macOS viewport export")
@MainActor
struct StorybookMacOSViewportTests {

  @Test("A SwiftUI export preserves its selector, padding, and bitmap scale")
  func dimensionsAndIdentity() throws {
    let viewport = try makeViewport {
      AnyView(Color.red.frame(height: 100))
    }
    let rendered = try StorybookViewportRenderer.render(
      viewport,
      width: 120,
      scale: 2,
      safeAreaInsets: .init(top: 12, left: 8, bottom: 20, right: 8)
    )
    #expect(rendered.descriptor == viewport.descriptor)
    #expect(rendered.pointSize == CGSize(width: 120, height: 132))
    #expect(rendered.pixelSize == CGSize(width: 240, height: 264))
    let bitmap = try #require(rendered.image.representations.first as? NSBitmapImageRep)
    #expect(bitmap.pixelsWide == 240)
    #expect(bitmap.pixelsHigh == 264)
    #expect(bitmap.colorAt(x: 120, y: 100)?.alphaComponent == 1)
  }

  @Test("AppKit representables remain visible in SwiftUI image exports")
  func nativeRepresentablePixels() throws {
    let viewport = try makeViewport {
      AnyView(NativeColorView().frame(height: 40))
    }
    let rendered = try StorybookViewportRenderer.render(viewport, width: 80, scale: 1)
    let bitmap = try #require(rendered.image.representations.first as? NSBitmapImageRep)
    let color = try #require(bitmap.colorAt(x: 40, y: 20)?.usingColorSpace(.deviceRGB))
    #expect(color.greenComponent > 0.9)
    #expect(color.redComponent < 0.1)
    #expect(color.alphaComponent == 1)
  }

  @Test("Native representables have a window when their export size is measured")
  func windowDependentRepresentableSize() throws {
    let viewport = try makeViewport { AnyView(WindowDependentView()) }
    let rendered = try StorybookViewportRenderer.render(viewport, width: 80, scale: 1)
    #expect(rendered.pointSize == CGSize(width: 80, height: 40))
    let bitmap = try #require(rendered.image.representations.first as? NSBitmapImageRep)
    let color = try #require(bitmap.colorAt(x: 40, y: 20)?.usingColorSpace(.deviceRGB))
    #expect(color.greenComponent > 0.9)
    #expect(color.alphaComponent == 1)
  }

  @Test("Explicit appearance reaches the SwiftUI environment")
  func explicitAppearance() throws {
    let viewport = try makeViewport { AnyView(AppearanceView()) }
    let light = try StorybookViewportRenderer.render(viewport, width: 40, scale: 1, appearance: .light)
    let dark = try StorybookViewportRenderer.render(viewport, width: 40, scale: 1, appearance: .dark)
    let lightBitmap = try #require(light.image.representations.first as? NSBitmapImageRep)
    let darkBitmap = try #require(dark.image.representations.first as? NSBitmapImageRep)
    let lightColor = try #require(lightBitmap.colorAt(x: 20, y: 20)?.usingColorSpace(.deviceRGB))
    let darkColor = try #require(darkBitmap.colorAt(x: 20, y: 20)?.usingColorSpace(.deviceRGB))
    #expect(lightColor.redComponent > 0.9)
    #expect(darkColor.redComponent < 0.1)
  }

  @Test("Invalid dimensions and oversized bitmaps fail before allocation")
  func invalidDimensions() throws {
    let viewport = try makeViewport { AnyView(Color.clear.frame(height: 100)) }
    #expect(throws: StorybookViewportRenderError.invalidWidth) {
      try StorybookViewportRenderer.render(viewport, width: 0, scale: 1)
    }
    #expect(throws: StorybookViewportRenderError.invalidScale) {
      try StorybookViewportRenderer.render(viewport, width: 100, scale: .infinity)
    }
    #expect(throws: StorybookViewportRenderError.invalidSize) {
      try StorybookViewportRenderer.render(
        viewport, width: 100, scale: 1,
        safeAreaInsets: .init(top: .nan, left: 0, bottom: 0, right: 0)
      )
    }
    #expect(throws: StorybookViewportRenderError.tooLarge(maximumPixelCount: 32_000_000)) {
      try StorybookViewportRenderer.render(viewport, width: 100, scale: 100)
    }
  }

  @Test("A native preview uses the NSView export and reports a precise viewport error")
  func nativePreviewSelection() throws {
    let page = makePage { .nsView { SolidGreenView(frame: .init(x: 0, y: 0, width: 80, height: 40)) } }
    let export = try makeExport(page)
    guard case .nsView(let preview) = export else {
      Issue.record("Expected an NSView export")
      return
    }
    #expect(preview.descriptor == page.descriptor)
    #expect(throws: StorybookPreviewExportError.requiresNativeView) {
      try StorybookViewport(page: page)
    }
  }

  @Test("Unsupported previews preserve the reason supplied by discovery")
  func unsupportedPreview() throws {
    let page = makePage { .unsupported("Unsupported preview source") }
    #expect(throws: StorybookPreviewExportError.unsupportedPreview("Unsupported preview source")) {
      try makeExport(page)
    }
    #expect(throws: StorybookPreviewExportError.unsupportedPreview("Unsupported preview source")) {
      try StorybookViewport(page: page)
    }
  }

  @Test("An NSView capture needs a live window and preserves native pixels")
  func nativeViewCapture() throws {
    let page = makePage { .nsView { SolidGreenView(frame: .init(x: 0, y: 0, width: 80, height: 40)) } }
    guard case .nsView(let preview) = try makeExport(page) else { return }
    #expect(throws: StorybookNSViewRenderError.notAttachedToWindow) {
      try StorybookNSViewRenderer.render(preview, width: 80, scale: 1, in: NSView())
    }
    let window = makeWindow()
    defer { window.close() }
    let host = try #require(window.contentView)
    let originalSubviews = host.subviews.count
    let rendered = try StorybookNSViewRenderer.render(
      preview, width: 80, scale: 2,
      safeAreaInsets: .init(top: 10, left: 5, bottom: 20, right: 5),
      in: host
    )
    #expect(rendered.pointSize == CGSize(width: 80, height: 70))
    #expect(rendered.pixelSize == CGSize(width: 160, height: 140))
    #expect(host.subviews.count == originalSubviews)
    let bitmap = try #require(rendered.image.representations.first as? NSBitmapImageRep)
    let color = try #require(bitmap.colorAt(x: 80, y: 50)?.usingColorSpace(.deviceRGB))
    #expect(color.greenComponent > 0.9)
    #expect(color.alphaComponent == 1)
  }

  @Test("Native multiline text reflows to the requested export width")
  func nativeMultilineText() throws {
    let page = makePage {
      .nsView {
        NSTextField(wrappingLabelWithString: String(repeating: "A multiline native label. ", count: 8))
      }
    }
    guard case .nsView(let preview) = try makeExport(page) else { return }
    let window = makeWindow()
    defer { window.close() }
    let host = try #require(window.contentView)
    let narrow = try StorybookNSViewRenderer.render(preview, width: 120, scale: 1, in: host)
    let wide = try StorybookNSViewRenderer.render(preview, width: 480, scale: 1, in: host)
    #expect(narrow.pointSize.width == 120)
    #expect(wide.pointSize.width == 480)
    #expect(narrow.pointSize.height > wide.pointSize.height)
    #expect(wide.pointSize.height > 0)
  }

  @Test("Native alignment insets preserve the requested frame and edge pixels")
  func nativeAlignmentRectBounds() throws {
    let label = NSTextField(wrappingLabelWithString: "A long native multiline label for rendering.")
    let labelPage = makePage { .nsView { label } }
    guard case .nsView(let labelPreview) = try makeExport(labelPage) else { return }
    let window = makeWindow()
    defer { window.close() }
    let host = try #require(window.contentView)
    let labelImage = try StorybookNSViewRenderer.render(labelPreview, width: 180, scale: 1, in: host)
    #expect(label.frame.width == labelImage.pointSize.width)

    let view = InsetEdgeView(frame: .init(x: 0, y: 0, width: 80, height: 40))
    let page = makePage { .nsView { view } }
    guard case .nsView(let preview) = try makeExport(page) else { return }
    let rendered = try StorybookNSViewRenderer.render(
      preview, width: 92, scale: 1,
      safeAreaInsets: .init(top: 0, left: 5, bottom: 0, right: 7),
      in: host
    )
    #expect(view.frame == CGRect(x: 5, y: 0, width: 80, height: 40))
    let bitmap = try #require(rendered.image.representations.first as? NSBitmapImageRep)
    let leftEdge = try #require(bitmap.colorAt(x: 5, y: 20)?.usingColorSpace(.deviceRGB))
    let rightEdge = try #require(bitmap.colorAt(x: 84, y: 20)?.usingColorSpace(.deviceRGB))
    #expect(leftEdge.greenComponent > 0.9)
    #expect(rightEdge.redComponent > 0.9)
    #expect(bitmap.colorAt(x: 85, y: 20)?.alphaComponent == 0)
  }

  @Test("Export does not remove a preview that already belongs to another host")
  func attachedNativeViewIsRejected() throws {
    let window = makeWindow()
    defer { window.close() }
    let host = try #require(window.contentView)
    let view = SolidGreenView(frame: .init(x: 0, y: 0, width: 80, height: 40))
    host.addSubview(view)
    let page = makePage { .nsView { view } }
    guard case .nsView(let preview) = try makeExport(page) else { return }
    #expect(throws: StorybookNSViewRenderError.previewAlreadyAttached) {
      try StorybookNSViewRenderer.render(preview, width: 80, scale: 1, in: host)
    }
    #expect(view.superview === host)
  }

  @Test("Controller capture requires the selected window and captures its content area")
  func controllerCapture() throws {
    let page = makePage {
      .presentedViewController {
        let controller = NSViewController()
        controller.view = SolidGreenView(frame: .init(x: 0, y: 0, width: 80, height: 40))
        return controller
      }
    }
    guard case .presentedViewController(let preview) = try makeExport(page) else { return }
    #expect(throws: StorybookPreviewExportError.requiresPresentedViewController) {
      try StorybookViewport(page: page)
    }
    let window = makeWindow()
    defer { window.close() }
    let controller = preview.makeViewController()
    #expect(throws: StorybookPresentedViewControllerRenderError.notPresentedInWindow) {
      try StorybookPresentedViewControllerRenderer.render(
        preview, presentedViewController: controller, in: window, scale: 1
      )
    }
    window.contentViewController = controller
    let rendered = try StorybookPresentedViewControllerRenderer.render(
      preview, presentedViewController: controller, in: window, scale: 1
    )
    #expect(rendered.pointSize == window.contentView?.bounds.size)
    let bitmap = try #require(rendered.image.representations.first as? NSBitmapImageRep)
    let color = try #require(bitmap.colorAt(x: 20, y: 20)?.usingColorSpace(.deviceRGB))
    #expect(color.greenComponent > 0.9)
  }

  private func makeViewport(content: @escaping @MainActor () -> AnyView) throws -> StorybookViewport {
    _ = NSApplication.shared
    return try StorybookViewport(page: makePage { .viewport(content) })
  }

  private func makePage(
    preview: @escaping @MainActor () -> StorybookViewPortPreview
  ) -> BookPage {
    BookPage(
      fileID: "Tests/StorybookMacOSViewportTests.swift", line: 42,
      title: "macOS export", usesScrollView: false,
      destination: { AnyView(EmptyView()) }, viewPortPreview: preview
    )
  }

  private func makeExport(_ page: BookPage) throws -> StorybookPreviewExport {
    let store = BookStore(book: Book(title: "Tests") { page })
    return try .init(
      bookStore: store,
      selector: .init(name: page.descriptor.name, fileID: page.descriptor.fileID, line: 42)
    )
  }

  private func makeWindow() -> NSWindow {
    _ = NSApplication.shared
    let window = NSWindow(
      contentRect: .init(x: 0, y: 0, width: 100, height: 100),
      styleMask: .borderless, backing: .buffered, defer: false
    )
    window.isReleasedWhenClosed = false
    return window
  }
}

/// A view with deterministic AppKit drawing, used to detect omitted native content.
@MainActor
private final class SolidGreenView: NSView {
  override func draw(_ dirtyRect: NSRect) {
    NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1).setFill()
    bounds.fill()
  }
}

/// Embeds native drawing in SwiftUI so a bitmap-only SwiftUI renderer would lose it.
@MainActor
private struct NativeColorView: NSViewRepresentable {
  func makeNSView(context: Context) -> SolidGreenView { SolidGreenView() }
  func updateNSView(_ nsView: SolidGreenView, context: Context) {}
}

/// Requires real window attachment during SwiftUI's size proposal.
@MainActor
private struct WindowDependentView: NSViewRepresentable {
  func makeNSView(context: Context) -> SolidGreenView { SolidGreenView() }
  func updateNSView(_ nsView: SolidGreenView, context: Context) {}
  func sizeThatFits(_ proposal: ProposedViewSize, nsView: SolidGreenView, context: Context) -> CGSize? {
    CGSize(width: proposal.width ?? 80, height: nsView.window == nil ? 0 : 40)
  }
}

/// Draws distinct frame edges outside its alignment rectangle to detect clipping.
@MainActor
private final class InsetEdgeView: NSView {
  override var alignmentRectInsets: NSEdgeInsets {
    .init(top: 0, left: 2, bottom: 0, right: 2)
  }

  override func draw(_ dirtyRect: NSRect) {
    NSColor.black.setFill()
    bounds.fill()
    NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1).setFill()
    NSRect(x: bounds.minX, y: bounds.minY, width: 1, height: bounds.height).fill()
    NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1).setFill()
    NSRect(x: bounds.maxX - 1, y: bounds.minY, width: 1, height: bounds.height).fill()
  }
}

/// Makes appearance assertions independent of changing system accent colors.
private struct AppearanceView: View {
  @Environment(\.colorScheme) private var colorScheme
  var body: some View {
    (colorScheme == .light ? Color.white : Color.black).frame(height: 40)
  }
}
#endif
