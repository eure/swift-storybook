import SwiftUI
import UIKit

/// The interface style applied to a Storybook page.
public enum StorybookAppearance: String, CaseIterable, Sendable {
  case light
  case dark

  init(_ colorScheme: ColorScheme) {
    self = colorScheme == .dark ? .dark : .light
  }

  public var userInterfaceStyle: UIUserInterfaceStyle {
    switch self {
    case .light:
      .light
    case .dark:
      .dark
    }
  }

  var colorScheme: ColorScheme {
    switch self {
    case .light:
      .light
    case .dark:
      .dark
    }
  }

  var toggled: StorybookAppearance {
    switch self {
    case .light:
      .dark
    case .dark:
      .light
    }
  }

  var title: String {
    switch self {
    case .light:
      "Light"
    case .dark:
      "Dark"
    }
  }

  var systemImageName: String {
    switch self {
    case .light:
      "sun.max"
    case .dark:
      "moon"
    }
  }
}

struct StorybookAppearanceConfiguration {
  var initialAppearance: StorybookAppearance?
  var onChange: (@MainActor (StorybookAppearance) -> Void)?
}

extension EnvironmentValues {
  @Entry var storybookAppearanceConfiguration = StorybookAppearanceConfiguration()
}

struct StorybookAppearanceToggle: View {

  @Binding var appearance: StorybookAppearance

  var body: some View {
    Button {
      appearance = appearance.toggled
    } label: {
      Image(systemName: appearance.systemImageName)
    }
    .accessibilityLabel("Appearance")
    .accessibilityValue(appearance.title)
    .accessibilityIdentifier("storybook.appearance.toggle")
  }
}

extension View {

  func storybookAppearance(_ appearance: StorybookAppearance) -> some View {
    self
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(uiColor: .systemBackground))
      .environment(\.colorScheme, appearance.colorScheme)
  }
}
