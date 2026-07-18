import Testing

@testable import StorybookKit

@Suite("Storybook launch requests")
struct StorybookLaunchRequestTests {

  @Test("Normal application arguments do not request Storybook")
  func noStorybookArgument() {
    #expect(
      StorybookLaunchRequest(
        arguments: ["ExampleApp", "-AppleLanguages", "(en)"]
      ) == nil
    )
  }

  @Test("The Storybook argument opens the catalog")
  func catalogRequest() {
    #expect(
      StorybookLaunchRequest(
        arguments: ["ExampleApp", "--storybook", "-AppleLanguages", "(en)"]
      ) == .catalog
    )
  }

  @Test("A page request preserves its exact name")
  func pageRequest() {
    #expect(
      StorybookLaunchRequest(
        arguments: ["ExampleApp", "--storybook", " AssetImage "]
      ) == .page(.init(name: " AssetImage "))
    )
  }

  @Test("The explicit name form preserves empty and hyphen-led names")
  func explicitPageName() {
    #expect(
      StorybookLaunchRequest(
        arguments: ["ExampleApp", "--storybook", "--storybook-name=- Dark"]
      ) == .page(.init(name: "- Dark"))
    )
    #expect(
      StorybookLaunchRequest(
        arguments: ["ExampleApp", "--storybook", "--storybook-name="]
      ) == .page(.init(name: ""))
    )
  }

  @Test("The explicit and shorthand name forms are mutually exclusive")
  func duplicatePageNameForms() {
    #expect(
      StorybookLaunchRequest(
        arguments: [
          "ExampleApp", "--storybook", "Page", "--storybook-name=Other",
        ]
      )
        == .invalid(
          .init(
            message:
              "Specify the page name either after --storybook or with --storybook-name, not both."
          )
        )
    )
    #expect(
      StorybookLaunchRequest(
        arguments: [
          "ExampleApp", "--storybook", "--storybook-name=First",
          "--storybook-name=Second",
        ]
      )
        == .invalid(
          .init(message: "--storybook-name may only be specified once.")
        )
    )
    #expect(
      StorybookLaunchRequest(
        arguments: ["ExampleApp", "--storybook", "--storybook-name"]
      )
        == .invalid(
          .init(message: "--storybook-name requires =<page-name>.")
        )
    )
  }

  @Test("Selector launch arguments round-trip exact names and qualifiers")
  func selectorLaunchArguments() {
    let selectors = [
      BookPageSelector(name: "Page with spaces"),
      BookPageSelector(name: ""),
      BookPageSelector(name: "- Dark"),
      BookPageSelector(
        name: "Qualified",
        fileID: "Feature/Component.swift",
        line: UInt64.max
      ),
    ]

    for selector in selectors {
      #expect(
        StorybookLaunchRequest(
          arguments: ["ExampleApp"] + selector.launchArguments
        ) == .page(selector)
      )
    }
  }

  @Test("File and line arguments qualify a page request")
  func qualifiedPageRequest() {
    #expect(
      StorybookLaunchRequest(
        arguments: [
          "ExampleApp",
          "--storybook-file",
          "AppResource/AssetImage.swift",
          "--storybook",
          "AssetImage",
          "--storybook-line",
          "42",
          "-UnrelatedArgument",
        ]
      )
        == .page(
          .init(
            name: "AssetImage",
            fileID: "AppResource/AssetImage.swift",
            line: 42
          )
        )
    )
  }

  @Test(
    "Duplicate supported arguments are rejected",
    arguments: [
      StorybookLaunchRequest.storybookArgument,
      StorybookLaunchRequest.fileArgument,
      StorybookLaunchRequest.lineArgument,
    ]
  )
  func duplicateArgument(argument: String) {
    let arguments: [String]
    switch argument {
    case StorybookLaunchRequest.storybookArgument:
      arguments = ["ExampleApp", argument, argument]
    case StorybookLaunchRequest.fileArgument:
      arguments = [
        "ExampleApp", "--storybook", "Page", argument, "A.swift", argument, "B.swift",
      ]
    default:
      arguments = [
        "ExampleApp", "--storybook", "Page", "--storybook-file", "A.swift",
        argument, "10", argument, "20",
      ]
    }

    #expect(
      StorybookLaunchRequest(arguments: arguments)
        == .invalid(
          .init(message: "\(argument) may only be specified once.")
        )
    )
  }

  @Test("File and line arguments require values")
  func missingQualifierValues() {
    #expect(
      StorybookLaunchRequest(
        arguments: ["ExampleApp", "--storybook", "Page", "--storybook-file"]
      )
        == .invalid(
          .init(message: "--storybook-file requires a file identifier.")
        )
    )
    #expect(
      StorybookLaunchRequest(
        arguments: [
          "ExampleApp", "--storybook", "Page", "--storybook-file", "A.swift",
          "--storybook-line",
        ]
      )
        == .invalid(
          .init(message: "--storybook-line requires a positive integer.")
        )
    )
  }

  @Test("Line arguments require positive integers")
  func invalidLineValues() {
    for value in ["zero", "0", "-1"] {
      #expect(
        StorybookLaunchRequest(
          arguments: [
            "ExampleApp", "--storybook", "Page", "--storybook-file", "A.swift",
            "--storybook-line", value,
          ]
        )
          == .invalid(
            .init(
              message: "--storybook-line requires a positive integer; received \"\(value)\"."
            )
          )
      )
    }
  }

  @Test("Line arguments normalize without platform integer narrowing")
  func wideLineValue() {
    #expect(
      StorybookLaunchRequest(
        arguments: [
          "ExampleApp", "--storybook", "Page", "--storybook-file", "A.swift",
          "--storybook-line", "+00018446744073709551615",
        ]
      )
        == .page(
          .init(
            name: "Page",
            fileID: "A.swift",
            line: UInt64.max
          )
        )
    )
  }

  @Test("A file qualifier requires a page name")
  func fileRequiresName() {
    #expect(
      StorybookLaunchRequest(
        arguments: ["ExampleApp", "--storybook", "--storybook-file", "A.swift"]
      )
        == .invalid(
          .init(message: "--storybook-file requires a Storybook page name.")
        )
    )
  }

  @Test("A line qualifier requires both a page name and file qualifier")
  func lineDependencies() {
    #expect(
      StorybookLaunchRequest(
        arguments: ["ExampleApp", "--storybook", "--storybook-line", "10"]
      )
        == .invalid(
          .init(
            message: "--storybook-line requires a Storybook page name and --storybook-file."
          )
        )
    )
    #expect(
      StorybookLaunchRequest(
        arguments: ["ExampleApp", "--storybook", "Page", "--storybook-line", "10"]
      )
        == .invalid(
          .init(message: "--storybook-line requires --storybook-file.")
        )
    )
  }
}
