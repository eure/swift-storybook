#if os(macOS)
import AppKit
import SwiftUI

/// Runs an action with the nearest Storybook AppKit presentation controller.
public struct BookAction: BookView {
  @Environment(\.storybook_targetViewController) private var targetViewController

  public let declarationIdentifier: DeclarationIdentifier
  public let action: @MainActor (NSViewController) -> Void
  public let title: String

  public init(title: String, action: @escaping @MainActor (NSViewController) -> Void) {
    self.title = title
    self.action = action
    self.declarationIdentifier = .init()
  }

  public var body: some View {
    Button(title) {
      if let targetViewController { action(targetViewController) }
    }
    .disabled(targetViewController == nil)
  }
}

/// Opens an AppKit controller as a destination in the Storybook navigation stack.
public struct BookPush: BookView {
  public let pushingViewControllerBlock: @MainActor () -> NSViewController
  public let declarationIdentifier: DeclarationIdentifier
  public let title: String

  public init(
    title: String,
    pushingViewControllerBlock: @escaping @MainActor () -> NSViewController
  ) {
    self.title = title
    self.pushingViewControllerBlock = pushingViewControllerBlock
    self.declarationIdentifier = .init()
  }

  public var body: some View {
    NavigationLink(title) {
      _ViewControllerHost(instantiate: pushingViewControllerBlock)
    }
  }
}

/// Presents an AppKit controller as a sheet attached to the host window.
///
/// The supplied controller owns its content and dismissal, as it does in an
/// ordinary `NSViewController.presentAsSheet(_:)` presentation.
public struct BookPresent: BookView {
  @Environment(\.storybook_targetViewController) private var targetViewController

  public let declarationIdentifier: DeclarationIdentifier
  public let presentedViewControllerBlock: @MainActor () -> NSViewController
  public let title: String

  public init(
    title: String,
    presentingViewControllerBlock: @escaping @MainActor () -> NSViewController
  ) {
    self.title = title
    self.presentedViewControllerBlock = presentingViewControllerBlock
    self.declarationIdentifier = .init()
  }

  public var body: some View {
    Button(title) {
      targetViewController?.presentAsSheet(presentedViewControllerBlock())
    }
    .disabled(targetViewController == nil)
  }
}
#endif
