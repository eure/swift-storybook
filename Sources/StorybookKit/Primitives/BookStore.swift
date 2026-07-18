import Combine
import Foundation

@MainActor
public final class BookStore: ObservableObject {

  @Published var historyPages: [BookPage] = []

  public let title: String
  public let book: Book

  private let pages: [BookPage]
  private let allPages: [BookPage.ID: BookPage]
  private let folderPages: [String: (book: Book, pageIDs: Set<BookPage.ID>)]

  private let userDefaults = UserDefaults(suiteName: "jp.eure.storybook2") ?? .standard

  public init(
    book: Book
  ) {

    self.title = book.title
    self.book = book

    let pages = book.allPages()
    self.pages = pages
    self.allPages = pages.reduce(
      into: [BookPage.ID: BookPage](),
      { partialResult, item in
        partialResult[item.id] = item
      }
    )

    // Build folder-to-pages mapping for search
    var folderPagesMap: [String: (book: Book, pageIDs: Set<BookPage.ID>)] = [:]
    func traverseNodes(_ nodes: [Book.Node], folderTitle: String? = nil) {
      for node in nodes {
        switch node {
        case .folder(let folder):
          let pages = folder.allPages()
          let pageIDs = Set(pages.map { $0.id })
          folderPagesMap[folder.title] = (book: folder, pageIDs: pageIDs)
          traverseNodes(folder.contents, folderTitle: folder.title)
        case .page:
          break
        }
      }
    }
    traverseNodes(book.contents)
    self.folderPages = folderPagesMap

    updateHistory()
  }

  /// Returns the only page that exactly matches the supplied selector.
  ///
  /// Name-only selectors are convenient for automation, but they must be
  /// unique across the book. Add a file ID, and finally a line number, when
  /// the error's candidates show that a name is shared.
  public func resolve(_ selector: BookPageSelector) throws -> BookPage {
    let nameMatches = pages.filter { page in
      page.descriptor.matches(.init(name: selector.name))
    }

    var matches = nameMatches
    var candidates = nameMatches

    if let fileID = selector.fileID {
      matches = matches.filter { page in
        page.descriptor.matches(
          .init(name: selector.name, fileID: fileID)
        )
      }
      if matches.isEmpty == false {
        candidates = matches
      }
    }

    if let line = selector.line, let fileID = selector.fileID {
      matches = matches.filter { page in
        page.descriptor.matches(
          .init(
            name: selector.name,
            fileID: fileID,
            normalizedLine: line
          )
        )
      }
      if matches.isEmpty == false {
        candidates = matches
      }
    }

    switch matches.count {
    case 0:
      throw BookPageResolutionError.notFound(
        selector: selector,
        candidates: sortedDescriptors(candidates)
      )
    case 1:
      return matches[0]
    default:
      throw BookPageResolutionError.ambiguous(
        selector: selector,
        candidates: sortedDescriptors(matches)
      )
    }
  }

  private func updateHistory() {

    let indexes = userDefaults.array(forKey: "history") as? [Int] ?? []

    let _pages = indexes.compactMap { (index: Int) -> BookPage? in
      let id = DeclarationIdentifier(raw: index)
      guard let page = allPages[id] else {
        return nil
      }
      return page
    }

    historyPages = _pages

  }

  func onOpen(pageID: DeclarationIdentifier) {

    guard allPages.keys.contains(pageID) else {
      return
    }

    let index = pageID.index

    var current = userDefaults.array(forKey: "history") as? [Int] ?? []
    if let index = current.firstIndex(of: index) {
      current.remove(at: index)
    }

    current.insert(index, at: 0)
    current = Array(current.prefix(5))

    userDefaults.set(current, forKey: "history")

    print("Update history", current)

    updateHistory()
  }

  nonisolated func search(query: String) async -> [Book.Node] {

    // Search through folders and pages
    var results: [(score: Double, node: Book.Node)] = []

    // Search folder titles - add folders themselves to results
    for (folderTitle, folderData) in folderPages {
      let folderScore = folderTitle.score(word: query)
      if folderScore > 0 {
        // Add the folder itself as a result
        results.append((score: folderScore, node: .folder(folderData.book)))
      }
    }

    // Search page titles
    for page in allPages.values {
      let pageScore = page.title.score(word: query)
      if pageScore > 0 {
        results.append((score: pageScore, node: .page(page)))
      }
    }

    // Remove duplicates (keep highest score for each node)
    var uniqueResults: [String: (score: Double, node: Book.Node)] = [:]
    for result in results {
      let nodeID = result.node.id
      if let existing = uniqueResults[nodeID] {
        // Keep the higher score
        if result.score > existing.score {
          uniqueResults[nodeID] = result
        }
      } else {
        uniqueResults[nodeID] = result
      }
    }

    // Sort by score and return nodes
    let sortedNodes = uniqueResults.values
      .sorted { $0.score > $1.score }
      .map { $0.node }

    return sortedNodes
  }

  private func sortedDescriptors(
    _ pages: [BookPage]
  ) -> [BookPageDescriptor] {
    pages
      .map(\.descriptor)
      .sorted { lhs, rhs in
        if lhs.fileID.utf8.elementsEqual(rhs.fileID.utf8) == false {
          return lhs.fileID.utf8.lexicographicallyPrecedes(rhs.fileID.utf8)
        }
        if lhs.line != rhs.line {
          if let lhsLine = UInt(lhs.line), let rhsLine = UInt(rhs.line) {
            return lhsLine < rhsLine
          }
          return lhs.line.utf8.lexicographicallyPrecedes(rhs.line.utf8)
        }
        return lhs.name.utf8.lexicographicallyPrecedes(rhs.name.utf8)
      }
  }

}
