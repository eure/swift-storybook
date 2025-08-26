
public enum SearchResult: Identifiable {
  case page(BookPage)
  case folder(Book)
  
  public var id: String {
    switch self {
    case .page(let page):
      return "page.\(page.id.index)"
    case .folder(let book):
      return "folder.\(book.id)"
    }
  }
  
  public var title: String {
    switch self {
    case .page(let page):
      return page.title
    case .folder(let book):
      return book.title
    }
  }
}

@MainActor
public final class BookStore: ObservableObject {

  @Published var historyPages: [BookPage] = []

  public let title: String
  public let book: Book

  private let allPages: [BookPage.ID: BookPage]
  private let allBooks: [Book.ID: Book]

  private let userDefaults = UserDefaults(suiteName: "jp.eure.storybook2") ?? .standard

  public init(
    book: Book
  ) {

    self.title = book.title
    self.book = book

    self.allPages = book.allPages().reduce(
      into: [BookPage.ID: BookPage](),
      { partialResult, item in
        partialResult[item.id] = item
      }
    )

    self.allBooks = book.allBooks().reduce(
      into: [Book.ID: Book](),
      { partialResult, item in
        partialResult[item.id] = item
      }
    )

    updateHistory()
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

  nonisolated func search(query: String) async -> [SearchResult] {

    // find pages using query but fuzzy
    let pageResults = allPages.values
      .map { page -> (score: Double, result: SearchResult) in
        let score = page.title.score(word: query)
        return (score, .page(page))
      }
      .filter { $0.score > 0 }

    // find folders using query but fuzzy
    let folderResults = allBooks.values
      .map { book -> (score: Double, result: SearchResult) in
        let score = book.title.score(word: query)
        return (score, .folder(book))
      }
      .filter { $0.score > 0 }

    // combine and sort results
    let allResults = (pageResults + folderResults)
      .sorted { $0.score > $1.score }
      .map { $0.result }

    return allResults
  }

}

