//
// Copyright (c) 2020 Eureka, Inc.
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

#if canImport(UIKit)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import Foundation

public enum BookGenerator {

  #if canImport(UIKit)
  public static func randomColor() -> UIColor {
    let red = CGFloat(Int.random(in: 0 ... 255))
    let green = CGFloat(Int.random(in: 0 ... 255))
    let blue = CGFloat(Int.random(in: 0 ... 255))
    return UIColor.init(red: red / 255, green: green / 255, blue: blue / 255, alpha: 1.0)
  }

  #elseif os(macOS)
  /// Returns a random opaque color for an AppKit preview fixture.
  public static func randomColor() -> NSColor {
    NSColor(
      red: CGFloat.random(in: 0 ... 1),
      green: CGFloat.random(in: 0 ... 1),
      blue: CGFloat.random(in: 0 ... 1),
      alpha: 1
    )
  }
  #endif

  public static func loremIpsum(length: Int) -> String {
    BookLorem.ipsum(length)
  }
  
  public static func randomEmoji() -> String {
    let range = 0x1F601...0x1F64F
    let ascii = range.lowerBound + Int(arc4random_uniform(UInt32(range.count)))
    
    var view = String.UnicodeScalarView()
    view.append(UnicodeScalar(ascii)!)
    
    let emoji = String(view)
    
    return emoji
  }

}
