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
