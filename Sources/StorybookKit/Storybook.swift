import SwiftUI

@available(iOS 17.0, *)
public struct Storybook: View {

  private let launchRequest: StorybookLaunchRequest?

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

    if let launchRequest {
      StorybookDisplayRootView(
        bookStore: bookStore,
        launchRequest: launchRequest
      )
    } else {
      StorybookDisplayRootView(bookStore: bookStore)
    }
  }
}
