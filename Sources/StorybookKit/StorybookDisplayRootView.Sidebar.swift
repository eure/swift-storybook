#if os(macOS)
import AppKit
import SwiftUI

/// Keeps the macOS catalog visible while a selected preview opens in the detail
/// column. Each window owns its selection, folder expansion, and search state.
struct BookSidebarCatalogView: View {

  private static let userDefaults = UserDefaults(suiteName: "jp.eure.storybook2") ?? .standard

  @ObservedObject private var store: BookStore
  @Environment(\.colorScheme) private var inheritedColorScheme
  @Environment(\.storybook_targetViewController) private var targetViewController
  @AppStorage("autoOpenLastPage", store: BookSidebarCatalogView.userDefaults)
  private var autoOpenLastPage = true

  private let shouldAutoOpenLastPage: Bool

  @State private var selection: Selection?
  @State private var expandedFolders: Set<Book.ID>
  @State private var columnVisibility: NavigationSplitViewVisibility = .all
  @State private var query = ""
  @State private var results: [Book.Node] = []
  @State private var showSettings = false
  @State private var didRestoreSelection = false
  @State private var appearanceContextStorage = AppearanceContext.Storage()
  @State private var overrideColorScheme: ColorScheme?

  init(store: BookStore, initialPage: BookPage?, shouldAutoOpenLastPage: Bool) {
    self.store = store
    self.shouldAutoOpenLastPage = shouldAutoOpenLastPage
    let selection = initialPage.flatMap {
      Self.findSelection(for: $0.id, in: store.book.contents, path: ["catalog"])
    }
    _selection = State(initialValue: selection)
    // Open the initial page's ancestors so an exact-page launch also reveals
    // its selected row. A catalog launch starts with its module folders open.
    let rootFolders = store.book.contents.compactMap { node -> Book.ID? in
      guard case .folder(let folder) = node else { return nil }
      return folder.id
    }
    _expandedFolders = State(initialValue: Set(rootFolders).union(selection?.ancestors ?? []))
  }

  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      sidebar
        .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 420)
    } detail: {
      NavigationStack {
        if let selection {
          BookPageDestination(page: selection.page)
        } else {
          ContentUnavailableView(
            "Select a Preview",
            systemImage: "sidebar.left",
            description: Text("Choose a preview from the sidebar.")
          )
          .navigationTitle(store.title)
        }
      }
      // Display caches its loaded preview, and previews may push their own
      // destinations. A different page must reset both content and navigation.
      .id(selection?.page.id)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .navigationSplitViewStyle(.balanced)
    .preferredColorScheme(overrideColorScheme)
    .environment(\.bookContext, store)
    .environment(
      \.appearanceContext,
      .init(overrideColorScheme: overrideColorScheme, storage: appearanceContextStorage)
    )
    .onChange(of: appearanceContextStorage.count) { _, _ in
      if overrideColorScheme != nil {
        overrideColorScheme = nil
      } else {
        overrideColorScheme = inheritedColorScheme == .dark ? .light : .dark
      }
    }
    .onChange(of: overrideColorScheme, initial: true) { _, value in
      // Native fixtures must receive the same override as SwiftUI content.
      let appearance = value.flatMap { NSAppearance(named: $0 == .dark ? .darkAqua : .aqua) }
      targetViewController?.children.forEach { $0.view.appearance = appearance }
    }
    .sheet(isPresented: $showSettings) {
      SettingsView()
        .frame(minWidth: 400, minHeight: 220)
    }
    .onAppear {
      guard didRestoreSelection == false else { return }
      didRestoreSelection = true
      guard shouldAutoOpenLastPage, autoOpenLastPage, selection == nil,
        let page = store.historyPages.first
      else { return }
      reveal(page)
    }
    .task(id: query) {
      guard query.isEmpty == false else {
        results = []
        if let page = selection?.page { reveal(page) }
        return
      }
      let matches = await store.search(query: query)
      guard Task.isCancelled == false else { return }
      results = matches
      expandedFolders.formUnion(Self.folderIDs(in: matches))
      if let page = selection?.page,
        let match = Self.findSelection(for: page.id, in: matches, path: ["search"])
      {
        selection = match
      }
    }
  }

  private var sidebar: some View {
    List(selection: $selection) {
      if query.isEmpty {
        if store.historyPages.isEmpty == false {
          Section("History") {
            ForEach(store.historyPages) { page in
              PageRow(page: page)
                .tag(Selection(page: page, path: ["history"], ancestors: []))
            }
          }
        }
        Section {
          ForEach(store.book.contents) { node in
            NodeRow(
              node: node, path: ["catalog"], ancestors: [],
              expandedFolders: $expandedFolders
            )
          }
        } header: {
          HStack {
            Text("Previews")
            Spacer()
            Button {
              let folders = Self.folderIDs(in: store.book.contents)
              if folders.isSubset(of: expandedFolders) {
                expandedFolders.subtract(folders)
              } else {
                expandedFolders.formUnion(folders)
              }
            } label: {
              Image(systemName: "arrow.up.arrow.down")
            }
            .buttonStyle(.borderless)
            .help("Expand or Collapse All Folders")
            .accessibilityLabel("Expand or Collapse All Folders")
          }
        }
      } else {
        Section("Search Results") {
          if results.isEmpty {
            Text("No matching previews")
              .foregroundStyle(.secondary)
          }
          ForEach(results) { node in
            NodeRow(
              node: node, path: ["search"], ancestors: [],
              expandedFolders: $expandedFolders
            )
          }
        }
      }
    }
    .listStyle(.sidebar)
    .navigationTitle(store.title)
    .searchable(text: $query, placement: .sidebar, prompt: "Search Previews")
    .toolbar {
      ToolbarItem {
        Button {
          showSettings = true
        } label: {
          Label("Settings", systemImage: "gearshape")
        }
      }
    }
    .accessibilityIdentifier("storybook.sidebar")
  }

  private func reveal(_ page: BookPage) {
    guard let match = Self.findSelection(
      for: page.id, in: store.book.contents, path: ["catalog"]
    ) else { return }
    selection = match
    expandedFolders.formUnion(match.ancestors)
  }

  private static func findSelection(
    for pageID: BookPage.ID, in nodes: [Book.Node], path: [String],
    ancestors: [Book.ID] = []
  ) -> Selection? {
    for node in nodes {
      switch node {
      case .page(let page) where page.id == pageID:
        return Selection(page: page, path: path, ancestors: ancestors)
      case .page:
        continue
      case .folder(let folder):
        if let match = findSelection(
          for: pageID, in: folder.contents, path: path + [node.id],
          ancestors: ancestors + [folder.id]
        ) {
          return match
        }
      }
    }
    return nil
  }

  private static func folderIDs(in nodes: [Book.Node]) -> Set<Book.ID> {
    nodes.reduce(into: Set<Book.ID>()) { result, node in
      if case .folder(let folder) = node {
        result.insert(folder.id)
        result.formUnion(folderIDs(in: folder.contents))
      }
    }
  }
}

extension BookSidebarCatalogView {

  /// Identifies a row independently of its page: history and search can show
  /// the same declaration as the catalog without duplicating selection tags.
  private struct Selection: Hashable {
    let page: BookPage
    let path: [String]
    let ancestors: [Book.ID]

    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.page.id == rhs.page.id && lhs.path == rhs.path
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(page.id)
      hasher.combine(path)
    }
  }

  /// Renders a folder tree with native disclosure and selectable leaf rows.
  private struct NodeRow: View {
    let node: Book.Node
    let path: [String]
    let ancestors: [Book.ID]
    @Binding var expandedFolders: Set<Book.ID>

    var body: some View {
      switch node {
      case .folder(let folder):
        DisclosureGroup(
          isExpanded: Binding(
            get: { expandedFolders.contains(folder.id) },
            set: { expanded in
              if expanded { expandedFolders.insert(folder.id) }
              else { expandedFolders.remove(folder.id) }
            }
          )
        ) {
          ForEach(folder.contents) { child in
            NodeRow(
              node: child, path: path + [node.id], ancestors: ancestors + [folder.id],
              expandedFolders: $expandedFolders
            )
          }
        } label: {
          Label(folder.title, systemImage: "folder")
            .lineLimit(1)
        }
      case .page(let page):
        PageRow(page: page)
          .tag(Selection(page: page, path: path, ancestors: ancestors))
      }
    }
  }

  /// A compact source-list row; the full source location remains in its help.
  private struct PageRow: View {
    let page: BookPage

    var body: some View {
      Label(page.title, systemImage: "doc")
        .lineLimit(1)
        .help("\(page.descriptor.fileID):\(page.descriptor.line)")
    }
  }
}
#endif
