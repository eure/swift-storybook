#if canImport(UIKit)
import SwiftUI

struct _ViewControllerHost<ContentViewController: UIViewController>:
  UIViewControllerRepresentable
{

  private let instantiate: @MainActor () -> ContentViewController
  private let _update:
    @MainActor (_ uiViewController: ContentViewController, _ context: Context) -> Void

  init(
    instantiate: @escaping @MainActor () -> ContentViewController,
    update: @escaping @MainActor (_ uiViewController: ContentViewController, _ context: Context) ->
      Void = { _, _ in }
  ) {
    self.instantiate = instantiate
    self._update = update
  }

  func makeUIViewController(context: Context) -> ContentViewController {
    let instantiated = instantiate()
    return instantiated
  }

  func updateUIViewController(_ uiViewController: ContentViewController, context: Context) {
    _update(uiViewController, context)
  }

}

#endif
