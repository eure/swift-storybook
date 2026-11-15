import SwiftUI
import Testing

@testable import StorybookKit

@Suite("Storybook appearance")
struct AppearanceContextTests {

  @Test("The initial appearance follows the system")
  func initialAppearance() {
    let context = AppearanceContext()

    #expect(context.overrideColorScheme == nil)
  }

  @Test(
    "Tapping in System mode fixes the opposite appearance", arguments: [ColorScheme.light, .dark])
  func toggleFromSystem(inherited: ColorScheme) {
    let context = AppearanceContext()

    context.toggle(relativeTo: inherited)

    #expect(context.overrideColorScheme == (inherited == .light ? .dark : .light))
  }

  @Test(
    "Repeated taps alternate fixed appearances without returning to System",
    arguments: [ColorScheme.light, .dark])
  func repeatedTaps(inherited: ColorScheme) {
    let context = AppearanceContext()

    context.toggle(relativeTo: inherited)
    context.toggle(relativeTo: inherited)
    #expect(context.overrideColorScheme == inherited)

    context.toggle(relativeTo: inherited)
    #expect(context.overrideColorScheme == (inherited == .light ? .dark : .light))
  }

  @Test(
    "Tapping uses the explicit selection rather than the inherited appearance",
    arguments: [ColorScheme.light, .dark], [ColorScheme.light, .dark]
  )
  func toggleExplicitSelection(selected: ColorScheme, inherited: ColorScheme) {
    let context = AppearanceContext()
    context.overrideColorScheme = selected

    context.toggle(relativeTo: inherited)

    #expect(context.overrideColorScheme == (selected == .light ? .dark : .light))
  }

  @Test(
    "Selecting System clears the override and uses the current inherited appearance",
    arguments: [ColorScheme.light, .dark])
  func returnToSystem(inherited: ColorScheme) {
    let context = AppearanceContext()
    context.overrideColorScheme = .dark

    context.overrideColorScheme = nil
    #expect(context.overrideColorScheme == nil)

    context.toggle(relativeTo: inherited)
    #expect(context.overrideColorScheme == (inherited == .light ? .dark : .light))
  }

}
