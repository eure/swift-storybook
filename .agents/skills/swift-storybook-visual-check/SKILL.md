---
name: swift-storybook-visual-check
description: Use when validating iOS UI work through swift-storybook by opening Storybook deep links in a simulator, inferring page IDs from #Preview declarations when needed, and capturing screenshots to confirm the rendered result.
---

# Swift Storybook Visual Check

Use this skill to verify UI changes in an iOS app that embeds `swift-storybook`. The goal is to open the exact Storybook page for the UI being changed, capture the simulator screen, and compare the result with the implementation intent.

## Workflow

1. Identify the app target, scheme, simulator, and Storybook URL scheme.
2. Build and run the iOS app. Prefer the repo's requested Xcode MCP tooling when available.
3. Find the Storybook page URL.
4. Open the URL in the simulator.
5. Capture a screenshot and verify that the expected page, title, and rendered UI are visible.

## Finding The Page URL

Prefer sources in this order:

1. Use a Storybook manifest if the app exposes one.
2. Use a copied deep link from the Storybook page if available.
3. Infer the page ID from source code.
4. If inference fails, open the Storybook root and use search.

For current `#Preview` pages, the page ID is usually:

```text
<module-name>/<file-name>.swift:<preview-declaration-line>
```

Example:

```swift
#Preview("Circle") {
  Circle()
}
```

If that declaration starts at line 24 in `SwiftUIDemoApp/Component.swift`, infer:

```text
SwiftUIDemoApp/Component.swift:24
```

Then open:

```text
storybook://page?id=SwiftUIDemoApp/Component.swift:24
```

Important details:

- The preview display name is not the page ID.
- The ID is based on runtime `PreviewRegistry.fileID` and `PreviewRegistry.line`.
- The line is the line where the `#Preview` declaration starts.
- `fileID` is usually `<ModuleName>/<FileName.swift>`, not an absolute file path.
- Re-check line numbers after editing, formatting, or inserting previews.
- Multiple previews with the same display name are distinguished by `fileID:line`.
- URL encoding of `/` and `:` in the query value is acceptable.

## Opening A Deep Link

Use the booted simulator id when known:

```bash
xcrun simctl openurl <simulator-id> 'storybook://page?id=SwiftUIDemoApp/Component.swift:24'
```

If the app is already installed, this can launch the app from a stopped state. iOS may show a one-time "Open in <App>?" confirmation; accept it before judging the result.

## SwiftUI Host Apps

SwiftUI host apps can rely on Storybook's SwiftUI entry point when the Storybook view is already in the app tree. For app-wide deep links, route URLs from the app root and present Storybook before passing the URL into Storybook.

## UIKit Host Apps

Do not rely on SwiftUI `.onOpenURL` in UIKit apps. Find the URL entry point in `SceneDelegate` or `AppDelegate`, present the Storybook view controller if it is not visible, then pass the URL to Storybook.

Expected host flow:

```text
SceneDelegate/AppDelegate URL callback
  -> present Storybook
  -> pass deep link URL
  -> Storybook resolves page ID
  -> Storybook opens the page
```

## Verification

After opening the URL, capture a screenshot with the available simulator tooling. Confirm:

- The navigation title matches the target preview title.
- The rendered UI matches the component you changed.
- The page is not merely the Storybook root or search screen.

If the page does not open:

- Confirm the app has registered the URL scheme in `Info.plist`.
- Confirm the app was rebuilt after adding or moving the preview.
- Recompute the ID from the current `#Preview` line.
- Try opening the Storybook root and searching for the preview title.
- If available, prefer the manifest over source inference.
