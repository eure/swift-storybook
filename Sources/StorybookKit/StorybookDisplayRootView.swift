import SwiftUI
import UIKit

public struct StorybookDisplayRootView: View {

  private let book: BookContainer

  /// Creates a Storybook that opens its catalog, subject to the user's
  /// auto-open-last-page setting.
  @MainActor
  public init(bookStore: BookStore) {
    self.book = .init(
      store: bookStore,
      initialPresentation: .automaticCatalog
    )
  }

  /// Creates a Storybook that immediately opens an exactly matched page.
  ///
  /// An unresolved or ambiguous selector produces a diagnostic screen inside
  /// Storybook instead of silently opening a different page.
  @MainActor
  public init(
    bookStore: BookStore,
    initialPage: BookPageSelector
  ) {
    self.book = .init(
      store: bookStore,
      initialPresentation: Self.resolve(
        initialPage,
        in: bookStore
      )
    )
  }

  /// Creates a Storybook for a parsed programmable launch request.
  ///
  /// Use `StorybookLaunchRequest.init(arguments:)` at the host application's
  /// startup boundary, before constructing its normal root view.
  @MainActor
  public init(
    bookStore: BookStore,
    launchRequest: StorybookLaunchRequest
  ) {
    let initialPresentation: BookInitialPresentation
    switch launchRequest {
    case .catalog:
      initialPresentation = .catalog
    case .page(let selector):
      initialPresentation = Self.resolve(selector, in: bookStore)
    case .invalid(let diagnostic):
      initialPresentation = .failure(.invalid(diagnostic))
    }

    self.book = .init(
      store: bookStore,
      initialPresentation: initialPresentation
    )
  }

  public var body: some View {

    _ViewControllerHost {
      let controller = _ViewController(content: book)
      return controller
    }
    .ignoresSafeArea()

  }

  @MainActor
  private static func resolve(
    _ selector: BookPageSelector,
    in store: BookStore
  ) -> BookInitialPresentation {
    do {
      return .page(try store.resolve(selector))
    } catch let error as BookPageResolutionError {
      return .failure(.resolution(error))
    } catch {
      return .failure(.unexpected(error.localizedDescription))
    }
  }
}

public struct BookActionHosting<Content: View>: View {

  private let content: Content

  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {

    _ViewControllerHost {
      let controller = _ViewController(content: content)
      return controller
    }
    .ignoresSafeArea()

  }
}

/// The navigation state Storybook should establish on its first presentation.
private enum BookInitialPresentation {
  case automaticCatalog
  case catalog
  case page(BookPage)
  case failure(StorybookLaunchFailure)
}

/// A launch failure that can be rendered without choosing an unintended page.
private enum StorybookLaunchFailure {
  case invalid(StorybookLaunchDiagnostic)
  case resolution(BookPageResolutionError)
  case unexpected(String)

  var reason: String {
    switch self {
    case .invalid(let diagnostic):
      return diagnostic.message
    case .resolution(let error):
      switch error {
      case .notFound:
        return "No Storybook page exactly matched the request."
      case .ambiguous(let selector, _):
        if selector.line != nil {
          return
            "Multiple pages share this exact name and source location. Give each page a unique name."
        }
        if selector.fileID != nil {
          return "More than one Storybook page matched the request. Add a candidate line number."
        }
        return
          "More than one Storybook page matched the request. Add a candidate file ID and, when needed, its line number."
      }
    case .unexpected(let message):
      return message
    }
  }

  var launchArguments: [String]? {
    let selector: BookPageSelector
    switch self {
    case .invalid, .unexpected:
      return nil
    case .resolution(let error):
      switch error {
      case .notFound(let value, _), .ambiguous(let value, _):
        selector = value
      }
    }

    return selector.launchArguments
  }

  var candidates: [BookPageDescriptor] {
    switch self {
    case .invalid, .unexpected:
      return []
    case .resolution(let error):
      let candidates: [BookPageDescriptor]
      switch error {
      case .notFound(_, let values), .ambiguous(_, let values):
        candidates = values
      }

      var seen: Set<BookPageDescriptor> = []
      return candidates.filter { candidate in
        seen.insert(candidate).inserted
      }
    }
  }
}

/// Selects the catalog or diagnostic surface for the requested launch mode.
private struct BookContainer: View {

  private let store: BookStore
  private let initialPresentation: BookInitialPresentation

  init(
    store: BookStore,
    initialPresentation: BookInitialPresentation
  ) {
    self.store = store
    self.initialPresentation = initialPresentation
  }

  var body: some View {
    switch initialPresentation {
    case .automaticCatalog:
      BookCatalogView(
        store: store,
        initialPage: nil,
        shouldAutoOpenLastPage: true
      )
    case .catalog:
      BookCatalogView(
        store: store,
        initialPage: nil,
        shouldAutoOpenLastPage: false
      )
    case .page(let page):
      BookCatalogView(
        store: store,
        initialPage: page,
        shouldAutoOpenLastPage: false
      )
    case .failure(let failure):
      StorybookLaunchFailureView(failure: failure)
    }
  }
}

/// Owns catalog navigation, search, settings, and page history presentation.
private struct BookCatalogView: View {

  private static let userDefaults = UserDefaults(suiteName: "jp.eure.storybook2") ?? .standard

  struct UniqueBox<T>: Hashable {

    static func == (lhs: UniqueBox<T>, rhs: UniqueBox<T>) -> Bool {
      lhs.uuid == rhs.uuid
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(uuid)
    }

    let uuid: UUID = .init()
    let value: T

    init(value: T) {
      self.value = value
    }
  }

  @ObservedObject private var store: BookStore

  @AppStorage("autoOpenLastPage", store: BookCatalogView.userDefaults)
  private var autoOpenLastPage: Bool = true

  private let shouldAutoOpenLastPage: Bool

  @State private var query: String = ""
  @State private var result: [Book.Node] = []
  @State private var currentTask: Task<Void, Error>?
  @State private var showSettings: Bool = false
  @State private var path: NavigationPath

  @MainActor
  init(
    store: BookStore,
    initialPage: BookPage?,
    shouldAutoOpenLastPage: Bool
  ) {
    self.store = store
    self.shouldAutoOpenLastPage = shouldAutoOpenLastPage

    var initialPath = NavigationPath()
    if let initialPage {
      initialPath.append(UniqueBox(value: initialPage))
    }
    self._path = .init(initialValue: initialPath)
  }

  var body: some View {
    NavigationStack(path: $path) {
      List {
        if result.isEmpty == false {
          Section {
            ForEach(result) { node in
              Group {
                switch node {
                case .folder(let folder):
                  DisclosureGroup {
                    ForEach(folder.contents) { childNode in
                      SearchResultNodeView(node: childNode)
                    }
                  } label: {
                    HStack {
                      Image(systemName: "folder.fill")
                        .foregroundStyle(.blue)
                      Text(folder.title)
                    }
                  }
                case .page(let page):
                  page
                }
              }
            }
          } header: {
            Text("Search Result")
          }
        }

        Section {
          ForEach(store.historyPages) { link in
            link
          }
        } header: {
          Text("History")
        }

        store.book
      }
      .navigationTitle(store.title)
      .searchable(text: $query, prompt: "Search")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            showSettings = true
          } label: {
            Image(systemName: "gearshape.fill")
          }
        }
      }
      .navigationDestination(for: UniqueBox<BookPage>.self) { page in
        BookPageDestination(page: page.value)
          .environment(\.bookContext, store)
      }
      .sheet(isPresented: $showSettings) {
        SettingsView()
      }
    }
    .environment(\.bookContext, store)
    .onAppear {
      guard shouldAutoOpenLastPage, autoOpenLastPage else {
        return
      }

      // Deferring avoids an iOS 26 navigation hang when returning to the root.
      Task {
        guard path.isEmpty else {
          return
        }
        if let page = store.historyPages.first {
          path.append(UniqueBox(value: page))
        }
      }
    }
    .onChange(
      of: query,
      perform: { value in
        guard value.isEmpty == false else {
          currentTask?.cancel()
          result = []
          return
        }

        currentTask?.cancel()
        currentTask = Task {
          let result = await store.search(query: value)

          guard Task.isCancelled == false else {
            return
          }

          self.result = result
        }
      })
  }
}

/// Presents an actionable launch diagnostic and deterministic candidates.
private struct StorybookLaunchFailureView: View {

  let failure: StorybookLaunchFailure

  var body: some View {
    NavigationStack {
      List {
        Section("Reason") {
          Text(failure.reason)
        }
        if let launchArguments = failure.launchArguments {
          Section("Launch arguments") {
            ForEach(
              Array(launchArguments.enumerated()),
              id: \.offset
            ) { _, argument in
              Text(argument)
                .font(.caption.monospaced())
                .textSelection(.enabled)
            }
          }
        }
        if failure.candidates.isEmpty == false {
          Section("Candidates") {
            ForEach(failure.candidates, id: \.self) { candidate in
              VStack(alignment: .leading) {
                Text(candidate.name)
                Text("\(candidate.fileID):\(candidate.line)")
                  .font(.caption.monospacedDigit())
                  .foregroundStyle(.secondary)
                  .textSelection(.enabled)
              }
            }
          }
        }
      }
      .navigationTitle("Storybook launch failed")
      .accessibilityIdentifier("storybook.launch.failure")
    }
  }
}

private struct SearchResultNodeView: View {
  let node: Book.Node

  var body: some View {
    switch node {
    case .folder(let folder):
      DisclosureGroup {
        ForEach(folder.contents) { childNode in
          SearchResultNodeView(node: childNode)
        }
      } label: {
        HStack {
          Image(systemName: "folder.fill")
            .foregroundStyle(.blue)
          Text(folder.title)
        }
      }
    case .page(let page):
      page
    }
  }
}

final class _ViewController<Content: View>: UIViewController {

  private let content: Content

  init(content: Content) {
    self.content = content
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    let hosting = UIHostingController(
      rootView:
        content
        .environment(\.storybook_targetViewController, self)
    )

    addChild(hosting)
    view.addSubview(hosting.view)
    hosting.view.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
      hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])

    hosting.didMove(toParent: self)

  }

}
