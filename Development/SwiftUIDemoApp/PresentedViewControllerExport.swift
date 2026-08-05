import StorybookKit
import SwiftUI
import UIKit

/// Presents a UIKit preview in the app's live window, then captures that
/// window at its normal device size. This is intentionally not a viewport: a
/// controller owns its presentation, safe areas, and lifecycle.
struct StorybookPresentedViewControllerExportHost: UIViewControllerRepresentable {

  let preview: StorybookPresentedViewController
  let appearance: StorybookViewportAppearance
  let scale: CGFloat
  let onImage: @MainActor (StorybookExportImage) -> Void
  let onFailure: @MainActor (Error) -> Void

  func makeCoordinator() -> Coordinator {
    .init(
      preview: preview,
      appearance: appearance,
      scale: scale,
      onImage: onImage,
      onFailure: onFailure
    )
  }

  func makeUIViewController(context: Context) -> UIViewController {
    let host = UIViewController()
    host.view.backgroundColor = .systemBackground
    host.overrideUserInterfaceStyle = appearance.userInterfaceStyle
    context.coordinator.attach(to: host)
    return host
  }

  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

  static func dismantleUIViewController(
    _ uiViewController: UIViewController,
    coordinator: Coordinator
  ) {
    coordinator.cancel(presentationHost: uiViewController)
  }

  @MainActor
  final class Coordinator {

    private let appearance: StorybookViewportAppearance
    private let onFailure: (Error) -> Void
    private let onImage: (StorybookExportImage) -> Void
    private let preview: StorybookPresentedViewController
    private let scale: CGFloat
    private weak var presentationHost: UIViewController?
    private var attachmentAttempts = 0
    private var cancelled = false
    private var started = false

    init(
      preview: StorybookPresentedViewController,
      appearance: StorybookViewportAppearance,
      scale: CGFloat,
      onImage: @escaping @MainActor (StorybookExportImage) -> Void,
      onFailure: @escaping @MainActor (Error) -> Void
    ) {
      self.preview = preview
      self.appearance = appearance
      self.scale = scale
      self.onImage = onImage
      self.onFailure = onFailure
    }

    func attach(to presentationHost: UIViewController) {
      self.presentationHost = presentationHost
      beginPresentationWhenAttached()
    }

    func cancel(presentationHost: UIViewController) {
      cancelled = true
      presentationHost.dismiss(animated: false)
    }

    private func beginPresentationWhenAttached() {
      guard started == false, cancelled == false else {
        return
      }
      guard let presentationHost,
            presentationHost.isViewLoaded,
            presentationHost.view.window != nil
      else {
        attachmentAttempts += 1
        guard attachmentAttempts <= 120 else {
          onFailure(CaptureError.missingWindow)
          return
        }
        DispatchQueue.main.async { [weak self] in
          self?.beginPresentationWhenAttached()
        }
        return
      }

      started = true
      let presentedViewController = preview.makeViewController()
      presentedViewController.overrideUserInterfaceStyle = appearance.userInterfaceStyle
      presentationHost.present(presentedViewController, animated: false) { [weak self, preview, presentedViewController] in
        // UIKit's presentation completion precedes a final display transaction.
        // Two turns of the main queue make the exported PNG deterministic without
        // guessing a time-based delay.
        DispatchQueue.main.async {
          DispatchQueue.main.async {
            self?.capture(
              preview: preview,
              presentedViewController: presentedViewController
            )
          }
        }
      }
    }

    private func capture(
      preview: StorybookPresentedViewController,
      presentedViewController: UIViewController
    ) {
      guard cancelled == false else {
        return
      }
      guard let window = presentationHost?.view.window else {
        onFailure(CaptureError.missingWindow)
        return
      }
      window.endEditing(true)

      do {
        let image = try StorybookPresentedViewControllerRenderer.render(
          preview,
          presentedViewController: presentedViewController,
          in: window,
          scale: scale
        )
        onImage(image)
      } catch {
        onFailure(error)
      }
    }

    private enum CaptureError: LocalizedError {
      case missingWindow

      var errorDescription: String? {
        switch self {
        case .missingWindow:
          return "The controller export host is not attached to a window."
        }
      }
    }
  }
}
