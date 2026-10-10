#if os(macOS)
import AppKit
import SwiftUI

/// Embeds a native fixture without running AppKit layout inside SwiftUI sizing.
struct _ViewHost<ContentView: NSView>: NSViewRepresentable {
  private let frame: StorybookAppKitPreviewFrame
  private let instantiate: @MainActor () -> ContentView
  private let update: @MainActor (ContentView, Context) -> Void

  init(
    frame: StorybookAppKitPreviewFrame = .init(),
    instantiate: @escaping @MainActor () -> ContentView,
    update: @escaping @MainActor (ContentView, Context) -> Void = { _, _ in }
  ) {
    self.frame = frame
    self.instantiate = instantiate
    self.update = update
  }

  func makeNSView(context: Context) -> StorybookAppKitPreviewContainer<ContentView> {
    StorybookAppKitPreviewContainer(contentView: instantiate())
  }

  func updateNSView(_ nsView: StorybookAppKitPreviewContainer<ContentView>, context: Context) {
    update(nsView.contentView, context)
    nsView.invalidateMeasurements()
  }

  func sizeThatFits(
    _ proposal: ProposedViewSize,
    nsView: StorybookAppKitPreviewContainer<ContentView>,
    context: Context
  ) -> CGSize? {
    nsView.sizeThatFits(proposal, frame: frame)
  }
}

/// Native frame constraints requested by `BookPreview.previewFrame`.
struct StorybookAppKitPreviewFrame {
  var minWidth: CGFloat?
  var idealWidth: CGFloat?
  var maxWidth: CGFloat?
  var minHeight: CGFloat?
  var idealHeight: CGFloat?
  var maxHeight: CGFloat?
}

/// Owns the native view and measures width-dependent content after SwiftUI's
/// current update. Calling AppKit layout synchronously from `sizeThatFits` can
/// reenter SwiftUI through native controls that themselves contain SwiftUI.
final class StorybookAppKitPreviewContainer<ContentView: NSView>: NSView {
  let contentView: ContentView
  private let initialSize: CGSize
  private var isMeasuring = false
  private var generation = 0
  private var measuredHeights: [CGFloat: CGFloat] = [:]
  private var measurementOrder: [CGFloat] = []
  private var pendingWidths: Set<CGFloat> = []

  init(contentView: ContentView) {
    self.contentView = contentView
    let fittingSize = contentView.fittingSize
    initialSize = CGSize(
      width: max(contentView.frame.width, fittingSize.width),
      height: max(contentView.frame.height, fittingSize.height)
    )
    super.init(frame: CGRect(origin: .zero, size: initialSize))
    addSubview(contentView)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layout() {
    super.layout()
    if isMeasuring == false {
      contentView.frame = bounds
    }
  }

  override func viewWillMove(toWindow newWindow: NSWindow?) {
    if newWindow !== window { invalidateMeasurements() }
    super.viewWillMove(toWindow: newWindow)
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    invalidateIntrinsicContentSize()
  }

  func invalidateMeasurements() {
    generation += 1
    pendingWidths.removeAll()
    measuredHeights.removeAll()
    measurementOrder.removeAll()
    invalidateIntrinsicContentSize()
  }

  func sizeThatFits(_ proposal: ProposedViewSize, frame: StorybookAppKitPreviewFrame) -> CGSize? {
    let naturalWidth = positive(initialSize.width) ?? positive(proposal.width)
    guard let naturalWidth else { return nil }
    let width = bounded(
      positive(frame.idealWidth) ?? min(naturalWidth, positive(proposal.width) ?? naturalWidth),
      minimum: frame.minWidth, maximum: frame.maxWidth
    )
    let fixedHeight = positive(frame.idealHeight)
    if fixedHeight == nil, measuredHeights[width] == nil {
      scheduleMeasurement(width: width)
    }
    guard let naturalHeight = fixedHeight ?? measuredHeights[width] ?? positive(initialSize.height) else {
      return nil
    }
    let height = bounded(naturalHeight, minimum: frame.minHeight, maximum: frame.maxHeight)
    return CGSize(width: width, height: height)
  }

  private func scheduleMeasurement(width: CGFloat) {
    guard window != nil, pendingWidths.insert(width).inserted else { return }
    let requestedGeneration = generation
    DispatchQueue.main.async { [weak self] in
      guard let self, self.window != nil, self.generation == requestedGeneration else { return }
      self.pendingWidths.remove(width)
      let height = self.measureHeight(width: width)
      guard self.window != nil, self.generation == requestedGeneration else { return }
      // SwiftUI can ask about several widths during one layout pass. Keep a
      // small bounded cache, keyed by width, so one result cannot size another.
      self.measuredHeights[width] = height
      self.measurementOrder.append(width)
      if self.measurementOrder.count > 8 {
        self.measuredHeights.removeValue(forKey: self.measurementOrder.removeFirst())
      }
      self.invalidateIntrinsicContentSize()
      self.needsLayout = true
    }
  }

  private func measureHeight(width: CGFloat) -> CGFloat {
    isMeasuring = true
    let originalFrame = contentView.frame
    let originalMask = contentView.translatesAutoresizingMaskIntoConstraints
    // Start from the original natural width so Auto Layout observes a width
    // change even if the provisional frame already has the requested width.
    contentView.frame.size = initialSize
    contentView.translatesAutoresizingMaskIntoConstraints = false
    let alignmentWidth = contentView.alignmentRect(
      forFrame: CGRect(x: 0, y: 0, width: width, height: initialSize.height)
    ).width
    let constraint = contentView.widthAnchor.constraint(equalToConstant: max(0, alignmentWidth))
    constraint.isActive = true
    defer {
      constraint.isActive = false
      contentView.frame = originalFrame
      contentView.translatesAutoresizingMaskIntoConstraints = originalMask
      isMeasuring = false
    }
    contentView.needsLayout = true
    contentView.layoutSubtreeIfNeeded()
    return positive(contentView.fittingSize.height) ?? initialSize.height
  }

  private func positive(_ value: CGFloat?) -> CGFloat? {
    guard let value, value.isFinite, value > 0 else { return nil }
    return value
  }

  private func bounded(_ value: CGFloat, minimum: CGFloat?, maximum: CGFloat?) -> CGFloat {
    let lower = positive(minimum) ?? 0
    let upper = positive(maximum) ?? .infinity
    return min(max(value, lower), max(lower, upper))
  }
}

/// Embeds an AppKit controller with SwiftUI-managed creation and containment.
struct _ViewControllerHost<ContentViewController: NSViewController>:
  NSViewControllerRepresentable
{
  private let instantiate: @MainActor () -> ContentViewController
  private let update: @MainActor (ContentViewController, Context) -> Void

  init(
    instantiate: @escaping @MainActor () -> ContentViewController,
    update: @escaping @MainActor (ContentViewController, Context) -> Void = { _, _ in }
  ) {
    self.instantiate = instantiate
    self.update = update
  }

  func makeNSViewController(context: Context) -> ContentViewController {
    instantiate()
  }

  func updateNSViewController(_ nsViewController: ContentViewController, context: Context) {
    update(nsViewController, context)
  }
}

/// Owns the SwiftUI catalog and provides a native presentation target per window.
final class _ViewController<Content: View>: NSViewController {
  private let content: Content

  init(content: Content) {
    self.content = content
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    view = NSView()
    let hosting = NSHostingController(
      rootView: content.environment(\.storybook_targetViewController, self)
    )
    addChild(hosting)
    hosting.view.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(hosting.view)
    NSLayoutConstraint.activate([
      hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
      hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
  }
}
#endif
