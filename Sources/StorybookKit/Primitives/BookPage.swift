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
import ResultBuilderKit
#if canImport(UIKit)
import UIKit
#endif

public struct DeclarationIdentifier: Hashable, Codable, Sendable {

  enum Storage: Hashable, Codable {
    case index(Int)
    case location(fileID: String, line: Int)
  }

  let storage: Storage

  nonisolated init() {
    self.storage = .index(issueUniqueNumber())
  }

  public init(fileID: String, line: Int) {
    self.storage = .location(fileID: fileID, line: line)
  }

  public init(raw index: Int) {
    self.storage = .index(index)
  }

  public init?(stableID: String) {
    if stableID.hasPrefix("index:") {
      let value = stableID.dropFirst("index:".count)
      guard let index = Int(value) else {
        return nil
      }
      self.storage = .index(index)
      return
    }

    guard
      let separator = stableID.lastIndex(of: ":"),
      separator > stableID.startIndex,
      let line = Int(stableID[stableID.index(after: separator)...])
    else {
      return nil
    }

    self.storage = .location(
      fileID: String(stableID[..<separator]),
      line: line
    )
  }

  // For backward compatibility with History feature
  var index: Int {
    switch storage {
    case .index(let i):
      return i
    case .location(let fileID, let line):
      return Self.stableHash("\(fileID):\(line)")
    }
  }

  // Stable string representation for identification
  public var stableID: String {
    switch storage {
    case .index(let i):
      return "index:\(i)"
    case .location(let fileID, let line):
      return "\(fileID):\(line)"
    }
  }

  private static func stableHash(_ value: String) -> Int {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in value.utf8 {
      hash ^= UInt64(byte)
      hash &*= 1_099_511_628_211
    }
    return Int(hash % UInt64(Int.max))
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

  @Environment(\.bookContext) var context

  public nonisolated var id: DeclarationIdentifier {
    declarationIdentifier
  }

  public let usesScrollView: Bool
  public let title: String
  public let destination: () -> AnyView
  public nonisolated let declarationIdentifier: DeclarationIdentifier
  private let fileID: any StringProtocol
  private let line: any FixedWidthInteger  

  public init<Destination: View>(
    _ fileID: any StringProtocol = #fileID,
    _ line: any FixedWidthInteger = #line,
    title: String,
    usesScrollView: Bool = true,
    @ViewBuilder destination: @MainActor @escaping () -> Destination
  ) {
    self.fileID = fileID
    self.line = line
    self.title = title
    self.usesScrollView = usesScrollView
    self.destination = { AnyView(destination()) }
    self.declarationIdentifier = .init(fileID: String(fileID), line: Int(line))
  }

  public var body: some View {

    NavigationLink {
      BookPageDestination(page: self)
    } label: {
      LinkLabel(page: self, title: title, fileID: fileID, line: line)
//        .contextMenu(menuItems: {
//          Text(title)
//        }) {
//          destination
//        }
    }
   
  }
}

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
    .listStyle(.plain)
    .navigationTitle(page.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        DeepLinkCopyButton(pageID: page.id)
      }
    }
    .onAppear(perform: {
      context?.onOpen(pageID: page.id)
    })
  }
}

private struct Display: View {
  
  @State var loaded: AnyView?
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

  @Environment(\.bookContext) var bookContext

  let page: BookPage
  let title: any StringProtocol
  let fileID: any StringProtocol
  let line: any FixedWidthInteger

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
      Spacer()
      if let store = bookContext {
        Button {
          store.togglePin(node: .page(page))
        } label: {
          Image(systemName: store.isPinned(node: .page(page)) ? "pin.fill" : "pin")
            .foregroundStyle(.orange)
        }
        .buttonStyle(.plain)
      }
    }
    .contextMenu {
      DeepLinkCopyButton(pageID: page.id, title: "Copy Deep Link")
    }
  }
}

private struct DeepLinkCopyButton: View {

  @Environment(\.bookContext) private var bookContext

  let pageID: DeclarationIdentifier
  var title: String?

  var body: some View {
    if let url = bookContext?.deepLinkURL(for: pageID) {
      Button {
        StorybookClipboard.copy(url)
      } label: {
        if let title {
          Label(title, systemImage: "link")
        } else {
          Image(systemName: "link")
        }
      }
    }
  }
}

private enum StorybookClipboard {

  static func copy(_ url: URL) {
    #if canImport(UIKit)
    UIPasteboard.general.url = url
    #endif
  }
}
