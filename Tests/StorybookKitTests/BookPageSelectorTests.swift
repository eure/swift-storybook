import SwiftUI
import Testing

@testable import StorybookKit

@Suite("Book page selectors")
struct BookPageSelectorTests {

  @Test("A name-only selector matches the exact name")
  func nameOnlySelector() {
    let descriptor = BookPageDescriptor(
      name: "AssetImage",
      fileID: "AppResource/AssetImage.swift",
      line: "42"
    )

    #expect(descriptor.matches(.init(name: "AssetImage")))
    #expect(descriptor.matches(.init(name: "assetimage")) == false)
    #expect(descriptor.matches(.init(name: " AssetImage ")) == false)
    #expect(
      descriptor.accessibilityIdentifier
        == "storybook.page|10:AssetImage|28:AppResource/AssetImage.swift|42"
    )
  }

  @Test("A file-qualified selector matches every supplied qualifier")
  func fileQualifiedSelector() {
    let descriptor = BookPageDescriptor(
      name: "Shared Name",
      fileID: "Feature/Component.swift",
      line: "10"
    )

    #expect(
      descriptor.matches(
        .init(name: "Shared Name", fileID: "Feature/Component.swift")
      )
    )
    #expect(
      descriptor.matches(
        .init(name: "Shared Name", fileID: "feature/Component.swift")
      ) == false
    )
  }

  @Test("A line-qualified selector is the final disambiguator")
  func lineQualifiedSelector() {
    let descriptor = BookPageDescriptor(
      name: "Shared Name",
      fileID: "Feature/Component.swift",
      line: "10"
    )

    #expect(
      descriptor.matches(
        .init(
          name: "Shared Name",
          fileID: "Feature/Component.swift",
          line: 10
        )
      )
    )
    #expect(
      descriptor.matches(
        .init(
          name: "Shared Name",
          fileID: "Feature/Component.swift",
          line: 11
        )
      ) == false
    )
  }

  @Test("Resolution errors preserve selectors and deterministic candidates")
  func resolutionErrorMetadata() {
    let selector = BookPageSelector(name: "Shared Name")
    let candidates = [
      BookPageDescriptor(
        name: "Shared Name",
        fileID: "Feature/First.swift",
        line: "10"
      ),
      BookPageDescriptor(
        name: "Shared Name",
        fileID: "Feature/Second.swift",
        line: "20"
      ),
    ]

    #expect(
      BookPageResolutionError.ambiguous(
        selector: selector,
        candidates: candidates
      )
        == .ambiguous(
          selector: selector,
          candidates: candidates
        )
    )
    #expect(
      BookPageResolutionError.notFound(
        selector: selector,
        candidates: []
      )
        == .notFound(
          selector: selector,
          candidates: []
        )
    )
  }

  @MainActor
  @Test("A unique name resolves its page")
  func uniqueNameResolution() throws {
    let store = makeStore()

    let page = try store.resolve(.init(name: "Unique"))

    #expect(page.descriptor.fileID == "Feature/Unique.swift")
  }

  @MainActor
  @Test("Duplicate names return deterministic source candidates")
  func ambiguousNameResolution() {
    let store = makeStore()
    let selector = BookPageSelector(name: "Shared")

    do {
      _ = try store.resolve(selector)
      Issue.record("Expected duplicate names to be ambiguous")
    } catch let error as BookPageResolutionError {
      #expect(
        error
          == .ambiguous(
            selector: selector,
            candidates: [
              .init(name: "Shared", fileID: "Feature/First.swift", line: "10"),
              .init(name: "Shared", fileID: "Feature/Second.swift", line: "20"),
            ]
          )
      )
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @MainActor
  @Test("File and line qualifiers resolve duplicate names")
  func qualifiedResolution() throws {
    let store = makeStore()

    let page = try store.resolve(
      .init(
        name: "Shared",
        fileID: "Feature/Second.swift",
        line: 20
      )
    )

    #expect(page.descriptor.line == "20")
  }

  @MainActor
  @Test("A wrong line reports candidates from the matched file")
  func wrongLineResolution() {
    let store = makeStore()
    let selector = BookPageSelector(
      name: "Shared",
      fileID: "Feature/Second.swift",
      line: 21
    )

    do {
      _ = try store.resolve(selector)
      Issue.record("Expected the unmatched line to fail")
    } catch let error as BookPageResolutionError {
      #expect(
        error
          == .notFound(
            selector: selector,
            candidates: [
              .init(name: "Shared", fileID: "Feature/Second.swift", line: "20")
            ]
          )
      )
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test("Canonically equivalent strings remain byte-distinct")
  func unicodeNormalizationIsNotMerged() {
    let composed = "\u{00E9}"
    let decomposed = "e\u{0301}"
    let descriptor = BookPageDescriptor(
      name: composed,
      fileID: "Feature/Unicode.swift",
      line: "10"
    )

    #expect(composed == decomposed)
    #expect(descriptor.matches(.init(name: decomposed)) == false)
    #expect(
      descriptor
        != BookPageDescriptor(
          name: decomposed,
          fileID: "Feature/Unicode.swift",
          line: "10"
        )
    )
  }

  @MainActor
  @Test("Selectors preserve integer lines outside the platform Int range")
  func wideIntegerLine() throws {
    let store = BookStore(
      book: Book(title: "Tests") {
        BookPage(
          "Feature/WideInteger.swift",
          UInt64.max,
          title: "Wide integer"
        ) {
          Text("Content")
        }
      }
    )

    let page = try store.resolve(
      .init(
        name: "Wide integer",
        fileID: "Feature/WideInteger.swift",
        line: UInt64.max
      )
    )

    #expect(page.descriptor.line == String(UInt64.max))
  }

  @MainActor
  private func makeStore() -> BookStore {
    BookStore(
      book: Book(title: "Tests") {
        BookPage("Feature/Second.swift", 20, title: "Shared") {
          Text("Second")
        }
        BookPage("Feature/Unique.swift", 30, title: "Unique") {
          Text("Unique")
        }
        BookPage("Feature/First.swift", 10, title: "Shared") {
          Text("First")
        }
      }
    )
  }
}
