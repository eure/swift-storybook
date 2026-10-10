import AppKit
import StorybookKit
import SwiftUI

/// Hosts the same preview catalog and launch contract used by the iOS demo.
@main
struct StorybookMacDemoApp: App {

  @NSApplicationDelegateAdaptor(DemoApplicationDelegate.self)
  private var applicationDelegate

  private let launchRequest = StorybookLaunchRequest(
    arguments: ProcessInfo.processInfo.arguments
  ) ?? .catalog

  var body: some Scene {
    WindowGroup("Storybook for macOS") {
      Storybook(launchRequest: launchRequest)
        .frame(minWidth: 640, minHeight: 480)
    }
    .defaultSize(width: 960, height: 700)
  }
}

/// Gives the SwiftPM demo normal Dock and foreground-window behavior.
@MainActor
final class DemoApplicationDelegate: NSObject, NSApplicationDelegate {

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
  }
}
