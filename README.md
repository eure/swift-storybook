# Storybook for iOS and macOS

Turn the `#Preview` declarations already in your app into an in-app component catalog.

Add `Storybook()` once, then keep writing previews as usual. Storybook discovers them at runtime and adds them to the catalog automatically—there is no separate registration step.

```swift
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

#Preview {
  UIColorPickerViewController()
}
```

<img width="320" alt="simulator_screenshot_4376C04E-79B0-4319-A2FC-1FA5DA25CC79" src="https://github.com/user-attachments/assets/f16cd30c-2b10-45cf-b3a6-b408df0c521b" />


## Motivation

Xcode previews can become difficult to keep working reliably in very large projects, especially when the build is complex. When that happens, existing `#Preview` declarations often stop contributing to the development loop even though they still describe valuable component states.

Storybook was created to preserve that investment. It discovers previews from a regular app build and presents them as a catalog, allowing teams to reuse their preview code and maintain a smooth UI development loop through the build and runtime path their project already relies on.

Even when Xcode previews work well, running Storybook as part of an app provides additional benefits:

- Open previews directly on a physical device.
- Keep the catalog available in the installed app across launches, independently of an Xcode preview session.
- Include a Storybook entry point in debug or internal builds and open it from within the app whenever it is needed.

## From `#Preview` to Storybook

```swift
#Preview("Circle") {
  Circle()
    .fill(.purple)
    .frame(width: 100, height: 100)
}
```

**The preview automatically appears in Storybook:**

<img width="150px" src="https://github.com/user-attachments/assets/c6819a8a-3685-422b-a561-16ab513ccd54" alt="A SwiftUI preview automatically displayed in Storybook">

The same declaration continues to work as an Xcode preview, so your preview code becomes the source of truth for both development and the in-app catalog.

The included [`swift-storybook-visual-check`](.agents/skills/swift-storybook-visual-check/SKILL.md) skill also turns that catalog into a repeatable visual-check workflow for coding agents.

## Quick start

1. Add the package and link the `StorybookKit` product to your app.

2. Put `Storybook` at the entry point of your catalog app or debug-only route.

```swift
import StorybookKit
import SwiftUI

struct ContentView: View {
  var body: some View {
    Storybook()
  }
}
```

3. Add `#Preview` declarations anywhere in the linked modules. No Storybook-specific registration is needed.

```swift
#Preview("Circle") {
  Circle()
    .fill(.purple)
    .frame(width: 100, height: 100)
}
```

### Native macOS host

Native macOS hosting requires macOS 14 or later. Link `StorybookKit` into a
SwiftUI or AppKit app and embed `Storybook()` in its window, using
`NSHostingController` when the host uses AppKit. SwiftUI, `NSView`, and
`NSViewController` previews are discovered from the app and its linked dynamic
frameworks. Controller previews open as native sheets.

The macOS catalog uses a resizable sidebar for preview folders, history, and
search, with the selected preview in the detail pane. The toolbar can hide or
show the sidebar. An exact-page launch selects and reveals its catalog row.

```swift
import AppKit
import StorybookKit
import SwiftUI

@main
struct CatalogApp: App {
  private let launchRequest = StorybookLaunchRequest(
    arguments: ProcessInfo.processInfo.arguments
  ) ?? .catalog

  var body: some Scene {
    WindowGroup {
      Storybook(launchRequest: launchRequest)
    }
  }
}

#Preview("Native button") {
  NSButton(title: "Continue", target: nil, action: nil)
}
```

The [macOS demo](Development/MacDemo) is a separate SwiftPM executable package
that uses the repository as a local dependency. Build it from the repository root:

```sh
swift build --package-path Development/MacDemo
```

The demo includes interactive SwiftUI and AppKit counters and a dismissible
controller sheet.
The existing iOS demo remains in `Development/Storybook.xcodeproj`.

`Book`, `BookPage`, `BookPageSelector`, and `StorybookLaunchRequest` use the same
API on both platforms, including exact-page arguments and accessibility
identifiers. Native preview and image-export types follow the platform:

| Export content | iOS | macOS |
| --- | --- | --- |
| SwiftUI | `StorybookViewportRenderer` | `StorybookViewportRenderer` |
| Native view | `StorybookUIViewRenderer` / `StorybookUIView` | `StorybookNSViewRenderer` / `StorybookNSView` |
| Presented controller | `StorybookPresentedViewControllerRenderer` / `UIViewController` | `StorybookPresentedViewControllerRenderer` / `NSViewController` |
| Exported image | `StorybookExportImage.image: UIImage` | `StorybookExportImage.image: NSImage` |
| Safe-area insets | `UIEdgeInsets` | `NSEdgeInsets` |

Native view export requires a host attached to a live window; the preview factory
returns an unattached view. Controller export
captures the presented window's content area, without the window's title bar.
On macOS, image export preserves the visible viewport of native scroll views;
it does not expand their documents into a full-content image.
The included agent visual-check and viewport-artifact workflow below targets
the iOS Simulator; use the macOS demo and native macOS window tooling for Mac
checks.

## Preview discovery

Storybook automatically discovers previews in the app executable and linked dynamic frameworks.

Each catalog entry currently renders one preview. Parameterized or grouped
preview declarations show an unsupported-content diagnostic.

> [!IMPORTANT]
> Previews in a static library may require the `-all_load` linker flag. Without it, the linker can remove preview symbols that appear unused, preventing Storybook from discovering them.

<img width="150px" src="https://github.com/user-attachments/assets/f849a5a1-c0df-4551-a9a8-c5a0367fe459" alt="list of modules">

## Agentic Coding

Storybook provides a deterministic bridge from UI code to visual verification in Simulator. The included [`swift-storybook-visual-check`](.agents/skills/swift-storybook-visual-check/SKILL.md) skill guides a coding agent through the complete check:

1. Select an exact `#Preview` or `BookPage` by name.
2. Disambiguate duplicate names with the source file and declaration line when needed.
3. Launch the host app directly into that page.
4. Verify its source-qualified accessibility identifier and rendered UI.
5. Prefer a host viewport artifact when available: it excludes Storybook chrome,
   expands root scroll content, and captures `UIViewController` previews as a
   full presented window. Verify its manifest selector, render mode, appearance,
   dimensions, and SHA-256 through `simctl get_app_container`.
6. Otherwise, capture a clean simulator screenshot only after hierarchy
   verification.

This makes UI validation reproducible without navigating the catalog by hand or adding a separate route for every component.

To onboard another app, use the [`create-storybook-project-skill`](.agents/skills/create-storybook-project-skill/SKILL.md) skill. It connects `StorybookLaunchRequest` to the host's real startup lifecycle, maps project-specific environment variables onto the standard launch arguments, and generates a repository-local visual-check skill with the exact scheme, bundle identifier, runner, and simulator workflow.

> [!NOTE]
> The host app must first connect `StorybookLaunchRequest` to its startup lifecycle and include `StorybookKit` in the selected build configuration. The package defines the launch contract but cannot replace an app's root UI on its own.

## Programmable launch

Storybook can parse a standard process argument and open its catalog or an exact page immediately. The host app must check the request before starting its normal UI; this package cannot intercept or replace an app's startup path by itself.

```swift
import Foundation
import StorybookKit
import SwiftUI

@main
struct ExampleApp: App {
  private let storybookLaunchRequest: StorybookLaunchRequest? = .init(
    arguments: ProcessInfo.processInfo.arguments
  )

  var body: some Scene {
    WindowGroup {
      if let storybookLaunchRequest {
        Storybook(launchRequest: storybookLaunchRequest)
      } else {
        AppRootView()
      }
    }
  }
}
```

Use the same request with a custom book:

```swift
@MainActor
func makeCustomStorybook(
  launchRequest: StorybookLaunchRequest
) -> some View {
  let book = Book(title: "Design System") {
    BookPage(title: "Primary button") {
      Button("Continue") {}
    }
  }

  return StorybookDisplayRootView(
    bookStore: BookStore(book: book),
    launchRequest: launchRequest
  )
}
```

The standard arguments are:

```text
--storybook
--storybook <page-name>
--storybook --storybook-name=<page-name>
--storybook <page-name> --storybook-file <module/file.swift>
--storybook <page-name> --storybook-file <module/file.swift> --storybook-line <line>
```

`--storybook` opens the catalog. Supply each token above as a distinct process argument; a page name containing spaces remains one argument. The positional form is convenient for ordinary names; use the single argument `--storybook-name=<page-name>` when the exact name is empty or begins with `-`. A name-only page request succeeds only when exactly one page has that name. Add the compiler-emitted `#fileID`, then the declaration line when necessary, to disambiguate duplicate names. Supplied page names and file identifiers are matched by their original UTF-8 bytes, without trimming, Unicode normalization, case folding, fuzzy search, or order-dependent fallback. Not-found and ambiguous requests remain visible in Storybook with candidate source locations and reusable launch-argument entries instead of opening another page. Pages that share the same name, file ID, and line must be given a unique declaration name or source location; Storybook does not choose between indistinguishable declarations.

After a page opens, its root exposes a deterministic accessibility identifier in this form:

```text
storybook.page|<name-byte-count>:<name>|<fileID-byte-count>:<fileID>|<line>
```

The counts are UTF-8 byte counts. This lets automation prove that a qualified request opened the intended page before taking a screenshot.

## Appearance

Each page has a Light / Dark toggle in its navigation bar. A page opens in the host's appearance, and a tap switches only that page, including UIKit views inside it, without relaunching the app. The catalog and other pages keep the host's appearance.

The toggle sets the SwiftUI color scheme of the page's content. A SwiftUI sheet presented from the page inherits it for its content, but its background keeps the host's appearance, and alerts keep the host's appearance. To check presented UI, change the host's appearance instead.

The toggle exposes the accessibility identifier `storybook.appearance.toggle`.

## Maintainers

- [Hiroshi Kimura (Muukii)](https://github.com/muukii)
- [John Estropia](https://github.com/johnestropia)

## License

Storybook-ios is released under the MIT license.
