#if canImport(UIKit)
import SwiftUI
import Testing
import UIKit

@testable import StorybookKit

@Suite("Storybook viewport renderer")
struct StorybookViewportTests {

  @MainActor
  @Test("An exact selector resolves the viewport page")
  func exactSelector() throws {
    guard #available(iOS 17.0, *) else { return }
    let viewport = try makeViewport {
      AnyView(Color.clear.frame(height: 10))
    }

    #expect(
      viewport.descriptor
        == .init(
          name: "Viewport test",
          fileID: "Tests/StorybookViewportTests.swift",
          line: "42"
        )
    )
  }

  @MainActor
  @Test("A controller preview resolves to a real presentation, not a viewport")
  func viewControllerPreviewUsesPresentationExport() throws {
    guard #available(iOS 17.0, *) else { return }
    let page = BookPage(
      fileID: "Tests/StorybookViewportTests.swift",
      line: 84,
      title: "Controller test",
      usesScrollView: false,
      destination: { AnyView(EmptyView()) },
      viewPortPreview: {
        .presentedViewController { UIViewController() }
      }
    )
    let store = BookStore(
      book: Book(title: "Tests") {
        page
      }
    )
    let selector = BookPageSelector(
      name: "Controller test",
      fileID: "Tests/StorybookViewportTests.swift",
      line: 84
    )

    let export = try StorybookPreviewExport(bookStore: store, selector: selector)
    guard case .presentedViewController(let controller) = export else {
      Issue.record("Expected a presented UIViewController export")
      return
    }
    #expect(controller.descriptor == page.descriptor)

    do {
      _ = try StorybookViewport(bookStore: store, selector: selector)
      Issue.record("Expected a UIViewController preview to reject viewport rendering")
    } catch let error as StorybookPreviewExportError {
      #expect(error == .requiresPresentedViewController)
    }
  }

  @MainActor
  @Test("A root scroll view renders beyond the supplied viewport width")
  func rootScrollViewUsesItsFullHeight() throws {
    guard #available(iOS 17.0, *) else { return }
    let viewport = try makeViewport {
      AnyView(
        ScrollView {
          VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { _ in
              Color.red.frame(height: 100)
            }
          }
        }
      )
    }

    let rendered = try StorybookViewportRenderer.render(
      viewport,
      width: 200,
      scale: 1,
      appearance: .light
    )

    #expect(rendered.pointSize == .init(width: 200, height: 800))
  }

  @MainActor
  @Test("An explicit appearance controls the off-screen host")
  func explicitAppearance() throws {
    guard #available(iOS 17.0, *) else { return }
    let viewport = try makeViewport {
      AnyView(Color(uiColor: .systemBackground).frame(height: 100))
    }

    let light = try StorybookViewportRenderer.render(
      viewport,
      width: 100,
      scale: 1,
      appearance: .light
    )
    let dark = try StorybookViewportRenderer.render(
      viewport,
      width: 100,
      scale: 1,
      appearance: .dark
    )

    #expect(light.image.pngData() != dark.image.pngData())
  }

  @MainActor
  @Test("Safe-area space is included in a fitted viewport")
  func safeAreaInsets() throws {
    guard #available(iOS 17.0, *) else { return }
    let viewport = try makeViewport {
      AnyView(Color.clear.frame(height: 100))
    }

    let rendered = try StorybookViewportRenderer.render(
      viewport,
      width: 100,
      scale: 1,
      safeAreaInsets: .init(top: 20, left: 0, bottom: 34, right: 0)
    )

    #expect(rendered.pointSize == .init(width: 100, height: 154))
  }

  @MainActor
  @Test("Invalid dimensions are rejected before drawing")
  func invalidDimensions() throws {
    guard #available(iOS 17.0, *) else { return }
    let viewport = try makeViewport {
      AnyView(Color.clear.frame(height: 100))
    }

    try expectError(.invalidWidth) {
      _ = try StorybookViewportRenderer.render(viewport, width: 0, scale: 1)
    }
    try expectError(.invalidScale) {
      _ = try StorybookViewportRenderer.render(viewport, width: 100, scale: 0)
    }
  }

  @MainActor
  @Test("The pixel guard rejects images before allocating a renderer")
  func maximumPixelCount() throws {
    guard #available(iOS 17.0, *) else { return }
    let viewport = try makeViewport {
      AnyView(Color.clear.frame(width: 1_000, height: 10_000))
    }

    try expectError(.tooLarge(maximumPixelCount: 32_000_000)) {
      _ = try StorybookViewportRenderer.render(viewport, width: 1_000, scale: 2)
    }
  }

  @MainActor
  @available(iOS 17.0, *)
  private func makeViewport(
    content: @escaping @MainActor () -> AnyView
  ) throws -> StorybookViewport {
    let store = BookStore(
      book: Book(title: "Tests") {
        BookPage(
          "Tests/StorybookViewportTests.swift",
          42,
          title: "Viewport test"
        ) {
          content()
        }
      }
    )
    return try StorybookViewport(
      bookStore: store,
      selector: .init(
        name: "Viewport test",
        fileID: "Tests/StorybookViewportTests.swift",
        line: 42
      )
    )
  }

  @MainActor
  @available(iOS 17.0, *)
  private func expectError(
    _ expected: StorybookViewportRenderError,
    operation: () throws -> Void
  ) throws {
    do {
      try operation()
      Issue.record("Expected \(expected)")
    } catch let error as StorybookViewportRenderError {
      #expect(error == expected)
    }
  }
}
#endif
