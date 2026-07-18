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

import Foundation
import SwiftUI

public struct DeclarationIdentifier: Hashable, Codable, Sendable {

  public let index: Int

  nonisolated init() {
    index = issueUniqueNumber()
  }

  public init(raw index: Int) {
    self.index = index
  }
}

private let _lock = NSLock()
private nonisolated(unsafe) var _counter: Int = 0
private func issueUniqueNumber() -> Int {
  _lock.lock()
  defer {
    _lock.unlock()
  }
  _counter += 1
  return _counter
}

/// A component that displays a disclosure view.
public struct BookPage: BookView, Identifiable, Sendable {

  public nonisolated var id: DeclarationIdentifier {
    declarationIdentifier
  }

  public let usesScrollView: Bool
  public let title: String
  public let destination: () -> AnyView
  /// The name and source location used to select this page programmatically.
  public let descriptor: BookPageDescriptor
  public nonisolated let declarationIdentifier: DeclarationIdentifier

  public init<Destination: View>(
    _ fileID: any StringProtocol = #fileID,
    _ line: any FixedWidthInteger = #line,
    title: String,
    usesScrollView: Bool = true,
    @ViewBuilder destination: @MainActor @escaping () -> Destination
  ) {
    self.title = title
    self.usesScrollView = usesScrollView
    self.destination = { AnyView(destination()) }
    self.descriptor = .init(
      name: title,
      fileID: String(fileID),
      line: String(describing: line)
    )
    self.declarationIdentifier = .init()
  }

  public var body: some View {

    NavigationLink {
      BookPageDestination(page: self)
    } label: {
      LinkLabel(
        title: descriptor.name,
        fileID: descriptor.fileID,
        line: descriptor.line
      )
      //        .contextMenu(menuItems: {
      //          Text(title)
      //        }) {
      //          destination
      //        }
    }

  }
}

/// Renders one page consistently for catalog links and programmable navigation.
struct BookPageDestination: View {

  @Environment(\.bookContext) private var context

  let page: BookPage

  var body: some View {
    Group {
      if page.usesScrollView {
        ScrollView {
          Display(content: page.destination)
        }
      } else {
        Display(content: page.destination)
      }
    }
    .accessibilityIdentifier(page.descriptor.accessibilityIdentifier)
    .listStyle(.plain)
    .navigationTitle(page.title)
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      context?.onOpen(pageID: page.id)
    }
  }
}

private struct Display: View {

  @State private var loaded: AnyView?
  private let content: () -> AnyView

  init(content: @escaping () -> AnyView) {
    self.content = content
  }

  var body: some View {
    if let loaded {
      loaded
    } else {
      Color.clear
        .onAppear(perform: {
          loaded = content()
        })
    }
  }

}

private struct LinkLabel: View {

  let title: String
  let fileID: String
  let line: String

  var body: some View {
    HStack {
      Image.init(systemName: "doc.fill")
        .foregroundStyle(.orange)
      VStack(alignment: .leading) {
        Text(title)
        Text("\(fileID):\(line)")
          .font(.caption.monospacedDigit())
          .opacity(0.8)
      }
    }
  }
}
