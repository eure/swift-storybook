# Storybook for iOS

This library allows you to view UI components in a catalog-style format.  
In most cases, it works by simply adding a few lines of code, as it gathers SwiftUI preview codes at runtime.

<img width="150px" src="https://github.com/user-attachments/assets/c6819a8a-3685-422b-a561-16ab513ccd54" alt="storybook previewing">

## Setup

1. Install this package into your project.

2. Put the entrypoint view.

```swift
import StorybookKit
import SwiftUI

struct ContentView: View {
  var body: some View {
    Storybook()
  }
}
```

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

### Agent visual checks

This repository includes the [`swift-storybook-visual-check`](.agents/skills/swift-storybook-visual-check/SKILL.md) skill. After the host adapter is connected, an Agent can use the same launch arguments to open the exact page, verify its hierarchy, and capture a simulator screenshot without navigating the catalog by hand.

## Example

In app executable module

```swift
#Preview("Circle") {
  Circle()
    .fill(.purple)
    .frame(width: 100, height: 100)
}
```

In a dynamic framework module
```swift
#Preview("Circle") {
  Circle()
    .fill(.purple)
    .frame(width: 100, height: 100)
}
```

In a static library module
```swift
#Preview("Circle") {
  Circle()
    .fill(.purple)
    .frame(width: 100, height: 100)
}
```

> [!IMPORTANT]
> To display all preview codes in a statically linked binary, you may need to link the binary with the -all_load linker flag.
> This is because the linker does not load symbols into the target binary if it deems them unnecessary.

<img width="150px" src="https://github.com/user-attachments/assets/f849a5a1-c0df-4551-a9a8-c5a0367fe459" alt="list of modules">

## Maintainers

- [Hiroshi Kimura (Muukii)](https://github.com/muukii)
- [John Estropia](https://github.com/johnestropia)

## License

Storybook-ios is released under the MIT license.
