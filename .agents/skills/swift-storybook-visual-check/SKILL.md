---
name: swift-storybook-visual-check
description: "Launch and visually verify an exact StorybookKit page in a host app on an iOS Simulator, then capture screenshot evidence. Use after UI changes, when inspecting a SwiftUI preview or BookPage, or when duplicate page names require source-file and line qualifiers."
---

# Swift Storybook Visual Check

Use the standard Storybook launch contract to open one page, verify the rendered UI, and capture evidence.

## Confirm the host adapter

Before launching, confirm that the host app handles Storybook arguments during startup and replaces its normal root with Storybook. The package defines the launch contract, but each host must connect that contract to its app lifecycle and include StorybookKit in the selected build configuration.

If the adapter is absent, stop and report that prerequisite. Do not claim that launch arguments alone can change an unintegrated app.

## Select the page

Use these arguments:

```text
--storybook
--storybook <name>
--storybook --storybook-name=<name>
--storybook <name> --storybook-file <fileID>
--storybook <name> --storybook-file <fileID> --storybook-line <line>
```

- Use `--storybook` alone only when the catalog is the requested result.
- Pass the page name as the positional value immediately after `--storybook`.
- For an empty or hyphen-led name, pass one exact argument in the form
  `--storybook-name=<name>` after `--storybook`.
- Treat `<fileID>` as the compiler source identifier, commonly `Module/Path/File.swift`.
- Treat `<line>` as the preview declaration's positive source line number.

Selection is exact. Do not guess, fuzzy-match, or choose the first duplicate. Start with the name when it is known to be unique. If Storybook reports not found or ambiguous, read the displayed or logged candidates and retry with the exact file, then the line when needed. Preserve argument values as distinct launch-argument entries so spaces in names remain intact.

## Launch and verify

1. Select a simulator-compatible debug build whose host adapter includes StorybookKit.
2. Build and install the host app with the available build tooling.
3. Boot or select a simulator and launch the installed app with the chosen arguments using the available device tooling.
   Preserve scheme-provided inherited arguments when the tooling exposes that option.
4. Wait for the UI to settle, then inspect the view or accessibility hierarchy.
5. Verify the opened page's identifier has the exact form
   `storybook.page|<name-byte-count>:<name>|<fileID-byte-count>:<fileID>|<line>`.
   Both byte counts are UTF-8 byte counts. This source-qualified marker proves
   that another same-name page did not open.
6. Verify that the requested page is visible and that no not-found, ambiguous-selection, invalid-request, crash, or normal-app startup screen replaced it. A launch diagnostic exposes `storybook.launch.failure` instead of a page identifier and lists each corrected launch argument as a separate selectable row.
7. Inspect the rendered UI for the requested change, including clipping, overlap, missing content, unexpected loading state, and incorrect presentation.

Use the host's own scheme, bundle identifier, and supported simulator. Do not assume a particular repository, Xcode integration, command wrapper, or device-control tool.

## Capture evidence

Capture a simulator screenshot only after hierarchy verification succeeds. Remove transient menus, keyboards, touch markers, and unrelated system overlays when possible. Keep the requested page visible at the state being evaluated, save the screenshot to a stable artifact path, and report that path with the verified page selector.

If the device tooling starts an interaction session, always end that session
after capture or failure before reporting the result.

## Fail honestly

Do not silently fall back to the catalog, another matching page, or a build-only result. If the build, host adapter, simulator launch, exact resolution, hierarchy verification, or screenshot capture fails, report the failed stage and the concrete diagnostic. State plainly when no trustworthy screenshot was produced.
