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

## Deep links

Storybook can open a page from a URL once the host app registers a URL scheme.
This is useful for automated UI validation because an agent can build the app,
open a Storybook page directly in Simulator, and capture a screenshot of the
rendered component.

### Configure the host app

Register a URL scheme in the host app's `Info.plist`.

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>com.example.MyApp</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>my-storybook</string>
    </array>
  </dict>
</array>
```

Pass the same scheme to Storybook:

```swift
Storybook(deepLinkScheme: "my-storybook")
```

The URL format is:

```text
my-storybook://page?id=<page-stable-id>
```

Each page screen has a link button that copies its deep link to the pasteboard.

### Page IDs

For pages created from `#Preview`, Storybook uses the preview source location as
the stable page ID:

```text
<module-name>/<file-name>.swift:<preview-declaration-line>
```

For example, this preview:

```swift
#Preview("Circle") {
  Circle()
}
```

declared at line 24 in `SwiftUIDemoApp/Component.swift` can be opened with:

```text
my-storybook://page?id=SwiftUIDemoApp/Component.swift:24
```

The preview display name is not the ID. Multiple previews can share the same
display name because they are distinguished by `fileID:line`. Re-check the line
number after editing or formatting previews.

### Opening a page in Simulator

After installing the host app on a simulator, open the page with `simctl`:

```bash
xcrun simctl openurl booted 'my-storybook://page?id=SwiftUIDemoApp/Component.swift:24'
```

iOS may show a one-time confirmation dialog before opening the app from a custom
scheme. Accept it, then repeat the command if necessary.

### UIKit host apps

SwiftUI apps can receive URLs through `.onOpenURL` when Storybook is already in
the view tree. UIKit apps should route URLs from `SceneDelegate` or
`AppDelegate`, present the Storybook UI if needed, then pass the URL into
Storybook so it can resolve and open the page.

### Agent workflow

This repository includes a Codex skill at
`.agents/skills/swift-storybook-visual-check`. It documents the recommended
agent flow:

1. Prefer a Storybook manifest if the host app exposes one.
2. Otherwise infer the page ID from the `#Preview` declaration location.
3. Build and run the app in Simulator.
4. Open the Storybook deep link.
5. Capture a screenshot and verify that the target page rendered.

## License

Storybook-ios is released under the MIT license.
