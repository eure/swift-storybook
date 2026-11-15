import SwiftUI

struct AppearanceButton: View {

  @Environment(\.colorScheme) private var inheritedColorScheme

  private let context: AppearanceContext

  private var activeColorScheme: ColorScheme {
    context.overrideColorScheme ?? inheritedColorScheme
  }

  private var accessibilityValue: String {
    switch context.overrideColorScheme {
    case .light?:
      return "Light (Override)"
    case .dark?:
      return "Dark (Override)"
    case nil:
      return activeColorScheme == .dark ? "System (Dark)" : "System (Light)"
    @unknown default:
      return "System"
    }
  }

  init(context: AppearanceContext) {
    self.context = context
  }

  var body: some View {
    @Bindable var context = context

    Menu {
      Picker("Appearance", selection: $context.overrideColorScheme) {
        Label("System", systemImage: "desktopcomputer")
          .tag(nil as ColorScheme?)

        Label("Light", systemImage: "sun.max")
          .tag(ColorScheme.light as ColorScheme?)

        Label("Dark", systemImage: "moon")
          .tag(ColorScheme.dark as ColorScheme?)
      }
    } label: {
      Label("Appearance", systemImage: activeColorScheme == .dark ? "moon" : "sun.max")
    } primaryAction: {
      context.toggle(relativeTo: inheritedColorScheme)
    }
    .labelStyle(.iconOnly)
    .tint(context.overrideColorScheme == nil ? Color.primary : Color.accentColor)
    .accessibilityLabel("Appearance")
    .accessibilityValue(accessibilityValue)
    .accessibilityHint(
      "Activate to switch appearance. Open the menu to choose System, Light, or Dark."
    )
    .help("Switch appearance. Open the menu to choose System, Light, or Dark.")
  }

}

#Preview {
  @Previewable @State var context = AppearanceContext()

  NavigationStack {
    Text("Appearance")
      .toolbar {
        ToolbarItem {
          AppearanceButton(context: context)
        }
      }
  }
  .preferredColorScheme(context.overrideColorScheme)
}
