import AppKit
import SwiftUI

/// A stateful SwiftUI fixture for checking interaction inside a discovered page.
private struct CounterPreview: View {

  @State private var count = 0
  @State private var showsDetails = true

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label("Native macOS preview", systemImage: "macwindow")
        .font(.title2)

      Text("Count: \(count)")
        .monospacedDigit()
        .accessibilityIdentifier("mac-demo.counter.value")

      HStack {
        Button("Increment") { count += 1 }
          .accessibilityIdentifier("mac-demo.counter.increment")
        Button("Reset") { count = 0 }
      }

      Toggle("Show details", isOn: $showsDetails)
      if showsDetails {
        Text("This page is discovered from a SwiftUI #Preview declaration.")
          .foregroundStyle(.secondary)
      }
    }
    .padding(24)
    .frame(width: 420, alignment: .leading)
  }
}

/// An AppKit view with a native button to verify represented-view interaction.
@MainActor
private final class CounterNSView: NSView {

  private let valueLabel = NSTextField(labelWithString: "AppKit count: 0")
  private var count = 0

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    let title = NSTextField(labelWithString: "Native NSView preview")
    title.font = .systemFont(ofSize: 20, weight: .semibold)
    let button = NSButton(title: "Increment", target: self, action: #selector(increment))
    button.setAccessibilityIdentifier("mac-demo.nsview.increment")
    valueLabel.setAccessibilityIdentifier("mac-demo.nsview.value")

    let stack = NSStackView(views: [title, valueLabel, button])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 16
    stack.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
      stack.topAnchor.constraint(equalTo: topAnchor, constant: 24),
      stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
      stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -24),
    ])
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var intrinsicContentSize: NSSize {
    NSSize(width: 420, height: 180)
  }

  @objc private func increment() {
    count += 1
    valueLabel.stringValue = "AppKit count: \(count)"
  }
}

/// A controller fixture whose content is installed through the AppKit lifecycle.
@MainActor
private final class CounterViewController: NSViewController {

  override func loadView() {
    let counter = CounterNSView(frame: NSRect(x: 0, y: 0, width: 420, height: 180))
    let closeButton = NSButton(title: "Close", target: self, action: #selector(close))
    closeButton.setAccessibilityIdentifier("mac-demo.controller.close")
    let stack = NSStackView(views: [counter, closeButton])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 12
    stack.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 20, right: 12)
    stack.frame = NSRect(x: 0, y: 0, width: 460, height: 260)
    view = stack
    preferredContentSize = NSSize(width: 460, height: 260)
  }

  @objc private func close() {
    dismiss(nil)
  }
}

#Preview("macOS SwiftUI Counter") {
  CounterPreview()
}

#Preview("macOS AppKit View") {
  CounterNSView(frame: NSRect(x: 0, y: 0, width: 420, height: 180))
}

#Preview("macOS AppKit Controller") {
  CounterViewController()
}
