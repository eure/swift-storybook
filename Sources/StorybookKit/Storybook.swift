import SwiftUI

@available(iOS 17.0, *)
public struct Storybook: View {

  private let launchRequest: StorybookLaunchRequest?
  private var appearanceConfiguration = StorybookAppearanceConfiguration()

  /// Creates a Storybook that opens its catalog.
  public init() {
    self.launchRequest = nil
  }

  /// Creates a Storybook that immediately opens an exactly matched preview.
  public init(initialPage: BookPageSelector) {
    self.launchRequest = .page(initialPage)
  }

  /// Creates a Storybook for a parsed programmable launch request.
  public init(launchRequest: StorybookLaunchRequest) {
    self.launchRequest = launchRequest
  }

  public var body: some View {
    let bookStore = BookStore(
      book: Book.init(title: "Contents") {
        if let nodes = Book.allBookPreviews() {
          nodes
        }
      }
    )

    let rootView =
      if let launchRequest {
        StorybookDisplayRootView(
          bookStore: bookStore,
          launchRequest: launchRequest
        )
      } else {
        StorybookDisplayRootView(bookStore: bookStore)
      }

    rootView.appearance(
      appearanceConfiguration.initialAppearance,
      onChange: appearanceConfiguration.onChange
    )
  }

  /// Sets the appearance each opened page starts with and observes the
  /// appearance of the visible page.
  ///
  /// See `StorybookDisplayRootView.appearance(_:onChange:)`.
  ///
  /// - Parameters:
  ///   - initialAppearance: The appearance each opened page starts with.
  ///   - onChange: Called with the visible page's appearance when a page
  ///     appears or its selection changes.
  public func appearance(
    _ initialAppearance: StorybookAppearance,
    onChange: (@MainActor (StorybookAppearance) -> Void)? = nil
  ) -> Self {
    var modified = self
    modified.appearanceConfiguration = .init(
      initialAppearance: initialAppearance,
      onChange: onChange
    )
    return modified
  }
}
