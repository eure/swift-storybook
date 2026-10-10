#if os(macOS)
import AppKit
import SwiftUI

/// Displays an AppKit view together with optional controls and its source location.
///
/// Content whose height depends on its width is measured after the current
/// SwiftUI update in the host window. Capture it after native layout has settled.
public struct BookPreview: BookView {

  /// Collects SwiftUI controls alongside the AppKit view when the fixture is created.
  public struct Context {
    var controlView: AnyView?

    /// Adds controls that manipulate the previewed view or its model.
    public mutating func control<Content: View>(_ content: () -> Content) {
      controlView = AnyView(content())
    }
  }

  public let viewBlock: @MainActor (inout Context) -> NSView
  public let declarationIdentifier: DeclarationIdentifier

  private let fileID: String
  private let line: String
  private let title: String?
  private var minWidth: CGFloat?
  private var idealWidth: CGFloat?
  private var maxWidth: CGFloat?
  private var minHeight: CGFloat?
  private var idealHeight: CGFloat?
  private var maxHeight: CGFloat?

  @State private var controlView: AnyView?

  /// Creates a fixture whose AppKit view is instantiated when it enters the UI.
  public init(
    _ fileID: any StringProtocol = #fileID,
    _ line: any FixedWidthInteger = #line,
    title: String? = nil,
    viewBlock: @escaping @MainActor (inout Context) -> NSView
  ) {
    self.fileID = String(fileID)
    self.line = String(describing: line)
    self.title = title
    self.viewBlock = viewBlock
    self.declarationIdentifier = .init()
  }

  public var body: some View {
    VStack {
      if let title {
        Text(title).font(.headline)
      }
      _ViewHost(frame: .init(
        minWidth: minWidth, idealWidth: idealWidth, maxWidth: maxWidth,
        minHeight: minHeight, idealHeight: idealHeight, maxHeight: maxHeight
      )) {
        var context = Context()
        let view = viewBlock(&context)
        // Publish controls after representable creation finishes its view update.
        Task { controlView = context.controlView }
        return view
      }
      controlView
      Text(verbatim: "\(fileID):\(line)")
        .font(.caption.monospacedDigit())
      BookSpacer(height: 16)
    }
  }

  /// Sets fixed dimensions, in points, for the preview's native content.
  public func previewFrame(width: CGFloat?, height: CGFloat?) -> Self {
    previewFrame(idealWidth: width, idealHeight: height)
  }

  /// Constrains the content using SwiftUI's proposed size and AppKit's fitting size.
  public func previewFrame(
    minWidth: CGFloat? = nil,
    idealWidth: CGFloat? = nil,
    maxWidth: CGFloat? = nil,
    minHeight: CGFloat? = nil,
    idealHeight: CGFloat? = nil,
    maxHeight: CGFloat? = nil
  ) -> Self {
    modified {
      $0.minWidth = minWidth
      $0.idealWidth = idealWidth
      $0.maxWidth = maxWidth
      $0.minHeight = minHeight
      $0.idealHeight = idealHeight
      $0.maxHeight = maxHeight
    }
  }
}
#endif
