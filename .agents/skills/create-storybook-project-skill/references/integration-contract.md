# Storybook Host Integration Contract

Use this reference while adapting an iOS host. Keep the standard StorybookKit contract stable and put repository-specific behavior at the host and launcher boundaries.

## Standard launch arguments

Pass arguments as distinct process arguments in this order:

```text
--storybook
--storybook <page-name>
--storybook --storybook-name=<page-name>
--storybook <page-name> --storybook-file <module/path/file.swift>
--storybook <page-name> --storybook-file <module/path/file.swift> --storybook-line <line>
```

Use the positional page name for ordinary non-empty names. Use the single argument `--storybook-name=<page-name>` when the name is empty or starts with `-`.

The file identifier is the compiler-emitted `#fileID`, not an absolute path. The line is the positive source line of the preview declaration. Name-only selection must not pick the first duplicate; retry with file ID and then line.

## SwiftUI lifecycle adapter

Parse the request once, before choosing the normal root:

```swift
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

Place conditional compilation around the import and branch when StorybookKit is not linked in every configuration.

## UIKit lifecycle adapter

Resolve the request before constructing the normal root view controller:

```swift
@MainActor
private func makeRootViewController() -> UIViewController {
#if canImport(StorybookKit)
  if let request = StorybookLaunchRequest(
    arguments: ProcessInfo.processInfo.arguments
  ) {
    return UIHostingController(
      rootView: Storybook(launchRequest: request)
    )
  }
#endif

  return makeNormalRootViewController()
}
```

Integrate this branch into the host's existing root factory instead of creating a second app lifecycle. If the project uses a custom `BookStore`, pass the request to `StorybookDisplayRootView(bookStore:launchRequest:)`.

## Environment-variable launcher

Use project-specific shell variables as a convenient input to the project's runner. Convert them into the standard argument array before invoking the app.

```bash
STORYBOOK_PAGE_NAME_IS_SET=0
if [[ "${APP_STORYBOOK_PAGE_NAME+x}" == "x" ]]; then
  STORYBOOK_PAGE_NAME_IS_SET=1
fi

if [[ -n "${APP_STORYBOOK_FILE_ID:-}" && "$STORYBOOK_PAGE_NAME_IS_SET" != "1" ]]; then
  echo "APP_STORYBOOK_FILE_ID requires APP_STORYBOOK_PAGE_NAME." >&2
  exit 1
fi

if [[ -n "${APP_STORYBOOK_PAGE_LINE:-}" && -z "${APP_STORYBOOK_FILE_ID:-}" ]]; then
  echo "APP_STORYBOOK_PAGE_LINE requires APP_STORYBOOK_FILE_ID." >&2
  exit 1
fi

if [[ "${APP_STORYBOOK:-0}" == "1" || "$STORYBOOK_PAGE_NAME_IS_SET" == "1" ]]; then
  LAUNCH_ARGUMENTS+=("--storybook")

  if [[ "$STORYBOOK_PAGE_NAME_IS_SET" == "1" ]]; then
    if [[ -z "$APP_STORYBOOK_PAGE_NAME" || "$APP_STORYBOOK_PAGE_NAME" == -* ]]; then
      LAUNCH_ARGUMENTS+=("--storybook-name=$APP_STORYBOOK_PAGE_NAME")
    else
      LAUNCH_ARGUMENTS+=("$APP_STORYBOOK_PAGE_NAME")
    fi
  fi

  if [[ -n "${APP_STORYBOOK_FILE_ID:-}" ]]; then
    LAUNCH_ARGUMENTS+=("--storybook-file" "$APP_STORYBOOK_FILE_ID")
  fi

  if [[ -n "${APP_STORYBOOK_PAGE_LINE:-}" ]]; then
    LAUNCH_ARGUMENTS+=("--storybook-line" "$APP_STORYBOOK_PAGE_LINE")
  fi
fi
```

Replace `APP` with the project's stable prefix. Validate any restricted variant or configuration before building.

Launch with array-preserving expansion:

```bash
xcrun simctl launch \
  --terminate-running-process \
  "$SIMULATOR_UDID" \
  "$BUNDLE_ID" \
  "${LAUNCH_ARGUMENTS[@]}"
```

Do not pass one quoted string containing several arguments. Do not use `eval`.

`SIMCTL_CHILD_<NAME>` passes an environment variable into the app process. That is a separate mechanism and is not required by StorybookKit. Prefer translating the runner's project-specific variables into standard launch arguments unless the host has a real need for additional process environment.

## Catalog construction

For the default catalog, use `Storybook(launchRequest:)`. For a custom catalog, preserve existing pages and include discovered previews:

```swift
let store = BookStore(
  book: Book(title: "Components") {
    Book.allBookPreviews() ?? []
  }
)

StorybookDisplayRootView(
  bookStore: store,
  launchRequest: request
)
```

Keep manual in-app presentation separate from programmable startup. Manual presentation may retain last-page behavior; an explicit launch request must establish the requested page or show a diagnostic.

## Deterministic verification

After exact resolution succeeds, Storybook exposes this root identifier:

```text
storybook.page|<name-byte-count>:<name>|<fileID-byte-count>:<fileID>|<line>
```

Counts are UTF-8 byte counts. Verify the identifier and visible content before screenshot capture. Treat `storybook.launch.failure`, normal app startup, a catalog fallback, or another same-name page as failure.

## Configuration safety

- Link StorybookKit only in intended development or internal configurations unless the product explicitly ships it.
- Guard code with the project's established compilation conditions.
- Preserve normal startup when `--storybook` is absent.
- Preserve unrelated host launch arguments.
- Keep credentials, user data, and production-only services out of preview setup.
- Do not claim physical-device automation when the verified workflow only supports Simulator.
