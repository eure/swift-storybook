//
// Copyright (c) 2026 Eureka, Inc.
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


import SwiftUI
import UIKit

private struct AppearanceDemo: View {

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text("SwiftUI")
          .font(.headline)
        Text("Primary and secondary styles on a grouped background.")
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding()
      .background(Color(uiColor: .secondarySystemGroupedBackground))
      .clipShape(RoundedRectangle(cornerRadius: 12))

      UIKitAppearanceCard()
        .frame(height: 88)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Color(uiColor: .systemGroupedBackground))
  }
}

private struct UIKitAppearanceCard: UIViewRepresentable {

  func makeUIView(context: Context) -> UIView {
    let title = UILabel()
    title.text = "UIKit"
    title.font = .preferredFont(forTextStyle: .headline)
    title.textColor = .label

    let message = UILabel()
    message.text = "Label colors resolved from UIKit traits."
    message.font = .preferredFont(forTextStyle: .body)
    message.textColor = .secondaryLabel
    message.numberOfLines = 0

    let stack = UIStackView(arrangedSubviews: [title, message])
    stack.axis = .vertical
    stack.spacing = 4
    stack.translatesAutoresizingMaskIntoConstraints = false

    let card = UIView()
    card.backgroundColor = .secondarySystemGroupedBackground
    card.layer.cornerRadius = 12
    card.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
      stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
      stack.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -16),
    ])
    return card
  }

  func updateUIView(_ uiView: UIView, context: Context) {}
}

#Preview("Appearance - SwiftUI and UIKit") {
  AppearanceDemo()
}
