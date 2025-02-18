//
// Copyright (c) 2024 Eureka, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - StorybookPreviewMacro

public struct StorybookPreviewMacro: ExpressionMacro {

  // MARK: Internal

  /// Should match `Book._magicSubstring`
  static let _magicSubstring: String = "__🤖🛠️_StorybookMagic_"

  // MARK: ExpressionMacro

  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    let (title, closure) = try self.parseArguments(from: node)
    let enumName = context.makeUniqueName(
      self._magicSubstring
    )
    return .init(
      stringLiteral: """
      {
        enum \(enumName): BookProvider {
         @MainActor
          static var bookBody: BookPage {
            .init(
              title: \(title),
              destination: \(closure)
            )
          }
        }
        return \(enumName).bookBody.destination
      }()
      """
    )
  }


  // MARK: Private

  private static func parseArguments(
    from node: some FreestandingMacroExpansionSyntax
  ) throws -> (
    title: ExprSyntax,
    closure: ClosureExprSyntax
  ) {
    var argumentsIterator = node.argumentList.makeIterator()
    var title: ExprSyntax? = (node.genericArgumentClause?.arguments.first?.argument)
      .flatMap { genericType -> TypeSyntaxProtocol? in
        genericType.as(IdentifierTypeSyntax.self)
        ?? genericType.as(MemberTypeSyntax.self)
      }
      .map({ .init(stringLiteral: "_typeName(\($0).self)") })

    var closure: ClosureExprSyntax? = node.trailingClosure
    while let argument = argumentsIterator.next()?
      .as(LabeledExprSyntax.self) {

      switch argument.label?.text {

      case "title"?:
        title = argument.expression

      case "target"?:
        title = .init(stringLiteral: "_typeName(\(argument))")

      case "contents"?:
        closure = argument.expression
          .as(ClosureExprSyntax.self)

      default:
        fatalError()
      }
    }
    return (
      title: title!,
      closure: closure!
    )
  }
}
