---
name: {{SKILL_NAME}}
description: "Launch and visually verify an exact StorybookKit page in {{PROJECT_NAME}} using the repository's supported build, install, and simulator workflow. Use after UI changes, when checking a #Preview or BookPage, or when source qualifiers are needed to select a duplicate page name."
---

# {{PROJECT_NAME}} Storybook Visual Check

Use the host app's programmable Storybook startup to open one exact page and capture trustworthy Simulator evidence.

## Project contract

- Repository: `{{REPOSITORY_ROOT}}`
- Workspace or project: `{{WORKSPACE_OR_PROJECT}}`
- Scheme: `{{SCHEME}}`
- Configuration: `{{CONFIGURATION}}`
- Bundle identifier: `{{BUNDLE_IDENTIFIER}}`
- Supported variants: {{SUPPORTED_VARIANTS}}
- Setup prerequisite: `{{SETUP_COMMAND}}`
- Canonical runner: `{{RUNNER_COMMAND}}`

Do not substitute another target, configuration, bundle identifier, or generic build command.

## Select the page

Find the requested `#Preview` or `BookPage` in source. Start with its exact display name. Add the compiler `#fileID`, then the declaration line when the name is duplicated.

Use these launcher variables:

```text
{{ENV_PREFIX}}_STORYBOOK=1
{{ENV_PREFIX}}_STORYBOOK_PAGE_NAME=<exact page name>
{{ENV_PREFIX}}_STORYBOOK_FILE_ID=<module/path/file.swift>
{{ENV_PREFIX}}_STORYBOOK_PAGE_LINE=<positive declaration line>
{{OPTIONAL_HOST_VARIABLES}}
```

Do not trim, normalize, fuzzy-match, or guess values. Preserve an explicitly empty page name.

## Build, install, and launch

Open the catalog:

```bash
env {{ENV_PREFIX}}_STORYBOOK=1 {{RUNNER_COMMAND}}
```

Open an exact page:

```bash
env \
  {{ENV_PREFIX}}_STORYBOOK_PAGE_NAME='{{EXAMPLE_PAGE_NAME}}' \
  {{ENV_PREFIX}}_STORYBOOK_FILE_ID='{{EXAMPLE_FILE_ID}}' \
  {{ENV_PREFIX}}_STORYBOOK_PAGE_LINE='{{EXAMPLE_LINE}}' \
  {{RUNNER_COMMAND}}
```

{{INSTALLED_APP_FAST_PATH}}

Use the repository's supported simulator selection. Preserve inherited launch arguments required by its scheme or runner.

## Verify before capture

1. Wait for the UI to settle.
2. Inspect the hierarchy for `storybook.page|<name-byte-count>:<name>|<fileID-byte-count>:<fileID>|<line>`.
3. Confirm the requested content is visible.
4. Reject `storybook.launch.failure`, normal app startup, catalog fallback, or another same-name page.
5. Check clipping, overlap, missing content, unexpected loading, and incorrect presentation.
6. Capture a screenshot only after exact hierarchy verification succeeds.
7. End any device-interaction session after capture or failure.

Save evidence under `{{ARTIFACT_DIRECTORY}}` and report the selector and screenshot path.

## Fail honestly

Stop at the failed stage when setup, build, install, launch, exact selection, hierarchy verification, or capture fails. Report the concrete diagnostic and do not substitute a build-only result or another page.

Known constraints:

{{KNOWN_CONSTRAINTS}}
