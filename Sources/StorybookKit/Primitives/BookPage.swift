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
public struct BookPage: BookView, Identifiable {

  @Environment(\.bookContext) var context

  public nonisolated var id: DeclarationIdentifier {
    declarationIdentifier
  }

  public let usesScrollView: Bool
  public let title: String
  public let destination: AnyView
  public nonisolated let declarationIdentifier: DeclarationIdentifier
  private let fileID: any StringProtocol
  private let line: any FixedWidthInteger  

  public init<Destination: View>(
    _ fileID: any StringProtocol = #fileID,
    _ line: any FixedWidthInteger = #line,
    title: String,
    usesScrollView: Bool = true,
    @ViewBuilder destination: @MainActor () -> Destination
  ) {
    self.fileID = fileID
    self.line = line
    self.title = title
    self.usesScrollView = usesScrollView
    self.destination = AnyView(destination())
    self.declarationIdentifier = .init()
  }

  public var body: some View {

    NavigationLink {
      Group {
        if usesScrollView {
          ScrollView {
            destination
          }
        } else {
          destination
        }
      }
      .listStyle(.plain)
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear(perform: {
        context?.onOpen(pageID: id)
      })
    } label: {
      LinkLabel(title: title, fileID: fileID, line: line)
        .contextMenu(menuItems: {
          Text(title)
        }) { 
          destination
        }
    }
   
  }
}

private struct LinkLabel: View {
  
  let title: any StringProtocol
  let fileID: any StringProtocol
  let line: any FixedWidthInteger

  var body: some View {
    HStack {
      Image.init(systemName: "doc")
      VStack(alignment: .leading) {
        Text(title)
        Text("\(fileID):\(line)")
          .font(.caption.monospacedDigit())
          .opacity(0.8)
      }
    }
  }
}
