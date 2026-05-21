
import Foundation
import Observation

@Observable
@MainActor
public final class BookStore {

  var historyPages: [BookPage] = []
  var pinnedNodes: [Book.Node] = []

  public let title: String
  public let book: Book
  public let deepLinkScheme: String?

  private let allPages: [BookPage.ID: BookPage]
  private let allPagesByStableID: [String: BookPage]
  private let folderPages: [String: (book: Book, pageIDs: Set<BookPage.ID>)]
  private var allNodes: [String: Book.Node] = [:]

  private let userDefaults = UserDefaults(suiteName: "jp.eure.storybook2") ?? .standard
  private enum DefaultsKey {
    static let historyPageIDs = "historyPageIDs"
    static let legacyHistoryIndexes = "history"
    static let pinnedNodes = "pinnedNodes"
  }

  public init(
    book: Book,
    deepLinkScheme: String? = StorybookDeepLink.defaultScheme
  ) {

    self.title = book.title
    self.book = book
    self.deepLinkScheme = deepLinkScheme

    let pages = book.allPages()

    self.allPages = pages.reduce(
      into: [BookPage.ID: BookPage](),
      { partialResult, item in
        partialResult[item.id] = item
      }
    )
    self.allPagesByStableID = pages.reduce(
      into: [String: BookPage](),
      { partialResult, item in
        partialResult[item.id.stableID] = item
      }
    )

    // Build folder-to-pages mapping for search and allNodes for pin management
    var folderPagesMap: [String: (book: Book, pageIDs: Set<BookPage.ID>)] = [:]
    var allNodesMap: [String: Book.Node] = [:]
    func traverseNodes(_ nodes: [Book.Node], folderTitle: String? = nil) {
      for node in nodes {
        allNodesMap[node.id] = node
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
    self.allNodes = allNodesMap

    updateHistory()
    loadPinnedNodes()
  }

  private func updateHistory() {

    let pageIDs = userDefaults.stringArray(forKey: DefaultsKey.historyPageIDs) ?? []
    if pageIDs.isEmpty == false {
      historyPages = pageIDs.compactMap { allPagesByStableID[$0] }
      return
    }

    let indexes = userDefaults.array(forKey: DefaultsKey.legacyHistoryIndexes) as? [Int] ?? []

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

    let stableID = pageID.stableID

    var current = userDefaults.stringArray(forKey: DefaultsKey.historyPageIDs) ?? []
    if let index = current.firstIndex(of: stableID) {
      current.remove(at: index)
    }

    current.insert(stableID, at: 0)
    current = Array(current.prefix(5))

    userDefaults.set(current, forKey: DefaultsKey.historyPageIDs)

    print("Update history", current)

    updateHistory()
  }

  public func deepLinkURL(for pageID: DeclarationIdentifier) -> URL? {
    guard let deepLinkScheme else {
      return nil
    }
    return StorybookDeepLink.makeURL(
      scheme: deepLinkScheme,
      pageID: pageID
    )
  }

  func deepLinkURL(for page: BookPage) -> URL? {
    deepLinkURL(for: page.id)
  }

  public func page(forDeepLink url: URL) -> BookPage? {
    guard
      let deepLinkScheme,
      let pageID = StorybookDeepLink.pageID(
        from: url,
        matchingScheme: deepLinkScheme
      )
    else {
      return nil
    }
    return allPagesByStableID[pageID]
  }

  func search(query: String) async -> [Book.Node] {

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

  // MARK: - Pin Management

  func togglePin(node: Book.Node) {
    if let index = pinnedNodes.firstIndex(where: { $0.id == node.id }) {
      pinnedNodes.remove(at: index)
    } else {
      pinnedNodes.insert(node, at: 0)
    }
    savePinnedNodes()
  }

  func isPinned(node: Book.Node) -> Bool {
    pinnedNodes.contains(where: { $0.id == node.id })
  }

  private func loadPinnedNodes() {
    guard let items = userDefaults.array(forKey: DefaultsKey.pinnedNodes) as? [[String: String]] else {
      return
    }

    let nodes = items.compactMap { item -> Book.Node? in
      guard let nodeIDString = item["id"] else {
        return nil
      }
      return allNodes[nodeIDString]
    }

    pinnedNodes = nodes
  }

  private func savePinnedNodes() {
    let items = pinnedNodes.map { node -> [String: String] in
      return ["id": node.id]
    }
    userDefaults.set(items, forKey: DefaultsKey.pinnedNodes)
  }

}
