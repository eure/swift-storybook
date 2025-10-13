import SwiftUI
import SwiftUISupport
import UIKit

public struct StorybookDisplayRootView: View {

  let book: BookContainer

  @MainActor
  public init(bookStore: BookStore) {
    self.book = .init(store: bookStore)
  }

  public var body: some View {

    _ViewControllerHost {
      let controller = _ViewController(content: book)
      return controller
    }
    .ignoresSafeArea()

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

struct BookContainer: View {

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

  // MARK: Properties

  @ObservedObject private var store: BookStore

  @AppStorage("autoOpenLastPage", store: BookContainer.userDefaults)
  private var autoOpenLastPage: Bool = true

  @State private var lastUsedItem: UniqueBox<BookPage>?
  @State private var query: String = ""
  @State private var result: [Book.Node] = []
  @State private var currentTask: Task<Void, Error>?
  @State private var showSettings: Bool = false

  @State var path: NavigationPath = .init()
  
  // MARK: Initializers
  
  @MainActor
  public init(
    store: BookStore
  ) {
    self.store = store
  }
  
  // MARK: View

  public var body: some View {

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
        page
          .value
          .destination()
          .environment(\.bookContext, store)
      }
      .sheet(isPresented: $showSettings) {
        SettingsView()
      }
    }
    .environment(\.bookContext, store)
    .onAppear {
      print("📱 BookContainer.onAppear: autoOpenLastPage = \(autoOpenLastPage)")
      guard autoOpenLastPage else {
        print("📱 Auto-open disabled, skipping")
        return
      }
      // Use Task to hop as somehow iOS26 gets hangs when back to top by using back button.
      Task {
        if let value = store.historyPages.first {
          print("📱 Auto-opening last page: \(value.title)")
          path.append(UniqueBox(value: value))
        }
      }
    }
    .onChange(of: query, perform: { value in
      
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
