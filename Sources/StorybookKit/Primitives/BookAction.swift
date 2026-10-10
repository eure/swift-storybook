//
// Copyright (c) 2020 Eureka, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#if canImport(UIKit)
import SwiftUI

public struct BookAction: BookView {

  @Environment(\.storybook_targetViewController) var targetViewController

  public let declarationIdentifier: DeclarationIdentifier
  
  public let action: @MainActor (UIViewController) -> Void

  public let title: String

  public init(
    title: String,
    action: @escaping @MainActor (UIViewController) -> Void
  ) {
    self.title = title
    self.action = action
    self.declarationIdentifier = .init()
  }

  public var body: some View {
    Button(title) {
      if let targetViewController {
        action(targetViewController)
      } else {
        
      }
    }
  }

}

#endif
