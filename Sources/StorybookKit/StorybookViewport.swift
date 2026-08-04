import SwiftUI
import UIKit

@available(iOS 17.0, *)
public struct StorybookViewport: View {

  public let descriptor: BookPageDescriptor

  private let destination: @MainActor () -> AnyView

  @MainActor
  public init(
    bookStore: BookStore,
    selector: BookPageSelector
  ) throws {
    try self.init(page: bookStore.resolve(selector))
  }

  @MainActor
  public init(page: BookPage) throws {
    guard case .viewport(let destination) = page.viewPortPreview() else {
      throw StorybookPreviewExportError.requiresPresentedViewController
    }
    self.init(descriptor: page.descriptor, destination: destination)
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

/// The raw Storybook content selected for an image export.
///
/// SwiftUI and `UIView` previews are fitted as a viewport. A
/// `UIViewController` preview is instead presented in a real window so its
/// UIKit presentation and lifecycle are preserved.
@available(iOS 17.0, *)
public enum StorybookPreviewExport {
  case viewport(StorybookViewport)
  case uiView(StorybookUIView)
  case presentedViewController(StorybookPresentedViewController)

  @MainActor
  public init(
    bookStore: BookStore,
    selector: BookPageSelector
  ) throws {
    let page = try bookStore.resolve(selector)
    switch page.viewPortPreview() {
    case .viewport(let destination):
      self = .viewport(
        StorybookViewport(
          descriptor: page.descriptor,
          destination: destination
        )
      )
    case .uiView(let makeView):
      self = .uiView(
        .init(
          descriptor: page.descriptor,
          makeView: makeView
        )
      )
    case .presentedViewController(let makeViewController):
      self = .presentedViewController(
        .init(
          descriptor: page.descriptor,
          makeViewController: makeViewController
        )
      )
    case .unsupported(let reason):
      throw StorybookPreviewExportError.unsupportedPreview(reason)
    }
  }
}

@available(iOS 17.0, *)
public struct StorybookUIView {

  public let descriptor: BookPageDescriptor
  private let factory: @MainActor () -> UIView

  fileprivate init(
    descriptor: BookPageDescriptor,
    makeView: @escaping @MainActor () -> UIView
  ) {
    self.descriptor = descriptor
    self.factory = makeView
  }

  @MainActor
  public func makeView() -> UIView {
    factory()
  }
}

/// A controller preview that must be captured as an actual UIKit presentation.
@available(iOS 17.0, *)
public struct StorybookPresentedViewController {

  public let descriptor: BookPageDescriptor
  private let factory: @MainActor () -> UIViewController

  fileprivate init(
    descriptor: BookPageDescriptor,
    makeViewController: @escaping @MainActor () -> UIViewController
  ) {
    self.descriptor = descriptor
    self.factory = makeViewController
  }

  @MainActor
  public func makeViewController() -> UIViewController {
    factory()
  }
}

@available(iOS 17.0, *)
public enum StorybookPreviewExportError: Error, Equatable, LocalizedError {
  case requiresPresentedViewController
  case unsupportedPreview(String)

  public var errorDescription: String? {
    switch self {
    case .requiresPresentedViewController:
      return "This preview is a UIViewController and must be exported as a presented controller."
    case .unsupportedPreview(let reason):
      return reason
    }
  }
}

@available(iOS 17.0, *)
public struct StorybookExportImage {

  public let image: UIImage
  public let descriptor: BookPageDescriptor
  public let pointSize: CGSize
  public let pixelSize: CGSize
}

/// The interface appearance used while rendering a Storybook viewport.
@available(iOS 17.0, *)
public enum StorybookViewportAppearance: String, CaseIterable, Codable, Sendable {
  case light
  case dark

  fileprivate var colorScheme: ColorScheme {
    switch self {
    case .light:
      .light
    case .dark:
      .dark
    }
  }

  public var userInterfaceStyle: UIUserInterfaceStyle {
    switch self {
    case .light:
      .light
    case .dark:
      .dark
    }
  }
}

@available(iOS 17.0, *)
public enum StorybookViewportRenderError: Error, Equatable, LocalizedError {
  case invalidWidth
  case invalidScale
  case invalidSize
  case tooLarge(maximumPixelCount: Int)

  public var errorDescription: String? {
    switch self {
    case .invalidWidth:
      return "Viewport width must be finite and greater than zero."
    case .invalidScale:
      return "Viewport scale must be finite and greater than zero."
    case .invalidSize:
      return "Viewport content did not produce a finite, nonzero size."
    case .tooLarge(let maximumPixelCount):
      return "Viewport image exceeds the maximum of \(maximumPixelCount) pixels."
    }
  }
}

@available(iOS 17.0, *)
@MainActor
public enum StorybookViewportRenderer {

  public static let maximumPixelCount = 32_000_000

  public static func render(
    _ viewport: StorybookViewport,
    width: CGFloat,
    scale: CGFloat = UIScreen.main.scale,
    appearance: StorybookViewportAppearance? = nil,
    safeAreaInsets: UIEdgeInsets = .zero
  ) throws -> StorybookExportImage {
    guard width.isFinite, width > 0 else {
      throw StorybookViewportRenderError.invalidWidth
    }
    guard scale.isFinite, scale > 0 else {
      throw StorybookViewportRenderError.invalidScale
    }

    let safeAreaTop = max(0, safeAreaInsets.top)
    let safeAreaBottom = max(0, safeAreaInsets.bottom)
    let content = AnyView(
      viewport
        .padding(.top, safeAreaTop)
        .padding(.bottom, safeAreaBottom)
    )
    let rootView: AnyView
    if let appearance {
      rootView = AnyView(
        content.environment(\.colorScheme, appearance.colorScheme)
      )
    } else {
      rootView = content
    }
    let viewController = UIHostingController(rootView: rootView)
    viewController.safeAreaRegions = []
    viewController.overrideUserInterfaceStyle = appearance?.userInterfaceStyle ?? .unspecified
    viewController.loadViewIfNeeded()

    let fittedSize = viewController.sizeThatFits(
      in: .init(width: width, height: .greatestFiniteMagnitude)
    )
    let pointSize = CGSize(width: width, height: fittedSize.height)
    guard pointSize.width.isFinite,
          pointSize.height.isFinite,
          pointSize.width > 0,
          pointSize.height > 0
    else {
      throw StorybookViewportRenderError.invalidSize
    }

    let pixelCount = Double(pointSize.width * scale) * Double(pointSize.height * scale)
    guard pixelCount <= Double(maximumPixelCount) else {
      throw StorybookViewportRenderError.tooLarge(
        maximumPixelCount: maximumPixelCount
      )
    }

    viewController.view.bounds = .init(origin: .zero, size: pointSize)
    viewController.view.setNeedsLayout()
    viewController.view.layoutIfNeeded()

    let format = UIGraphicsImageRendererFormat()
    format.scale = scale
    format.opaque = false
    let image = UIGraphicsImageRenderer(size: pointSize, format: format).image { context in
      if viewController.view.drawHierarchy(
        in: .init(origin: .zero, size: pointSize),
        afterScreenUpdates: true
      ) == false {
        viewController.view.layer.render(in: context.cgContext)
      }
    }

    return .init(
      image: image,
      descriptor: viewport.descriptor,
      pointSize: pointSize,
      pixelSize: .init(
        width: pointSize.width * scale,
        height: pointSize.height * scale
      )
    )
  }
}

@available(iOS 17.0, *)
@MainActor
public enum StorybookUIViewRenderer {

  public static func render(
    _ preview: StorybookUIView,
    width: CGFloat,
    scale: CGFloat = UIScreen.main.scale,
    appearance: StorybookViewportAppearance? = nil,
    safeAreaInsets: UIEdgeInsets = .zero,
    in host: UIView
  ) throws -> StorybookExportImage {
    guard width.isFinite, width > 0 else {
      throw StorybookViewportRenderError.invalidWidth
    }
    guard scale.isFinite, scale > 0 else {
      throw StorybookViewportRenderError.invalidScale
    }
    guard host.window != nil else {
      throw StorybookUIViewRenderError.notAttachedToWindow
    }

    let content = UIView(frame: .init(x: 0, y: 0, width: width, height: host.bounds.height))
    content.backgroundColor = .systemBackground
    content.overrideUserInterfaceStyle = appearance?.userInterfaceStyle ?? .unspecified
    host.addSubview(content)
    defer {
      content.removeFromSuperview()
    }

    let view = preview.makeView()
    view.overrideUserInterfaceStyle = appearance?.userInterfaceStyle ?? .unspecified
    content.addSubview(view)

    let fittedSize = try fittedSize(of: view, in: content, width: width)
    let safeAreaTop = max(0, safeAreaInsets.top)
    let safeAreaBottom = max(0, safeAreaInsets.bottom)
    let pointSize = CGSize(
      width: width,
      height: fittedSize.height + safeAreaTop + safeAreaBottom
    )
    content.bounds.size = pointSize
    content.frame.size = pointSize
    view.frame.origin.y = safeAreaTop
    view.setNeedsLayout()
    view.layoutIfNeeded()
    content.setNeedsLayout()
    content.layoutIfNeeded()

    let pixelCount = Double(pointSize.width * scale) * Double(pointSize.height * scale)
    guard pixelCount <= Double(StorybookViewportRenderer.maximumPixelCount) else {
      throw StorybookViewportRenderError.tooLarge(
        maximumPixelCount: StorybookViewportRenderer.maximumPixelCount
      )
    }

    let format = UIGraphicsImageRendererFormat()
    format.scale = scale
    format.opaque = false
    let image = UIGraphicsImageRenderer(size: pointSize, format: format).image { context in
      if content.drawHierarchy(
        in: .init(origin: .zero, size: pointSize),
        afterScreenUpdates: true
      ) == false {
        content.layer.render(in: context.cgContext)
      }
    }

    return .init(
      image: image,
      descriptor: preview.descriptor,
      pointSize: pointSize,
      pixelSize: .init(
        width: pointSize.width * scale,
        height: pointSize.height * scale
      )
    )
  }

  private static func fittedSize(
    of view: UIView,
    in content: UIView,
    width: CGFloat
  ) throws -> CGSize {
    let proposedSize = CGSize(width: width, height: .greatestFiniteMagnitude)
    let fittedSize = view.sizeThatFits(proposedSize)
    let intrinsicSize = view.intrinsicContentSize
    let viewSize = CGSize(
      width: validDimension(fittedSize.width) ? fittedSize.width : intrinsicSize.width,
      height: validDimension(fittedSize.height) ? fittedSize.height : intrinsicSize.height
    )
    view.frame = .init(
      origin: .zero,
      size: .init(
        width: width,
        height: max(
          validDimension(viewSize.height) ? viewSize.height : 0,
          content.bounds.height
        )
      )
    )
    view.setNeedsLayout()
    view.layoutIfNeeded()

    let scrollViews = scrollViews(in: view)
    guard scrollViews.isEmpty == false else {
      guard validDimension(viewSize.width), validDimension(viewSize.height) else {
        throw StorybookViewportRenderError.invalidSize
      }

      view.frame = .init(
        x: (width - viewSize.width) / 2,
        y: 0,
        width: viewSize.width,
        height: viewSize.height
      )
      return .init(width: width, height: viewSize.height)
    }

    var height = validDimension(viewSize.height) ? viewSize.height : 0
    for scrollView in scrollViews {
      let scrollHeight = scrollView.contentSize.height
      guard scrollHeight.isFinite, scrollHeight >= 0 else {
        throw StorybookViewportRenderError.invalidSize
      }
      scrollView.frame.size.height = scrollHeight
      if scrollView === view {
        height = max(height, scrollHeight)
        continue
      }
      expandAncestors(of: scrollView, through: view)
      height = max(
        height,
        scrollView.convert(scrollView.bounds, to: view).maxY
      )
    }
    guard validDimension(height) else {
      throw StorybookViewportRenderError.invalidSize
    }
    view.frame = .init(
      origin: .zero,
      size: .init(width: width, height: height)
    )
    return .init(width: width, height: height)
  }

  private static func scrollViews(in view: UIView) -> [UIScrollView] {
    var result: [UIScrollView] = []
    func collect(from view: UIView) {
      if let scrollView = view as? UIScrollView {
        result.append(scrollView)
      }
      view.subviews.forEach(collect)
    }
    collect(from: view)
    return result
  }

  private static func expandAncestors(
    of scrollView: UIScrollView,
    through rootView: UIView
  ) {
    var view: UIView = scrollView
    while let superview = view.superview {
      superview.frame.size.height = max(
        superview.frame.height,
        view.frame.maxY
      )
      if superview === rootView {
        return
      }
      view = superview
    }
  }

  private static func validDimension(_ value: CGFloat) -> Bool {
    value.isFinite && value > 0 && value != UIView.noIntrinsicMetric
  }
}

@available(iOS 17.0, *)
public enum StorybookUIViewRenderError: Error, Equatable, LocalizedError {
  case notAttachedToWindow

  public var errorDescription: String? {
    switch self {
    case .notAttachedToWindow:
      "The UIKit viewport must be attached to a window before rendering."
    }
  }
}

/// Captures a controller after it has been presented in a live UIKit window.
/// The output always has the window's normal bounds; it does not resize to the
/// controller's content or scroll extent.
@available(iOS 17.0, *)
@MainActor
public enum StorybookPresentedViewControllerRenderer {

  public static func render(
    _ preview: StorybookPresentedViewController,
    presentedViewController: UIViewController,
    in window: UIWindow,
    scale: CGFloat = UIScreen.main.scale
  ) throws -> StorybookExportImage {
    guard scale.isFinite, scale > 0 else {
      throw StorybookViewportRenderError.invalidScale
    }
    guard presentedViewController.viewIfLoaded?.window === window else {
      throw StorybookPresentedViewControllerRenderError.notPresentedInWindow
    }

    let pointSize = window.bounds.size
    guard pointSize.width.isFinite,
          pointSize.height.isFinite,
          pointSize.width > 0,
          pointSize.height > 0
    else {
      throw StorybookViewportRenderError.invalidSize
    }

    let pixelCount = Double(pointSize.width * scale) * Double(pointSize.height * scale)
    guard pixelCount <= Double(StorybookViewportRenderer.maximumPixelCount) else {
      throw StorybookViewportRenderError.tooLarge(
        maximumPixelCount: StorybookViewportRenderer.maximumPixelCount
      )
    }

    window.setNeedsLayout()
    window.layoutIfNeeded()

    let format = UIGraphicsImageRendererFormat()
    format.scale = scale
    format.opaque = false
    let image = UIGraphicsImageRenderer(size: pointSize, format: format).image { context in
      if window.drawHierarchy(
        in: .init(origin: .zero, size: pointSize),
        afterScreenUpdates: true
      ) == false {
        window.layer.render(in: context.cgContext)
      }
    }

    return .init(
      image: image,
      descriptor: preview.descriptor,
      pointSize: pointSize,
      pixelSize: .init(
        width: pointSize.width * scale,
        height: pointSize.height * scale
      )
    )
  }
}

@available(iOS 17.0, *)
public enum StorybookPresentedViewControllerRenderError: Error, Equatable, LocalizedError {
  case notPresentedInWindow

  public var errorDescription: String? {
    switch self {
    case .notPresentedInWindow:
      return "The preview controller is not presented in the capture window."
    }
  }
}
