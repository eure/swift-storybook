import SwiftUI
import UIKit

/// The interface style Storybook applies to a page's preview content.
///
/// The style is scoped to the page content through the SwiftUI color scheme,
/// which SwiftUI also bridges to the trait collection of hosted UIKit views
/// and view controllers, so UIKit dynamic colors resolve with it.
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

/// The host-provided initial appearance and change observer.
struct StorybookAppearanceConfiguration {
  var initialAppearance: StorybookAppearance = .system
  var onChange: (@MainActor (StorybookAppearance) -> Void)?
}

extension EnvironmentValues {
  @Entry var storybookAppearanceConfiguration = StorybookAppearanceConfiguration()
}

/// A toolbar menu that switches the appearance of the current page.
struct StorybookAppearanceMenu: View {

  @Binding var appearance: StorybookAppearance

  var body: some View {
    Menu {
      Picker("Appearance", selection: $appearance) {
        ForEach(StorybookAppearance.allCases, id: \.self) { value in
          Label(value.title, systemImage: value.systemImageName)
            .accessibilityIdentifier("storybook.appearance.\(value.rawValue)")
        }
      }
    } label: {
      Image(systemName: appearance.systemImageName)
    }
    .accessibilityLabel("Appearance")
    .accessibilityValue(appearance.title)
    .accessibilityIdentifier("storybook.appearance.menu")
  }
}

extension View {

  /// Resolves this content with an explicit appearance, leaving `.system`
  /// to inherit the surrounding appearance.
  ///
  /// The view identity is the same for every appearance, so switching keeps
  /// the content's state and exercises its handling of trait changes.
  func storybookAppearance(_ appearance: StorybookAppearance) -> some View {
    self
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      // An opaque background fills the page, including behind the navigation
      // bar, so the page and its bar read as one appearance.
      .background(appearance.colorScheme == nil ? Color.clear : Color(uiColor: .systemBackground))
      .transformEnvironment(\.colorScheme) { colorScheme in
        if let explicitColorScheme = appearance.colorScheme {
          colorScheme = explicitColorScheme
        }
      }
  }
}
