import Foundation

public enum StorybookDeepLink {

  public static let defaultScheme = "storybook"

  public static func makeURL(
    scheme: String = Self.defaultScheme,
    pageID: DeclarationIdentifier
  ) -> URL? {
    makeURL(scheme: scheme, pageID: pageID.stableID)
  }

  public static func makeURL(
    scheme: String = Self.defaultScheme,
    pageID: String
  ) -> URL? {
    guard pageID.isEmpty == false else {
      return nil
    }

    var components = URLComponents()
    components.scheme = scheme
    components.host = "page"
    components.queryItems = [
      .init(name: "id", value: pageID)
    ]
    return components.url
  }

  public static func pageID(
    from url: URL,
    matchingScheme scheme: String? = nil
  ) -> String? {
    if let scheme {
      guard url.scheme?.caseInsensitiveCompare(scheme) == .orderedSame else {
        return nil
      }
    }

    guard url.host == "page" || url.path == "/page" else {
      return nil
    }

    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    return components?
      .queryItems?
      .first(where: { $0.name == "id" })?
      .value
  }
}
