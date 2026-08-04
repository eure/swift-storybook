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
import StorybookKit
import SwiftUI

@main
struct SwiftUIDemoAppApp: App {

  private let storybookLaunchRequest: StorybookLaunchRequest?
  private let viewportExportPreparationFailure: String?
  private let viewportExportRequest: ViewportExportRequest

  init() {
    let arguments = ProcessInfo.processInfo.arguments
    storybookLaunchRequest = .init(arguments: arguments)
    let viewportExportRequest = ViewportExportRequest(arguments: arguments)
    self.viewportExportRequest = viewportExportRequest

    if case .request(let request) = viewportExportRequest {
      do {
        try StorybookViewportArtifact.prepare(exportID: request.exportID)
        viewportExportPreparationFailure = nil
      } catch {
        viewportExportPreparationFailure = error.localizedDescription
      }
    } else {
      viewportExportPreparationFailure = nil
    }
  }

  var body: some Scene {
    WindowGroup {
      switch viewportExportRequest {
      case .disabled:
        if let storybookLaunchRequest {
          Storybook(launchRequest: storybookLaunchRequest)
        } else {
          ContentView()
        }
      case .invalid(let message):
        StorybookViewportExportFailureView(message: message)
      case .request(let request):
        if let viewportExportPreparationFailure {
          StorybookViewportExportFailureView(
            message: viewportExportPreparationFailure
          )
        } else if case .page(let selector) = storybookLaunchRequest {
          StorybookViewportExportView(
            selector: selector,
            exportID: request.exportID,
            appearance: request.appearance
          )
        } else {
          StorybookViewportExportFailureView(
            message: "Viewport export requires an exact Storybook page selector."
          )
        }
      }
    }
  }
}
