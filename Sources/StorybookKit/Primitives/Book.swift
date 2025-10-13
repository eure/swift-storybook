import SwiftUI

public struct Book: BookView, Identifiable {

  public enum Node: Identifiable {

    public var id: String {
      switch self {
      case .folder(let v): return "folder.\(v.id)"
      case .page(let v): return "page.\(v.id)"
      }
    }

    case folder(Book)
    case page(BookPage)

    var sortingKey: String {
      switch self {
      case .folder(let v): return v.title
      case .page(let v): return v.title
      }
    }

    @MainActor
    var children: [Node]? {
      switch self {
      case .folder(let v): return v.contents
      case .page: return nil
      }
    }

  }

  public var id: UUID = .init()

  public let title: String
  public let contents: [Node]
  
  @State private var isExpandedAll: Bool = false

  public init(
    title: String,
    @FolderBuilder contents: () -> [Node]
  ) {

    self.title = title

    let _contents = contents()

    let folders =
      _contents
      .filter {
        switch $0 {
        case .folder:
          return true
        case .page:
          return false
        }
      }
      .sorted { a, b in
        a.sortingKey < b.sortingKey
      }

    let pages =
      _contents
      .filter {
        switch $0 {
        case .folder:
          return false
        case .page:
          return true
        }
      }
      .sorted { a, b in
        a.sortingKey < b.sortingKey
      }

    self.contents = folders + pages

  }

  public var body: some View {
    Section { 
      ForEach(contents) { node in
        NodeOutlineGroup(expandsAll: isExpandedAll, node, children: \.children) { content in
          switch content {
          case .folder(let folder):

            HStack {
              Image.init(systemName: "folder.fill")
                .foregroundStyle(.blue)
              Text(folder.title)
            }

          case .page(let page):
            page
          }
        }
        
      }
    } header: {
      HStack {
        Text(title)
        Spacer()
        Button(isExpandedAll ? " Collapse All" : " Expand All") {
          isExpandedAll.toggle()
        }
        .font(.caption)
      }
    }
   
  }

  func allPages() -> [BookPage] {
    contents.flatMap { node -> [BookPage] in
      switch node {
      case .folder(let folder):
        return folder.allPages()
      case .page(let page):
        return [page]
      }
    }
  }

}

// MARK: Runtime creation
extension Book {

  /// All conformers to `BookProvider`, including those declared from the `#StorybookPage` macro
  public static func allBookProviders() -> [any BookProvider.Type] {
    self.findAllBookProviders(filterByStorybookPageMacro: false) ?? []
  }

  /// All conformers to `BookProvider` that were declared from the `#StorybookPage` macro
  public static func allStorybookPages() -> [any BookProvider.Type] {
    self.findAllBookProviders(filterByStorybookPageMacro: true) ?? []
  }

  /// All `#Preview`s as `BookPage`s
  @available(iOS 17.0, *)
  public static func allBookPreviews() -> [Node]? {
    guard let sortedPreviewRegistries = self.findAllPreviews() else {
      return nil
    }
    var fileIDsByModule: [String: Set<String>] = [:]
    var registriesByFileID: [String: [PreviewRegistryWrapper]] = [:]
    for item in sortedPreviewRegistries {
      fileIDsByModule[item.module, default: []].insert(item.fileID)
      registriesByFileID[item.fileID, default: []].append(item)
    }
    return fileIDsByModule.keys.sorted().map { module in
      return Node.folder(
        .init(
          title: module,
          contents: { [fileIDs = fileIDsByModule[module]!.sorted()] in
            fileIDs.map { fileID in

              let name = String(fileID[fileID.index(after: module.endIndex)...])
              let registries = registriesByFileID[fileID]!

              return Node.folder(
                .init(
                  title: name,
                  contents: {
                    registries.map { registry in

                      let pageName: String

                      if let displayName = registry.displayName {
                        pageName = "\(displayName)"
                      } else {
                        pageName = "line: \(registry.line)"
                      }

                      return Node.page(
                        .init(
                          fileID,
                          registry.line,
                          title: pageName,
                          usesScrollView: false,
                          destination: {
                            AnyView(registry.makeView())
                          }
                        )
                      )

                    }
                  }))

            }
          }
        )
      )
    }
  }

}

@resultBuilder
public struct FolderBuilder {

  public typealias Element = Book.Node

  @MainActor
  public static func buildExpression<Provider: BookProvider>(_ expression: Provider.Type)
    -> [FolderBuilder.Element]
  {
    return [.page(expression.bookBody)]
  }

  public static func buildExpression(_ expression: BookPage) -> [FolderBuilder.Element] {
    return [.page(expression)]
  }

  public static func buildExpression(_ expression: [BookPage]) -> [FolderBuilder.Element] {
    return expression.map { .page($0) }
  }

  public static func buildExpression(_ expression: Book) -> [FolderBuilder.Element] {
    return [.folder(expression)]
  }

  public static func buildExpression(_ expression: [Book]) -> [FolderBuilder.Element] {
    return expression.map { .folder($0) }
  }

  public static func buildBlock() -> [Element] {
    []
  }

  public static func buildBlock<C: Collection>(_ contents: C...) -> [Element]
  where C.Element == Element {
    return contents.flatMap { $0 }
  }

  public static func buildOptional(_ component: [Element]?) -> [Element] {
    return component ?? []
  }

  public static func buildEither(first component: [Element]) -> [Element] {
    return component
  }

  public static func buildEither(second component: [Element]) -> [Element] {
    return component
  }

  public static func buildArray(_ components: [[Element]]) -> [Element] {
    components.flatMap { $0 }
  }

  public static func buildExpression(_ element: Element?) -> [Element] {
    return element.map { [$0] } ?? []
  }

  public static func buildExpression(_ element: Element) -> [Element] {
    return [element]
  }

  public static func buildExpression<C: Collection>(_ elements: C) -> [Element]
  where C.Element == Element {
    Array(elements)
  }

  public static func buildExpression<C: Collection>(_ elements: C) -> [Element]
  where C.Element == Element? {
    elements.compactMap { $0 }
  }

}

private struct NodeOutlineGroup<Node, Content>: View where Node: Identifiable, Content: View {

  let node: Node
  let childKeyPath: KeyPath<Node, [Node]?>

  let expandsAll: Bool
  
  @State var isExpanded: Bool

  let content: (Node) -> Content

  init(
    expandsAll: Bool,
    _ node: Node, children childKeyPath: KeyPath<Node, [Node]?>,
    @ViewBuilder content: @escaping (Node) -> Content
  ) {
    self._isExpanded = .init(wrappedValue: expandsAll)
    self.expandsAll = expandsAll
    self.node = node
    self.childKeyPath = childKeyPath
    self.content = content
  }

  var body: some View {
    Group {
      if node[keyPath: childKeyPath] != nil {
        DisclosureGroup(
          isExpanded: $isExpanded,
          content: {
            ForEach(node[keyPath: childKeyPath]!) { childNode in
              NodeOutlineGroup(
                expandsAll: expandsAll,
                childNode,
                children: childKeyPath,
                content: content
              )
            }
          },
          label: { 
            content(node)              
          }
        )
       
      } else {
        content(node)
      }
    }
    .onChange(of: expandsAll) { value in
      withAnimation(.default) {
        isExpanded = value
      }
    }
  }
}
