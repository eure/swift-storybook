#if os(macOS)
import AppKit
import SwiftUI

/// The raw SwiftUI content of one selected page, without the catalog interface.
@available(macOS 14.0, *)
public struct StorybookViewport: View {

  public let descriptor: BookPageDescriptor
  private let destination: @MainActor () -> AnyView

  @MainActor
  public init(bookStore: BookStore, selector: BookPageSelector) throws {
    try self.init(page: bookStore.resolve(selector))
  }

  @MainActor
  public init(page: BookPage) throws {
    switch page.viewPortPreview() {
    case .viewport(let destination):
      self.init(descriptor: page.descriptor, destination: destination)
    case .nsView:
      throw StorybookPreviewExportError.requiresNativeView
    case .presentedViewController:
      throw StorybookPreviewExportError.requiresPresentedViewController
    case .unsupported(let reason):
      throw StorybookPreviewExportError.unsupportedPreview(reason)
    }
  }

  fileprivate init(
    descriptor: BookPageDescriptor,
    destination: @escaping @MainActor () -> AnyView
  ) {
    self.descriptor = descriptor
    self.destination = destination
  }

  public var body: some View {
    destination()
      .accessibilityIdentifier(descriptor.accessibilityIdentifier)
  }
}

/// Content selected for native macOS image export.
///
/// SwiftUI content is fitted in an AppKit hosting controller. Native views need
/// a window-backed host; controllers must already belong to the capture window.
@available(macOS 14.0, *)
public enum StorybookPreviewExport {
  case viewport(StorybookViewport)
  case nsView(StorybookNSView)
  case presentedViewController(StorybookPresentedViewController)

  @MainActor
  public init(bookStore: BookStore, selector: BookPageSelector) throws {
    let page = try bookStore.resolve(selector)
    switch page.viewPortPreview() {
    case .viewport(let destination):
      self = .viewport(.init(descriptor: page.descriptor, destination: destination))
    case .nsView(let makeView):
      self = .nsView(.init(descriptor: page.descriptor, makeView: makeView))
    case .presentedViewController(let makeViewController):
      self = .presentedViewController(
        .init(descriptor: page.descriptor, makeViewController: makeViewController)
      )
    case .unsupported(let reason):
      throw StorybookPreviewExportError.unsupportedPreview(reason)
    }
  }
}

/// A factory for a native AppKit preview and its source identity.
@available(macOS 14.0, *)
public struct StorybookNSView {

  public let descriptor: BookPageDescriptor
  private let factory: @MainActor () -> NSView

  fileprivate init(descriptor: BookPageDescriptor, makeView: @escaping @MainActor () -> NSView) {
    self.descriptor = descriptor
    self.factory = makeView
  }

  /// Creates the view to display or capture. The factory should return an unattached view.
  @MainActor
  public func makeView() -> NSView {
    factory()
  }
}

/// A controller factory whose output is captured after native AppKit presentation.
@available(macOS 14.0, *)
public struct StorybookPresentedViewController {

  public let descriptor: BookPageDescriptor
  private let factory: @MainActor () -> NSViewController

  fileprivate init(
    descriptor: BookPageDescriptor,
    makeViewController: @escaping @MainActor () -> NSViewController
  ) {
    self.descriptor = descriptor
    self.factory = makeViewController
  }

  @MainActor
  public func makeViewController() -> NSViewController {
    factory()
  }
}

/// A mismatch between a preview's native representation and its export path.
@available(macOS 14.0, *)
public enum StorybookPreviewExportError: Error, Equatable, LocalizedError {
  case requiresNativeView
  case requiresPresentedViewController
  case unsupportedPreview(String)

  public var errorDescription: String? {
    switch self {
    case .requiresNativeView:
      "This preview is an NSView and must be exported with StorybookNSViewRenderer."
    case .requiresPresentedViewController:
      "This preview is an NSViewController and must be exported after presentation."
    case .unsupportedPreview(let reason):
      reason
    }
  }
}

/// A native bitmap together with the selected page and its measured dimensions.
@available(macOS 14.0, *)
public struct StorybookExportImage {
  public let image: NSImage
  public let descriptor: BookPageDescriptor
  public let pointSize: CGSize
  public let pixelSize: CGSize
}

/// The interface appearance applied to both SwiftUI and AppKit export content.
@available(macOS 14.0, *)
public enum StorybookViewportAppearance: String, CaseIterable, Codable, Sendable {
  case light
  case dark

  fileprivate var colorScheme: ColorScheme {
    self == .light ? .light : .dark
  }

  public var appKitAppearance: NSAppearance? {
    NSAppearance(named: self == .light ? .aqua : .darkAqua)
  }
}

/// Validation and bitmap allocation failures reported before export completes.
@available(macOS 14.0, *)
public enum StorybookViewportRenderError: Error, Equatable, LocalizedError {
  case invalidWidth
  case invalidScale
  case invalidSize
  case tooLarge(maximumPixelCount: Int)
  case captureFailed

  public var errorDescription: String? {
    switch self {
    case .invalidWidth:
      "Viewport width must be finite and greater than zero."
    case .invalidScale:
      "Viewport scale must be finite and greater than zero."
    case .invalidSize:
      "Viewport content did not produce a finite, nonzero size."
    case .tooLarge(let maximumPixelCount):
      "Viewport image exceeds the maximum of \(maximumPixelCount) pixels."
    case .captureFailed:
      "AppKit could not allocate the bitmap used to capture the preview."
    }
  }
}

/// Hosts a SwiftUI viewport in AppKit, including embedded native representables.
///
/// An unattached host uses a temporary borderless window during rendering. That
/// window is never ordered front and does not change the application's key window.
@available(macOS 14.0, *)
@MainActor
public final class StorybookViewportHost: NSViewController {

  public let descriptor: BookPageDescriptor
  private let hostedViewController: NSHostingController<AnyView>
  private let insets: NSEdgeInsets

  public init(
    viewport: StorybookViewport,
    appearance: StorybookViewportAppearance? = nil,
    safeAreaInsets: NSEdgeInsets = .init()
  ) {
    descriptor = viewport.descriptor
    insets = safeAreaInsets
    hostedViewController = NSHostingController(
      rootView: StorybookViewportRenderer.rootView(
        viewport: viewport,
        appearance: appearance,
        safeAreaInsets: safeAreaInsets
      )
    )
    super.init(nibName: nil, bundle: nil)
    hostedViewController.safeAreaRegions = []
    hostedViewController.view.appearance = appearance?.appKitAppearance
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func loadView() {
    view = StorybookCaptureView()
    addChild(hostedViewController)
    hostedViewController.view.autoresizingMask = [.width, .height]
    view.addSubview(hostedViewController.view)
  }

  /// Fits content to a point width, then captures its AppKit view hierarchy.
  ///
  /// Scrolling content retains its native layout behavior; this method does not
  /// expand nested scroll views or rasterize independently presented windows.
  public func render(
    width: CGFloat,
    scale: CGFloat = NSScreen.main?.backingScaleFactor ?? 1
  ) throws -> StorybookExportImage {
    try StorybookViewportRenderer.validate(width: width, scale: scale, insets: insets)
    // Native representables may consult their window during measurement. Attach
    // first using a bounded provisional size, then measure the requested width.
    let captureWindow: NSWindow?
    if view.window == nil {
      let initialSize = CGSize(width: min(width, 1_024), height: 1)
      let window = NSWindow(
        contentRect: .init(origin: .zero, size: initialSize),
        styleMask: .borderless,
        backing: .buffered,
        defer: false
      )
      window.isReleasedWhenClosed = false
      window.isOpaque = false
      window.backgroundColor = .clear
      window.contentViewController = self
      captureWindow = window
    } else {
      captureWindow = nil
    }
    defer {
      captureWindow?.contentViewController = nil
      captureWindow?.close()
    }

    hostedViewController.view.frame = view.bounds
    view.layoutSubtreeIfNeeded()
    let fittedSize = hostedViewController.sizeThatFits(
      in: .init(width: width, height: CGFloat.greatestFiniteMagnitude)
    )
    let pointSize = CGSize(width: width, height: fittedSize.height)
    try StorybookViewportRenderer.validate(pointSize: pointSize, scale: scale)
    captureWindow?.setContentSize(pointSize)
    view.frame.size = pointSize
    hostedViewController.view.frame = .init(origin: .zero, size: pointSize)
    return try StorybookViewportRenderer.capture(
      view: hostedViewController.view,
      descriptor: descriptor,
      scale: scale
    )
  }
}

/// Renders fitted SwiftUI content through AppKit to preserve native subviews.
@available(macOS 14.0, *)
@MainActor
public enum StorybookViewportRenderer {

  public static let maximumPixelCount = 32_000_000

  public static func render(
    _ viewport: StorybookViewport,
    width: CGFloat,
    scale: CGFloat = NSScreen.main?.backingScaleFactor ?? 1,
    appearance: StorybookViewportAppearance? = nil,
    safeAreaInsets: NSEdgeInsets = .init()
  ) throws -> StorybookExportImage {
    try validate(width: width, scale: scale, insets: safeAreaInsets)
    return try StorybookViewportHost(
      viewport: viewport,
      appearance: appearance,
      safeAreaInsets: safeAreaInsets
    ).render(width: width, scale: scale)
  }

  fileprivate static func rootView(
    viewport: StorybookViewport,
    appearance: StorybookViewportAppearance?,
    safeAreaInsets: NSEdgeInsets
  ) -> AnyView {
    let content = AnyView(
      viewport
        .padding(.top, max(0, safeAreaInsets.top))
        .padding(.leading, max(0, safeAreaInsets.left))
        .padding(.bottom, max(0, safeAreaInsets.bottom))
        .padding(.trailing, max(0, safeAreaInsets.right))
    )
    if let appearance {
      return AnyView(content.environment(\.colorScheme, appearance.colorScheme))
    }
    return content
  }

  fileprivate static func validate(width: CGFloat, scale: CGFloat, insets: NSEdgeInsets) throws {
    guard width.isFinite, width > 0 else {
      throw StorybookViewportRenderError.invalidWidth
    }
    guard scale.isFinite, scale > 0 else {
      throw StorybookViewportRenderError.invalidScale
    }
    guard [insets.top, insets.left, insets.bottom, insets.right].allSatisfy(\.isFinite),
          width > max(0, insets.left) + max(0, insets.right) else {
      throw StorybookViewportRenderError.invalidSize
    }
  }

  fileprivate static func validate(pointSize: CGSize, scale: CGFloat) throws {
    guard scale.isFinite, scale > 0 else {
      throw StorybookViewportRenderError.invalidScale
    }
    guard pointSize.width.isFinite, pointSize.height.isFinite,
          pointSize.width > 0, pointSize.height > 0 else {
      throw StorybookViewportRenderError.invalidSize
    }
    let pixels = Double(ceil(pointSize.width * scale)) * Double(ceil(pointSize.height * scale))
    guard pixels <= Double(maximumPixelCount) else {
      throw StorybookViewportRenderError.tooLarge(maximumPixelCount: maximumPixelCount)
    }
  }

  fileprivate static func capture(
    view: NSView,
    descriptor: BookPageDescriptor,
    scale: CGFloat
  ) throws -> StorybookExportImage {
    let pointSize = view.bounds.size
    try validate(pointSize: pointSize, scale: scale)
    let pixelWidth = Int(ceil(pointSize.width * scale))
    let pixelHeight = Int(ceil(pointSize.height * scale))
    guard let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: pixelWidth,
      pixelsHigh: pixelHeight,
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0
    ) else {
      throw StorybookViewportRenderError.captureFailed
    }
    bitmap.size = pointSize
    view.layoutSubtreeIfNeeded()
    view.cacheDisplay(in: view.bounds, to: bitmap)
    let image = NSImage(size: pointSize)
    image.addRepresentation(bitmap)
    return .init(
      image: image,
      descriptor: descriptor,
      pointSize: pointSize,
      pixelSize: .init(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
    )
  }
}

/// Captures a native view in an existing window-backed host.
///
/// Height comes from Auto Layout, intrinsic content size, or the factory's frame,
/// in that order. Scroll views keep their visible viewport instead of expanding
/// their document. Views with no finite height must set one in their factory.
@available(macOS 14.0, *)
@MainActor
public enum StorybookNSViewRenderer {

  public static func render(
    _ preview: StorybookNSView,
    width: CGFloat,
    scale: CGFloat = NSScreen.main?.backingScaleFactor ?? 1,
    appearance: StorybookViewportAppearance? = nil,
    safeAreaInsets: NSEdgeInsets = .init(),
    in host: NSView
  ) throws -> StorybookExportImage {
    try StorybookViewportRenderer.validate(width: width, scale: scale, insets: safeAreaInsets)
    guard host.window != nil else {
      throw StorybookNSViewRenderError.notAttachedToWindow
    }
    let view = preview.makeView()
    guard view.superview == nil, view.window == nil else {
      throw StorybookNSViewRenderError.previewAlreadyAttached
    }
    let content = StorybookCaptureView()
    content.appearance = appearance?.appKitAppearance
    host.addSubview(content)
    content.addSubview(view)
    defer { content.removeFromSuperview() }

    let left = max(0, safeAreaInsets.left)
    let right = max(0, safeAreaInsets.right)
    let top = max(0, safeAreaInsets.top)
    let bottom = max(0, safeAreaInsets.bottom)
    let contentWidth = width - left - right
    let originalHeight = view.frame.height
    let originalMask = view.translatesAutoresizingMaskIntoConstraints
    // Width anchors measure the alignment rectangle, not the view's frame.
    // Subtract native alignment insets so controls such as NSTextField retain
    // their complete frame, including the padding outside the alignment rect.
    let alignmentWidth = view.alignmentRect(
      forFrame: .init(x: 0, y: 0, width: contentWidth, height: originalHeight)
    ).width
    guard alignmentWidth.isFinite, alignmentWidth >= 0 else {
      throw StorybookViewportRenderError.invalidSize
    }
    view.translatesAutoresizingMaskIntoConstraints = false
    let widthConstraint = view.widthAnchor.constraint(equalToConstant: alignmentWidth)
    widthConstraint.isActive = true
    defer {
      widthConstraint.isActive = false
      view.translatesAutoresizingMaskIntoConstraints = originalMask
      view.removeFromSuperview()
    }
    view.frame.size.width = contentWidth
    view.layoutSubtreeIfNeeded()
    let height = [view.fittingSize.height, view.intrinsicContentSize.height, originalHeight]
      .first { $0.isFinite && $0 > 0 } ?? 0
    let pointSize = CGSize(width: width, height: height + top + bottom)
    guard height > 0 else { throw StorybookViewportRenderError.invalidSize }
    try StorybookViewportRenderer.validate(pointSize: pointSize, scale: scale)
    content.frame = .init(origin: .zero, size: pointSize)
    view.frame = .init(x: left, y: top, width: contentWidth, height: height)
    return try StorybookViewportRenderer.capture(view: content, descriptor: preview.descriptor, scale: scale)
  }
}

/// Native view hosting failures that cannot be resolved by changing image size.
@available(macOS 14.0, *)
public enum StorybookNSViewRenderError: Error, Equatable, LocalizedError {
  case notAttachedToWindow
  case previewAlreadyAttached

  public var errorDescription: String? {
    switch self {
    case .notAttachedToWindow:
      "The AppKit viewport must be attached to a window before rendering."
    case .previewAlreadyAttached:
      "The preview factory must return an NSView that is not already attached to a host."
    }
  }
}

/// Captures the content area of a controller's actual AppKit window.
///
/// A sheet should pass its own window. Window chrome and other windows are not
/// included, and the controller is not resized to fit its scrolling content.
@available(macOS 14.0, *)
@MainActor
public enum StorybookPresentedViewControllerRenderer {

  public static func render(
    _ preview: StorybookPresentedViewController,
    presentedViewController: NSViewController,
    in window: NSWindow,
    scale: CGFloat = NSScreen.main?.backingScaleFactor ?? 1
  ) throws -> StorybookExportImage {
    guard scale.isFinite, scale > 0 else {
      throw StorybookViewportRenderError.invalidScale
    }
    guard presentedViewController.isViewLoaded,
          presentedViewController.view.window === window,
          let contentView = window.contentView else {
      throw StorybookPresentedViewControllerRenderError.notPresentedInWindow
    }
    return try StorybookViewportRenderer.capture(view: contentView, descriptor: preview.descriptor, scale: scale)
  }
}

/// A controller has not yet reached the AppKit window selected for capture.
@available(macOS 14.0, *)
public enum StorybookPresentedViewControllerRenderError: Error, Equatable, LocalizedError {
  case notPresentedInWindow

  public var errorDescription: String? {
    "The preview controller is not presented in the capture window."
  }
}

/// Keeps exported padding coordinates consistent with SwiftUI's top-leading origin.
@MainActor
private final class StorybookCaptureView: NSView {
  override var isFlipped: Bool { true }
}
#endif
