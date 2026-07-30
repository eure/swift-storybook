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

/// A compact summary of a background operation.
///
/// The card keeps its content stateless so each operation state can be rendered
/// independently in Storybook. Callers that need interaction own the state and
/// update it from `onAction`.
struct DemoStatusCard: View {

  /// The operation state rendered by a status card.
  enum Status: Equatable {

    /// Work is in progress.
    ///
    /// Pass a value between `0` and `1` for determinate progress, or `nil` when
    /// the total amount of work is unknown.
    case syncing(progress: Double?)

    /// The operation completed successfully.
    case success

    /// The operation stopped because it needs attention.
    case failure

    fileprivate var title: LocalizedStringResource {
      switch self {
      case .syncing:
        return "Syncing components"
      case .success:
        return "Everything is up to date"
      case .failure:
        return "Sync needs attention"
      }
    }

    fileprivate var symbolName: String {
      switch self {
      case .syncing:
        return "arrow.triangle.2.circlepath"
      case .success:
        return "checkmark.circle.fill"
      case .failure:
        return "exclamationmark.triangle.fill"
      }
    }

    fileprivate var tint: Color {
      switch self {
      case .syncing:
        return .blue
      case .success:
        return .green
      case .failure:
        return .orange
      }
    }

    fileprivate var progress: Double? {
      guard case .syncing(let progress) = self else {
        return nil
      }
      return progress
    }

    fileprivate var isSyncing: Bool {
      guard case .syncing = self else {
        return false
      }
      return true
    }
  }

  let status: Status
  let message: LocalizedStringResource
  let actionTitle: LocalizedStringResource?
  let onAction: @MainActor () -> Void

  init(
    status: Status,
    message: LocalizedStringResource,
    actionTitle: LocalizedStringResource? = nil,
    onAction: @escaping @MainActor () -> Void = {}
  ) {
    self.status = status
    self.message = message
    self.actionTitle = actionTitle
    self.onAction = onAction
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      DemoStatusCardHeader(
        title: status.title,
        symbolName: status.symbolName,
        tint: status.tint
      )

      Text(message)
        .font(.body)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if status.isSyncing {
        DemoStatusCardProgress(progress: status.progress)
      }

      if let actionTitle {
        DemoStatusCardAction(
          title: actionTitle,
          tint: status.tint,
          action: onAction
        )
      }
    }
    .padding(24)
    .background(
      Color(uiColor: .secondarySystemGroupedBackground),
      in: RoundedRectangle(cornerRadius: 24, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(Color(uiColor: .separator).opacity(0.24))
    }
    .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
  }
}

/// Displays the semantic icon and title for a status card.
private struct DemoStatusCardHeader: View {

  let title: LocalizedStringResource
  let symbolName: String
  let tint: Color

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: symbolName)
        .font(.title2.weight(.semibold))
        .foregroundStyle(tint)
        .frame(width: 44, height: 44)
        .background(tint.opacity(0.12), in: Circle())
        .accessibilityHidden(true)

      Text(title)
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

/// Displays determinate or indeterminate progress without changing the card API.
private struct DemoStatusCardProgress: View {

  let progress: Double?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let progress {
        HStack {
          Text("Progress")
          Spacer()
          Text(progress, format: .percent.precision(.fractionLength(0)))
            .monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(.secondary)

        ProgressView(value: progress)
      } else {
        ProgressView("Preparing sync…")
      }
    }
    .tint(.blue)
  }
}

/// Displays the optional action owned by the preview or host screen.
private struct DemoStatusCardAction: View {

  let title: LocalizedStringResource
  let tint: Color
  let action: @MainActor () -> Void

  var body: some View {
    Button(action: action) {
      Label {
        Text(title)
      } icon: {
        Image(systemName: "arrow.clockwise")
      }
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .controlSize(.large)
    .tint(tint)
  }
}

/// Gives component previews a consistent width, padding, and adaptive backdrop.
private struct DemoStatusCardCanvas<Content: View>: View {

  let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    content
      .frame(maxWidth: 420)
      .padding(24)
      .frame(maxWidth: .infinity)
      .background(Color(uiColor: .systemGroupedBackground))
  }
}

/// Owns the mutable state used by the interactive Storybook page.
private struct InteractiveStatusCardPreview: View {

  @State private var status: DemoStatusCard.Status = .syncing(progress: 0.42)

  var body: some View {
    DemoStatusCard(
      status: status,
      message: message,
      actionTitle: actionTitle,
      onAction: advance
    )
  }

  private var message: LocalizedStringResource {
    switch status {
    case .syncing:
      return "The catalog is collecting previews from the linked modules."
    case .success:
      return "The latest component states are ready to review."
    case .failure:
      return "A linked module could not be scanned. Try the operation again."
    }
  }

  private var actionTitle: LocalizedStringResource {
    switch status {
    case .syncing:
      return "Finish sync"
    case .success:
      return "Simulate issue"
    case .failure:
      return "Try again"
    }
  }

  private func advance() {
    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
      switch status {
      case .syncing:
        status = .success
      case .success:
        status = .failure
      case .failure:
        status = .syncing(progress: 0.42)
      }
    }
  }
}

#Preview("Status Card - Success") {
  DemoStatusCardCanvas {
    DemoStatusCard(
      status: .success,
      message: "Previews from three linked modules are ready to review."
    )
  }
}

#Preview("Status Card - Loading") {
  DemoStatusCardCanvas {
    DemoStatusCard(
      status: .syncing(progress: 0.68),
      message: "Collecting preview metadata from the application target."
    )
  }
}

#Preview("Status Card - Error") {
  DemoStatusCardCanvas {
    DemoStatusCard(
      status: .failure,
      message: "The static library was not linked with all preview symbols."
    )
  }
}

#Preview("Status Card - Long Content") {
  DemoStatusCardCanvas {
    DemoStatusCard(
      status: .failure,
      message: "The component catalog could not finish scanning every linked module. Check the build settings, rebuild the demo application, and try loading the catalog again."
    )
  }
  .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Status Card - Dark") {
  DemoStatusCardCanvas {
    DemoStatusCard(
      status: .success,
      message: "The catalog is ready in dark appearance."
    )
  }
  .preferredColorScheme(.dark)
}

#Preview("Status Card - Interactive") {
  DemoStatusCardCanvas {
    InteractiveStatusCardPreview()
  }
}
