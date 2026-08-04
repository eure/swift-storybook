import StorybookKit
import SwiftUI
import UIKit

/// Hosts a SwiftUI viewport in the app's live window before exporting it. This
/// lets `onAppear`, `task`, and UIKit-backed representables begin their
/// lifecycle work before the full-height bitmap is captured.
struct StorybookSwiftUIExportHost: UIViewControllerRepresentable {

  let viewport: StorybookViewport
  let appearance: StorybookViewportAppearance
  let scale: CGFloat
  let safeAreaInsets: UIEdgeInsets
  let onImage: @MainActor (StorybookExportImage) -> Void
  let onFailure: @MainActor (Error) -> Void

  func makeCoordinator() -> Coordinator {
    .init(
      scale: scale,
      onImage: onImage,
      onFailure: onFailure
    )
  }

  func makeUIViewController(context: Context) -> StorybookViewportHost {
    let host = StorybookViewportHost(
      viewport: viewport,
      appearance: appearance,
      safeAreaInsets: safeAreaInsets
    )
    context.coordinator.attach(to: host)
    return host
  }

  func updateUIViewController(
    _ uiViewController: StorybookViewportHost,
    context: Context
  ) {
    context.coordinator.captureWhenAttached()
  }

  static func dismantleUIViewController(
    _ uiViewController: StorybookViewportHost,
    coordinator: Coordinator
  ) {
    coordinator.cancel()
  }

  @MainActor
  final class Coordinator {

    private let onFailure: (Error) -> Void
    private let onImage: (StorybookExportImage) -> Void
    private let scale: CGFloat
    private var attachmentAttempts = 0
    private var cancelled = false
    private var captureStarted = false
    private weak var host: StorybookViewportHost?

    init(
      scale: CGFloat,
      onImage: @escaping @MainActor (StorybookExportImage) -> Void,
      onFailure: @escaping @MainActor (Error) -> Void
    ) {
      self.scale = scale
      self.onImage = onImage
      self.onFailure = onFailure
    }

    func attach(to host: StorybookViewportHost) {
      self.host = host
    }

    func cancel() {
      cancelled = true
    }

    func captureWhenAttached() {
      guard captureStarted == false, cancelled == false else {
        return
      }
      guard let host, host.view.window != nil, host.view.bounds.width > 0 else {
        attachmentAttempts += 1
        guard attachmentAttempts <= 120 else {
          onFailure(CaptureError.missingWindow)
          return
        }
        DispatchQueue.main.async { [weak self] in
          self?.captureWhenAttached()
        }
        return
      }

      captureStarted = true
      // The first turn allows SwiftUI to run `onAppear` and start `task`; the
      // second waits for the resulting display transaction before drawing.
      DispatchQueue.main.async { [weak self, weak host] in
        DispatchQueue.main.async {
          self?.capture(in: host)
        }
      }
    }

    private func capture(in host: StorybookViewportHost?) {
      guard cancelled == false, let host else {
        return
      }

      do {
        let rendered = try host.render(
          width: host.view.bounds.width,
          scale: scale
        )
        onImage(rendered)
      } catch {
        onFailure(error)
      }
    }

    private enum CaptureError: LocalizedError {
      case missingWindow

      var errorDescription: String? {
        switch self {
        case .missingWindow:
          "The SwiftUI viewport export host is not attached to a window."
        }
      }
    }
  }
}
