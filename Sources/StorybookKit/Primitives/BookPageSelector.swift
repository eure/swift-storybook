import Foundation

/// The source metadata that identifies a page within a Storybook catalog.
///
/// A descriptor preserves the exact strings emitted by the compiler. Storybook
/// compares names and file identifiers byte-for-byte so that distinct previews
/// are never merged by case folding or whitespace normalization.
public struct BookPageDescriptor: Equatable, Hashable, Sendable {

  /// The page name displayed by Storybook.
  public let name: String

  /// The compiler-emitted file identifier that declares the page.
  public let fileID: String

  /// The source line that declares the page.
  ///
  /// This is stored as text to preserve source compatibility with
  /// `BookPage`'s existing `FixedWidthInteger` initializer without trapping
  /// when a caller supplies a value outside the platform `Int` range.
  public let line: String

  /// A deterministic accessibility identifier for a successfully opened page.
  ///
  /// Automation can compare this value with the accessibility hierarchy to
  /// prove that a source-qualified request opened the intended page.
  public var accessibilityIdentifier: String {
    "storybook.page|\(name.utf8.count):\(name)|\(fileID.utf8.count):\(fileID)|\(line)"
  }

  /// Creates source metadata for a Storybook page.
  ///
  /// - Parameters:
  ///   - name: The page name displayed by Storybook.
  ///   - fileID: The compiler-emitted file identifier that declares the page.
  ///   - line: The source line that declares the page.
  public init(
    name: String,
    fileID: String,
    line: String
  ) {
    self.name = name
    self.fileID = fileID
    self.line = line
  }

  /// Returns whether this descriptor exactly matches the supplied selector.
  ///
  /// Every qualifier supplied by the selector must match. A selector without a
  /// file identifier matches pages by name alone, while a selector with a line
  /// also requires the source line to match.
  func matches(_ selector: BookPageSelector) -> Bool {
    guard name.hasSameUTF8(as: selector.name) else {
      return false
    }

    guard let fileID = selector.fileID else {
      return true
    }
    guard self.fileID.hasSameUTF8(as: fileID) else {
      return false
    }

    guard let line = selector.line else {
      return true
    }
    return self.line == line
  }

  public static func == (
    lhs: BookPageDescriptor,
    rhs: BookPageDescriptor
  ) -> Bool {
    lhs.name.hasSameUTF8(as: rhs.name)
      && lhs.fileID.hasSameUTF8(as: rhs.fileID)
      && lhs.line == rhs.line
  }

  public func hash(into hasher: inout Hasher) {
    name.hashUTF8(into: &hasher)
    fileID.hashUTF8(into: &hasher)
    hasher.combine(line)
  }
}

/// An exact query for a page in a Storybook catalog.
///
/// Use a name-only selector when a page name is unique. Add a file identifier
/// when the same name appears in multiple files, and add a line only when
/// multiple pages in one file intentionally share the same name. Source lines
/// can change as code is edited, so they should be the final disambiguator.
public struct BookPageSelector: Equatable, Hashable, Sendable {

  /// The exact page name to match.
  public let name: String

  /// The exact compiler-emitted file identifier to match, when supplied.
  public let fileID: String?

  /// The exact source line to match, when supplied.
  ///
  /// The value is stored as text so selectors accept the same
  /// `FixedWidthInteger` range as `BookPage` without a narrowing conversion.
  public let line: String?

  /// Creates a selector that matches pages by their exact name.
  ///
  /// - Parameter name: The page name displayed by Storybook.
  public init(name: String) {
    self.name = name
    self.fileID = nil
    self.line = nil
  }

  /// Creates a selector qualified by source file and, optionally, source line.
  ///
  /// - Parameters:
  ///   - name: The exact page name to match.
  ///   - fileID: The exact compiler-emitted file identifier to match.
  ///   - line: The source line to match. Omit this unless pages with the same
  ///     name coexist in the same file.
  public init(
    name: String,
    fileID: String,
    line: (any FixedWidthInteger)? = nil
  ) {
    self.name = name
    self.fileID = fileID
    self.line = line.map { String(describing: $0) }
  }

  init(
    name: String,
    fileID: String,
    normalizedLine: String
  ) {
    self.name = name
    self.fileID = fileID
    self.line = normalizedLine
  }

  public static func == (
    lhs: BookPageSelector,
    rhs: BookPageSelector
  ) -> Bool {
    guard lhs.name.hasSameUTF8(as: rhs.name), lhs.line == rhs.line else {
      return false
    }

    switch (lhs.fileID, rhs.fileID) {
    case (.none, .none):
      return true
    case (.some(let lhsFileID), .some(let rhsFileID)):
      return lhsFileID.hasSameUTF8(as: rhsFileID)
    case (.none, .some), (.some, .none):
      return false
    }
  }

  public func hash(into hasher: inout Hasher) {
    name.hashUTF8(into: &hasher)
    switch fileID {
    case .some(let fileID):
      hasher.combine(true)
      fileID.hashUTF8(into: &hasher)
    case .none:
      hasher.combine(false)
    }
    hasher.combine(line)
  }
}

/// An error produced when a Storybook page selector cannot resolve one page.
public enum BookPageResolutionError: Error, Equatable, Sendable {

  /// No page matched the selector.
  ///
  /// Candidates contain pages with the requested name when Storybook can offer
  /// a more specific file or line qualifier.
  case notFound(
    selector: BookPageSelector,
    candidates: [BookPageDescriptor]
  )

  /// More than one page matched the selector.
  ///
  /// Use the candidate metadata to construct a more specific selector.
  case ambiguous(
    selector: BookPageSelector,
    candidates: [BookPageDescriptor]
  )
}

extension String {

  fileprivate func hasSameUTF8(as other: String) -> Bool {
    utf8.elementsEqual(other.utf8)
  }

  fileprivate func hashUTF8(into hasher: inout Hasher) {
    hasher.combine(utf8.count)
    for byte in utf8 {
      hasher.combine(byte)
    }
  }
}
