import SwiftUI
import UIKit

/// The interface style applied to a Storybook page.
public enum StorybookAppearance: String, CaseIterable, Sendable {
  /// Inherits the interface style of the host.
  case system
  case light
  case dark

  public var userInterfaceStyle: UIUserInterfaceStyle {
    switch self {
    case .system:
      .unspecified
    case .light:
      .light
    case .dark:
      .dark
    }
  }

  var colorScheme: ColorScheme? {
    switch self {
    case .system:
      nil
    case .light:
      .light
    case .dark:
      .dark
    }
  }

  var title: String {
    switch self {
    case .system:
      "System"
    case .light:
      "Light"
    case .dark:
      "Dark"
    }
  }

  var systemImageName: String {
    switch self {
    case .system:
      "circle.lefthalf.filled"
    case .light:
      "sun.max"
    case .dark:
      "moon"
    }
  }
}

struct StorybookAppearanceConfiguration {
  var initialAppearance: StorybookAppearance = .system
  var onChange: (@MainActor (StorybookAppearance) -> Void)?
}

extension EnvironmentValues {
  @Entry var storybookAppearanceConfiguration = StorybookAppearanceConfiguration()
}

struct StorybookAppearanceToggle: View {

  @Binding var appearance: StorybookAppearance
  let inheritedColorScheme: ColorScheme

  var body: some View {
    Button {
      let colorScheme = appearance.colorScheme ?? inheritedColorScheme
      appearance = colorScheme == .dark ? .light : .dark
    } label: {
      Image(systemName: appearance.systemImageName)
    }
    .contextMenu {
      Picker("Appearance", selection: $appearance) {
        ForEach(StorybookAppearance.allCases, id: \.self) { value in
          Label(value.title, systemImage: value.systemImageName)
            .accessibilityIdentifier("storybook.appearance.\(value.rawValue)")
        }
      }
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
      .background(appearance.colorScheme == nil ? Color.clear : Color(uiColor: .systemBackground))
      .transformEnvironment(\.colorScheme) { colorScheme in
        if let explicitColorScheme = appearance.colorScheme {
          colorScheme = explicitColorScheme
        }
      }
  }
}
