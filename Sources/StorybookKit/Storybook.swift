import SwiftUI

@available(iOS 17.0, *)
public struct Storybook: View  {

  private let deepLinkScheme: String?
  
  public init(deepLinkScheme: String? = StorybookDeepLink.defaultScheme) {
    self.deepLinkScheme = deepLinkScheme
  }
  
  public var body: some View {
    StorybookDisplayRootView(
      bookStore: .init(
        book: Book.init(title: "Contents") {
          
          if let nodes = Book.allBookPreviews() {
            Book(title: "#Preview") {
              nodes
            }
          }
          
        },
        deepLinkScheme: deepLinkScheme
      )
    )
  }
}
