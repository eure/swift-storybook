import StorybookKit
import SwiftUI
import UIKit

struct StorybookUIViewExportHost: UIViewRepresentable {

  let preview: StorybookUIView
  let appearance: StorybookViewportAppearance
  let scale: CGFloat
  let safeAreaInsets: UIEdgeInsets
  let onImage: @MainActor (StorybookExportImage) -> Void
  let onFailure: @MainActor (Error) -> Void

  func makeCoordinator() -> Coordinator {
    .init(
      preview: preview,
      appearance: appearance,
      scale: scale,
      safeAreaInsets: safeAreaInsets,
      onImage: onImage,
      onFailure: onFailure
    )
  }

  func makeUIView(context: Context) -> UIView {
    let host = UIView()
    host.backgroundColor = .systemBackground
    host.overrideUserInterfaceStyle = appearance.userInterfaceStyle
    context.coordinator.attach(to: host)
    return host
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    context.coordinator.captureWhenAttached()
  }

  static func dismantleUIView(
    _ uiView: UIView,
    coordinator: Coordinator
  ) {
    coordinator.cancel()
  }

  @MainActor
  final class Coordinator {

    private let appearance: StorybookViewportAppearance
    private let onFailure: (Error) -> Void
    private let onImage: (StorybookExportImage) -> Void
    private let preview: StorybookUIView
    private let scale: CGFloat
    private let safeAreaInsets: UIEdgeInsets
    private var attachmentAttempts = 0
    private var cancelled = false
    private var captureStarted = false
    private weak var host: UIView?

    init(
      preview: StorybookUIView,
      appearance: StorybookViewportAppearance,
      scale: CGFloat,
      safeAreaInsets: UIEdgeInsets,
      onImage: @escaping @MainActor (StorybookExportImage) -> Void,
      onFailure: @escaping @MainActor (Error) -> Void
    ) {
      self.preview = preview
      self.appearance = appearance
      self.scale = scale
      self.safeAreaInsets = safeAreaInsets
      self.onImage = onImage
      self.onFailure = onFailure
    }

    func attach(to host: UIView) {
      self.host = host
    }

    func cancel() {
      cancelled = true
    }

    func captureWhenAttached() {
      guard captureStarted == false, cancelled == false else {
        return
      }
      guard let host, host.window != nil, host.bounds.width > 0 else {
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
      DispatchQueue.main.async { [weak self] in
        DispatchQueue.main.async {
          self?.capture(in: host)
        }
      }
    }

    private func capture(in host: UIView) {
      guard cancelled == false else {
        return
      }

      do {
        let rendered = try StorybookUIViewRenderer.render(
          preview,
          width: host.bounds.width,
          scale: scale,
          appearance: appearance,
          safeAreaInsets: safeAreaInsets,
          in: host
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
          "The UIKit viewport export host is not attached to a window."
        }
      }
    }
  }
}
