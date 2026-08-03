import CryptoKit
import Foundation
import StorybookKit
import SwiftUI

enum ViewportExportRequest {

  struct Request: Equatable {
    let exportID: String
    let appearance: StorybookViewportAppearance
  }

  case disabled
  case request(Request)
  case invalid(String)

  init(arguments: [String]) {
    let renderArguments = arguments.indices.filter {
      arguments[$0] == "--storybook-render"
    }
    guard renderArguments.isEmpty == false else {
      self = .disabled
      return
    }
    guard renderArguments.count == 1 else {
      self = .invalid("Viewport export accepts exactly one --storybook-render argument.")
      return
    }
    let renderValueIndex = arguments.index(after: renderArguments[0])
    guard arguments.indices.contains(renderValueIndex),
          arguments[renderValueIndex] == "viewport"
    else {
      self = .invalid("Viewport export requires --storybook-render viewport.")
      return
    }

    guard let exportID = Self.value(
      after: "--storybook-export-id",
      in: arguments
    ) else {
      self = .invalid("Viewport export requires one --storybook-export-id value.")
      return
    }
    guard exportID.isEmpty == false,
          exportID.unicodeScalars.allSatisfy({
            CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_"
          })
    else {
      self = .invalid(
        "Viewport export IDs may contain only letters, numbers, hyphens, and underscores."
      )
      return
    }

    guard let appearanceValue = Self.value(
      after: "--storybook-appearance",
      in: arguments
    ), let appearance = StorybookViewportAppearance(rawValue: appearanceValue) else {
      self = .invalid("Viewport export requires --storybook-appearance light or dark.")
      return
    }

    self = .request(.init(exportID: exportID, appearance: appearance))
  }

  private static func value(after argument: String, in arguments: [String]) -> String? {
    let indexes = arguments.indices.filter { arguments[$0] == argument }
    guard indexes.count == 1 else {
      return nil
    }
    let valueIndex = arguments.index(after: indexes[0])
    guard arguments.indices.contains(valueIndex) else {
      return nil
    }
    return arguments[valueIndex]
  }
}

struct StorybookViewportExportView: View {

  private enum ExportState {
    case preparing
    case viewport(StorybookViewport)
    case presentedViewController(StorybookPresentedViewController)
    case complete
    case failed(String)

    var accessibilityIdentifier: String {
      switch self {
      case .preparing:
        return "storybook.viewport.export.preparing"
      case .viewport, .presentedViewController:
        return "storybook.viewport.export.ready"
      case .complete:
        return "storybook.viewport.export.complete"
      case .failed:
        return "storybook.viewport.export.failure"
      }
    }
  }

  let selector: BookPageSelector
  let exportID: String
  let appearance: StorybookViewportAppearance

  @Environment(\.displayScale) private var displayScale
  @State private var state: ExportState = .preparing

  init(
    selector: BookPageSelector,
    exportID: String,
    appearance: StorybookViewportAppearance
  ) {
    self.selector = selector
    self.exportID = exportID
    self.appearance = appearance
  }

  var body: some View {
    GeometryReader { proxy in
      Group {
        switch state {
        case .preparing:
          ProgressView()
        case .viewport(let viewport):
          viewport
        case .presentedViewController(let preview):
          StorybookPresentedViewControllerExportHost(
            preview: preview,
            appearance: appearance,
            scale: displayScale,
            onImage: { image in
              finish(
                image,
                renderMode: .presentedViewController
              )
            },
            onFailure: { error in
              state = .failed(error.localizedDescription)
            }
          )
        case .complete:
          Color.clear
        case .failed(let message):
          ContentUnavailableView(
            "Viewport export failed",
            systemImage: "exclamationmark.triangle",
            description: Text(message)
          )
        }
      }
      .accessibilityIdentifier(state.accessibilityIdentifier)
      .task(id: proxy.size) {
        export(width: proxy.size.width, scale: displayScale)
      }
    }
  }

  @MainActor
  private func export(width: CGFloat, scale: CGFloat) {
    guard case .preparing = state else {
      return
    }

    do {
      let bookStore = BookStore(
        book: Book(title: "Contents") {
          Book.allBookPreviews() ?? []
        }
      )
      let preview = try StorybookPreviewExport(
        bookStore: bookStore,
        selector: selector
      )
      switch preview {
      case .viewport(let viewport):
        let rendered = try StorybookViewportRenderer.render(
          viewport,
          width: width,
          scale: scale,
          appearance: appearance
        )
        finish(rendered, renderMode: .viewport)
        state = .viewport(viewport)
      case .presentedViewController(let controller):
        state = .presentedViewController(controller)
      }
    } catch {
      state = .failed(error.localizedDescription)
    }
  }

  @MainActor
  private func finish(
    _ rendered: StorybookExportImage,
    renderMode: StorybookImageRenderMode
  ) {
    do {
      try StorybookViewportArtifact.write(
        rendered,
        exportID: exportID,
        appearance: appearance,
        renderMode: renderMode
      )
      if case .presentedViewController = state {
        state = .complete
      }
    } catch {
      state = .failed(error.localizedDescription)
    }
  }
}

struct StorybookViewportExportFailureView: View {

  let message: String

  var body: some View {
    ContentUnavailableView(
      "Viewport export failed",
      systemImage: "exclamationmark.triangle",
      description: Text(message)
    )
    .accessibilityIdentifier("storybook.viewport.export.failure")
  }
}

private struct StorybookViewportArtifact: Codable {

  let schemaVersion: Int
  let exportID: String
  let name: String
  let fileID: String
  let line: String
  let renderMode: StorybookImageRenderMode
  let appearance: StorybookViewportAppearance
  let pointWidth: Double
  let pointHeight: Double
  let pixelWidth: Double
  let pixelHeight: Double
  let sha256: String

  static func write(
    _ rendered: StorybookExportImage,
    exportID: String,
    appearance: StorybookViewportAppearance,
    renderMode: StorybookImageRenderMode
  ) throws {
    guard let pngData = rendered.image.pngData() else {
      throw ExportError.pngEncodingFailed
    }

    let fileManager = FileManager.default
    let applicationSupport = try fileManager.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let directory = applicationSupport
      .appendingPathComponent("StorybookViewportExports", isDirectory: true)
      .appendingPathComponent(exportID, isDirectory: true)
    try fileManager.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )

    let imageURL = directory.appendingPathComponent("image.png")
    try pngData.write(to: imageURL, options: .atomic)

    let artifact = Self(
      schemaVersion: 1,
      exportID: exportID,
      name: rendered.descriptor.name,
      fileID: rendered.descriptor.fileID,
      line: rendered.descriptor.line,
      renderMode: renderMode,
      appearance: appearance,
      pointWidth: rendered.pointSize.width,
      pointHeight: rendered.pointSize.height,
      pixelWidth: rendered.pixelSize.width,
      pixelHeight: rendered.pixelSize.height,
      sha256: SHA256.hash(data: pngData)
        .map { String(format: "%02x", $0) }
        .joined()
    )
    let manifestURL = directory.appendingPathComponent("manifest.json")
    try JSONEncoder().encode(artifact).write(to: manifestURL, options: .atomic)
  }

  private enum ExportError: LocalizedError {
    case pngEncodingFailed

    var errorDescription: String? {
      switch self {
      case .pngEncodingFailed:
        return "Viewport renderer could not encode PNG data."
      }
    }
  }
}

private enum StorybookImageRenderMode: String, Codable {
  case viewport
  case presentedViewController
}
