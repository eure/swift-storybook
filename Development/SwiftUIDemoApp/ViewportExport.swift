import CryptoKit
import Foundation
import StorybookKit
import SwiftUI
import UIKit

enum ViewportExportRequest {

  struct Request: Equatable {
    let exportID: String
    let appearance: StorybookViewportAppearance
  }

  case disabled
  case request(Request)
  case invalid(message: String, exportID: String?)

  var exportID: String? {
    switch self {
    case .disabled:
      nil
    case .request(let request):
      request.exportID
    case .invalid(_, let exportID):
      exportID
    }
  }

  init(arguments: [String]) {
    let validExportID = Self.validExportID(in: arguments)
    let renderArguments = arguments.indices.filter {
      arguments[$0] == "--storybook-render"
    }
    guard renderArguments.isEmpty == false else {
      self = .disabled
      return
    }
    guard renderArguments.count == 1 else {
      self = .invalid(
        message: "Viewport export accepts exactly one --storybook-render argument.",
        exportID: validExportID
      )
      return
    }
    let renderValueIndex = arguments.index(after: renderArguments[0])
    guard arguments.indices.contains(renderValueIndex),
          arguments[renderValueIndex] == "viewport"
    else {
      self = .invalid(
        message: "Viewport export requires --storybook-render viewport.",
        exportID: validExportID
      )
      return
    }

    guard let exportID = Self.value(
      after: "--storybook-export-id",
      in: arguments
    ) else {
      self = .invalid(
        message: "Viewport export requires one --storybook-export-id value.",
        exportID: validExportID
      )
      return
    }
    guard exportID.isEmpty == false,
          exportID.unicodeScalars.allSatisfy({
            CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_"
          })
    else {
      self = .invalid(
        message: "Viewport export IDs may contain only letters, numbers, hyphens, and underscores.",
        exportID: validExportID
      )
      return
    }

    guard let appearanceValue = Self.value(
      after: "--storybook-appearance",
      in: arguments
    ), let appearance = StorybookViewportAppearance(rawValue: appearanceValue) else {
      self = .invalid(
        message: "Viewport export requires --storybook-appearance light or dark.",
        exportID: validExportID
      )
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

  private static func validExportID(in arguments: [String]) -> String? {
    guard let exportID = value(after: "--storybook-export-id", in: arguments),
          exportID.isEmpty == false,
          exportID.unicodeScalars.allSatisfy({
            CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_"
          })
    else {
      return nil
    }
    return exportID
  }
}

struct StorybookViewportExportView: View {

  private enum ExportState {
    case preparing
    case viewport(StorybookViewport)
    case uiView(StorybookUIView)
    case presentedViewController(StorybookPresentedViewController)
    case complete
    case failed(String)

    var accessibilityIdentifier: String {
      switch self {
      case .preparing:
        return "storybook.viewport.export.preparing"
      case .viewport, .uiView, .presentedViewController:
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
          StorybookSwiftUIExportHost(
            viewport: viewport,
            appearance: appearance,
            scale: displayScale,
            safeAreaInsets: viewportInsets(from: proxy.safeAreaInsets),
            onImage: { image in
              complete(image, renderMode: .viewport)
            },
            onFailure: { error in
              state = .failed(error.localizedDescription)
            }
          )
        case .uiView(let preview):
          StorybookUIViewExportHost(
            preview: preview,
            appearance: appearance,
            scale: displayScale,
            safeAreaInsets: viewportInsets(from: proxy.safeAreaInsets),
            onImage: { image in
              complete(image, renderMode: .viewport)
            },
            onFailure: { error in
              state = .failed(error.localizedDescription)
            }
          )
        case .presentedViewController(let preview):
          StorybookPresentedViewControllerExportHost(
            preview: preview,
            appearance: appearance,
            scale: displayScale,
            onImage: { image in
              complete(
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
        export()
      }
    }
  }

  @MainActor
  private func export() {
    guard case .preparing = state else {
      return
    }

    do {
      try StorybookViewportArtifact.prepare(exportID: exportID)
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
        state = .viewport(viewport)
      case .uiView(let view):
        state = .uiView(view)
      case .presentedViewController(let controller):
        state = .presentedViewController(controller)
      }
    } catch {
      state = .failed(error.localizedDescription)
    }
  }

  private func viewportInsets(from insets: EdgeInsets) -> UIEdgeInsets {
    .init(
      top: max(insets.top, 16),
      left: insets.leading,
      bottom: max(insets.bottom, 16),
      right: insets.trailing
    )
  }

  @MainActor
  private func complete(
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
      state = .complete
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

struct StorybookViewportArtifact: Codable {

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

  static func prepare(exportID: String) throws {
    let fileManager = FileManager.default
    let directory = try exportDirectory(
      exportID: exportID,
      fileManager: fileManager
    )
    for fileName in ["image.png", "manifest.json"] {
      let url = directory.appendingPathComponent(fileName)
      guard fileManager.fileExists(atPath: url.path) else {
        continue
      }
      try fileManager.removeItem(at: url)
    }
  }

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
    let directory = try exportDirectory(
      exportID: exportID,
      fileManager: fileManager
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

  private static func exportDirectory(
    exportID: String,
    fileManager: FileManager
  ) throws -> URL {
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
    return directory
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

enum StorybookImageRenderMode: String, Codable {
  case viewport
  case presentedViewController
}
