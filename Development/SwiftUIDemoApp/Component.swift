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

import SwiftUI
import UIKit

#Preview("Circle") {
  Circle()
    .fill(.purple)
    .frame(width: 100, height: 100)
}

#Preview("Circle2") {
  Circle()
    .fill(.purple)
    .frame(width: 100, height: 100)
}

#Preview {
  Circle()
    .fill(.purple)
    .frame(width: 100, height: 100)
}

#Preview {
  UISwitch()
}

#Preview("Color picker controller") {
  UIColorPickerViewController()
}

#Preview("Long scrolling view") {
  longScrollingView()
}

@MainActor
private func longScrollingView() -> UIView {
  let root = UIView()
  root.backgroundColor = .systemBackground

  let scrollView = UIScrollView()
  let stackView = UIStackView()
  stackView.axis = .vertical
  stackView.spacing = 12

  root.addSubview(scrollView)
  scrollView.translatesAutoresizingMaskIntoConstraints = false
  NSLayoutConstraint.activate([
    scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
    scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
    scrollView.topAnchor.constraint(equalTo: root.topAnchor),
    scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
  ])

  scrollView.addSubview(stackView)
  stackView.translatesAutoresizingMaskIntoConstraints = false
  NSLayoutConstraint.activate([
    stackView.leadingAnchor.constraint(
      equalTo: scrollView.contentLayoutGuide.leadingAnchor,
      constant: 20
    ),
    stackView.trailingAnchor.constraint(
      equalTo: scrollView.contentLayoutGuide.trailingAnchor,
      constant: -20
    ),
    stackView.topAnchor.constraint(
      equalTo: scrollView.contentLayoutGuide.topAnchor,
      constant: 20
    ),
    stackView.bottomAnchor.constraint(
      equalTo: scrollView.contentLayoutGuide.bottomAnchor,
      constant: -20
    ),
    stackView.widthAnchor.constraint(
      equalTo: scrollView.frameLayoutGuide.widthAnchor,
      constant: -40
    ),
  ])

  for index in 1...10 {
    let section = UIView()
    section.backgroundColor = [
      UIColor.systemBlue,
      .systemIndigo,
      .systemPurple,
      .systemPink,
      .systemRed,
      .systemOrange,
      .systemYellow,
      .systemGreen,
      .systemTeal,
      .systemCyan,
    ][index - 1]
    section.layer.cornerRadius = 16
    section.heightAnchor.constraint(equalToConstant: 120).isActive = true

    let label = UILabel()
    label.text = "Section \(index)"
    label.font = .preferredFont(forTextStyle: .title2)
    label.textColor = .white
    section.addSubview(label)
    label.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: section.leadingAnchor, constant: 20),
      label.centerYAnchor.constraint(equalTo: section.centerYAnchor),
    ])
    stackView.addArrangedSubview(section)
  }

  return root
}
