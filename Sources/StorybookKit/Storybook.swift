import SwiftUI

@available(iOS 17.0, *)
public struct Storybook: View  {
  
  public init() {
    
  }
  
  public var body: some View {
    StorybookDisplayRootView(
      bookStore: .init(
        book: .init(title: "Storybook") {
          
          if let nodes = Book.allBookPreviews() {
            Book(title: "#Preview macro") {
              nodes
            }
          }
          
        }
      )
    )
  }
}
