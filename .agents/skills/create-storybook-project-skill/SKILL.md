---
name: create-storybook-project-skill
description: "Configure an iOS host project for deterministic StorybookKit startup and create a project-local visual-check skill with its exact build, install, launch, selector, and verification workflow. Use when onboarding StorybookKit for agentic coding, exposing project-specific environment variables that launch the catalog or one #Preview, or replacing a generic Storybook workflow with a repository-specific skill."
---

# Create a Storybook Project Skill

Configure the target app to open Storybook through its real startup path, then generate a self-contained Skill that can repeat the project's exact visual-check workflow.

## Preserve the contract boundary

Keep these responsibilities separate:

- Let StorybookKit own the project-independent `--storybook` launch arguments.
- Let the host app parse `StorybookLaunchRequest` before constructing its normal root UI.
- Let the project's runner translate project-specific environment variables into the standard arguments.
- Let the generated Skill own concrete repository facts such as the scheme, bundle identifier, configuration, simulator selection, and commands.

Do not add project-specific environment-variable parsing to StorybookKit. Environment variables are a launcher interface; process arguments are the app-facing contract.

Read [references/integration-contract.md](references/integration-contract.md) before changing the host app or its runner.

## 1. Inspect the target project

Read the target repository's instruction files completely before editing. Then locate and verify:

1. The dependency declaration and configurations that link `StorybookKit`.
2. The application startup boundary: SwiftUI `App`, scene delegate, app delegate, or a custom root coordinator.
3. The existing Storybook catalog, `BookStore`, manual developer-menu entry, and preview discovery path.
4. The canonical build/install/launch command and its simulator-selection behavior.
5. The scheme, configuration, bundle identifier, supported app variants, and required generated workspace.
6. One real `#Preview` that can serve as an exact launch probe.
7. Existing repository-local Skills and their naming and tool conventions.

Treat discovered values as evidence. Do not guess a scheme, bundle identifier, target, environment prefix, or app lifecycle from common iOS defaults.

## 2. Connect programmable startup

Reuse an existing host adapter when present. Otherwise implement the narrowest adapter that:

1. Calls `StorybookLaunchRequest(arguments: ProcessInfo.processInfo.arguments)` at the earliest root-selection boundary.
2. Keeps normal startup unchanged when the initializer returns `nil`.
3. Replaces the normal root with `Storybook` or `StorybookDisplayRootView` when a request exists.
4. Passes `.invalid` requests into Storybook so the diagnostic remains visible instead of silently falling back.
5. Builds the catalog from the project's existing pages and `Book.allBookPreviews()`.
6. Compiles only in the configurations where StorybookKit is linked.
7. Preserves an existing manual in-app Storybook entry independently of programmable startup.

Add host-specific options, such as a light/dark override, outside `StorybookLaunchRequest`. Parse them deterministically and convert invalid values into a visible `StorybookLaunchDiagnostic`.

## 3. Expose a project launcher interface

Prefer the project's existing simulator runner. Extend it with a stable uppercase prefix derived from the project, for example:

```text
<PREFIX>_STORYBOOK=1
<PREFIX>_STORYBOOK_PAGE_NAME=<exact preview name>
<PREFIX>_STORYBOOK_FILE_ID=<module/path/file.swift>
<PREFIX>_STORYBOOK_PAGE_LINE=<positive declaration line>
```

Add host-specific variables only when the project needs them. Preserve an explicitly set empty page name, validate dependent qualifiers, and append each launch argument as a separate array element. Never assemble shell-evaluated argument strings.

Support the repository's normal build-and-install path. When its tooling already supports relaunching an installed app without rebuilding, document that fast path in the generated Skill; otherwise state the actual build/install cost rather than inventing one.

## 4. Generate the project-local Skill

Create the Skill under the target repository's established skill root. Default to:

```text
.agents/skills/<project-slug>-storybook-visual-check
```

Copy [assets/project-skill-template](assets/project-skill-template) as the starting point. Replace every template placeholder, delete inapplicable optional sections, and keep the result project-specific.

Record concrete values for:

- repository root and prerequisite generation/setup;
- supported target, scheme, configuration, and bundle identifier;
- canonical runner command and environment variables;
- installed-app relaunch path, only when verified;
- exact page-name, file-ID, and line-selection behavior;
- appearance or locale controls owned by the host;
- hierarchy identifier and screenshot tool;
- cleanup requirements for device-interaction sessions;
- known unsupported variants and honest failure conditions.

Do not make the generated Skill another generic Storybook guide. It should remove repository discovery work from every future visual check.

## 5. Validate the integration and Skill

Validate in proportion to the changes:

1. Run the target repository's preferred incremental build for the host configuration.
2. Launch the catalog through the environment-variable interface.
3. Launch one exact preview by name, adding file ID and line if necessary.
4. Verify the exact `storybook.page|...` accessibility identifier before capturing a screenshot.
5. Confirm that launching without Storybook inputs still follows normal startup.
6. Validate the generated Skill with the available Skill validator.
7. Search for unresolved template placeholders and conflict markers.

If build, install, launch, exact selection, hierarchy verification, or screenshot capture cannot be completed, report the failed stage. Do not substitute a catalog launch, another page, or a build-only result for visual verification.

## 6. Report the result

Return:

- host integration files changed;
- environment-variable interface and exact example command;
- generated Skill path;
- supported and unsupported configurations;
- build and launch validation performed;
- screenshot artifact path when verification succeeded;
- any prerequisite the project still needs.
