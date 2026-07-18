import Foundation

/// A user-facing diagnostic produced while parsing Storybook launch arguments.
public struct StorybookLaunchDiagnostic: Error, Equatable, Sendable {

  /// A description of the invalid launch arguments and how to correct them.
  public let message: String

  /// Creates a launch diagnostic with a user-facing message.
  ///
  /// - Parameter message: A description of the invalid launch arguments.
  public init(message: String) {
    self.message = message
  }
}

/// A request to launch the Storybook catalog or one exact page.
///
/// Initialize a request with the host process arguments. The initializer
/// returns `nil` when `--storybook` is absent so the host can continue its
/// normal startup path. Unrelated arguments are ignored.
public enum StorybookLaunchRequest: Equatable, Sendable {

  /// The argument that enables the Storybook startup path.
  public static let storybookArgument = "--storybook"

  /// The explicit argument prefix for page names that cannot use shorthand.
  ///
  /// Pass the complete argument as `--storybook-name=<page-name>`. This form
  /// can represent empty names and names beginning with a hyphen without
  /// consuming unrelated host application arguments.
  public static let nameArgument = "--storybook-name"

  /// The optional argument that qualifies a page name by source file.
  public static let fileArgument = "--storybook-file"

  /// The optional argument that qualifies a page name and file by source line.
  public static let lineArgument = "--storybook-line"

  /// Opens the Storybook catalog.
  case catalog

  /// Opens the one page that exactly matches the selector.
  case page(BookPageSelector)

  /// Displays a diagnostic instead of opening a potentially unintended page.
  case invalid(StorybookLaunchDiagnostic)

  /// Parses a Storybook request from host process arguments.
  ///
  /// Pass `--storybook` to open the catalog or place a page name immediately
  /// after it. Use `--storybook-name=<page-name>` for an empty or hyphen-led
  /// name. Use `--storybook-file` and `--storybook-line` to disambiguate
  /// duplicate names. Every supported argument may appear at most once.
  ///
  /// - Parameter arguments: The process arguments, including unrelated host
  ///   application arguments.
  /// - Returns: `nil` when `--storybook` is absent.
  public init?(arguments: [String]) {
    guard let storybookIndex = arguments.firstIndex(of: Self.storybookArgument) else {
      return nil
    }

    let explicitNamePrefix = "\(Self.nameArgument)="
    let explicitNameArguments = arguments.filter { argument in
      argument == Self.nameArgument || argument.hasPrefix(explicitNamePrefix)
    }
    guard explicitNameArguments.count <= 1 else {
      self = .invalid(
        .init(message: "\(Self.nameArgument) may only be specified once.")
      )
      return
    }
    if explicitNameArguments.first == Self.nameArgument {
      self = .invalid(
        .init(message: "\(Self.nameArgument) requires =<page-name>.")
      )
      return
    }

    for argument in [
      Self.storybookArgument,
      Self.fileArgument,
      Self.lineArgument,
    ] where arguments.filter({ $0 == argument }).count > 1 {
      self = .invalid(
        .init(message: "\(argument) may only be specified once.")
      )
      return
    }

    let positionalName = Self.optionalPageName(
      after: storybookIndex,
      in: arguments
    )
    let explicitName = explicitNameArguments.first.map { argument in
      String(argument.dropFirst(explicitNamePrefix.count))
    }
    if positionalName != nil, explicitName != nil {
      self = .invalid(
        .init(
          message:
            "Specify the page name either after \(Self.storybookArgument) or with \(Self.nameArgument), not both."
        )
      )
      return
    }
    let name = explicitName ?? positionalName

    let fileID: String?
    if let fileIndex = arguments.firstIndex(of: Self.fileArgument) {
      guard let value = Self.requiredValue(after: fileIndex, in: arguments) else {
        self = .invalid(
          .init(message: "\(Self.fileArgument) requires a file identifier.")
        )
        return
      }
      fileID = value
    } else {
      fileID = nil
    }

    let line: String?
    if let lineIndex = arguments.firstIndex(of: Self.lineArgument) {
      guard let value = Self.lineValue(after: lineIndex, in: arguments) else {
        self = .invalid(
          .init(message: "\(Self.lineArgument) requires a positive integer.")
        )
        return
      }
      guard let normalizedLine = Self.normalizedPositiveInteger(value) else {
        self = .invalid(
          .init(
            message: "\(Self.lineArgument) requires a positive integer; received \"\(value)\"."
          )
        )
        return
      }
      line = normalizedLine
    } else {
      line = nil
    }

    guard let name else {
      if fileID != nil {
        self = .invalid(
          .init(message: "\(Self.fileArgument) requires a Storybook page name.")
        )
        return
      }
      if line != nil {
        self = .invalid(
          .init(
            message: "\(Self.lineArgument) requires a Storybook page name and \(Self.fileArgument)."
          )
        )
        return
      }

      self = .catalog
      return
    }

    if line != nil, fileID == nil {
      self = .invalid(
        .init(message: "\(Self.lineArgument) requires \(Self.fileArgument).")
      )
      return
    }

    if let fileID {
      if let line {
        self = .page(
          .init(
            name: name,
            fileID: fileID,
            normalizedLine: line
          )
        )
      } else {
        self = .page(.init(name: name, fileID: fileID))
      }
    } else {
      self = .page(.init(name: name))
    }
  }

  private static func optionalPageName(
    after index: Int,
    in arguments: [String]
  ) -> String? {
    let valueIndex = arguments.index(after: index)
    guard arguments.indices.contains(valueIndex) else {
      return nil
    }

    let value = arguments[valueIndex]
    guard value.isEmpty == false, value.hasPrefix("-") == false else {
      return nil
    }
    return value
  }

  private static func requiredValue(
    after index: Int,
    in arguments: [String]
  ) -> String? {
    let valueIndex = arguments.index(after: index)
    guard arguments.indices.contains(valueIndex) else {
      return nil
    }

    let value = arguments[valueIndex]
    guard value.isEmpty == false, value.hasPrefix("-") == false else {
      return nil
    }
    return value
  }

  private static func lineValue(
    after index: Int,
    in arguments: [String]
  ) -> String? {
    let valueIndex = arguments.index(after: index)
    guard arguments.indices.contains(valueIndex) else {
      return nil
    }

    let value = arguments[valueIndex]
    guard value.isEmpty == false, value.hasPrefix("--") == false else {
      return nil
    }
    return value
  }

  /// Normalizes a decimal source line without narrowing it to a platform Int.
  private static func normalizedPositiveInteger(_ value: String) -> String? {
    let digits = value.first == "+" ? value.dropFirst() : value[...]
    guard digits.isEmpty == false else {
      return nil
    }
    guard digits.unicodeScalars.allSatisfy({ scalar in
      (48...57).contains(scalar.value)
    }) else {
      return nil
    }

    let significantDigits = digits.drop(while: { $0 == "0" })
    guard significantDigits.isEmpty == false else {
      return nil
    }
    return String(significantDigits)
  }
}

extension BookPageSelector {

  /// Process arguments that reproduce this selector without shell parsing.
  var launchArguments: [String] {
    var arguments = [StorybookLaunchRequest.storybookArgument]
    if name.isEmpty || name.hasPrefix("-") {
      arguments.append("\(StorybookLaunchRequest.nameArgument)=\(name)")
    } else {
      arguments.append(name)
    }
    if let fileID {
      arguments.append(
        contentsOf: [StorybookLaunchRequest.fileArgument, fileID]
      )
    }
    if let line {
      arguments.append(
        contentsOf: [StorybookLaunchRequest.lineArgument, line]
      )
    }
    return arguments
  }
}
