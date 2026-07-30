import Foundation
import Testing

@testable import StorybookKit

@Suite("Application Mach-O image scope")
struct ApplicationMachOImageScopeTests {

  private let scope = ApplicationMachOImageScope(
    bundleURL: URL(
      fileURLWithPath: "/private/var/containers/Bundle/Application/UUID/Example.app"
    )
  )

  @Test("The application executable and debug dylib are included")
  func applicationExecutable() {
    #expect(
      scope.contains(
        imagePath: "/private/var/containers/Bundle/Application/UUID/Example.app/Example"
      )
    )
    #expect(
      scope.contains(
        imagePath:
          "/private/var/containers/Bundle/Application/UUID/Example.app/Example.debug.dylib"
      )
    )
  }

  @Test("An embedded dynamic framework is included")
  func embeddedDynamicFramework() {
    #expect(
      scope.contains(
        imagePath:
          "/private/var/containers/Bundle/Application/UUID/Example.app/Frameworks/Feature.framework/Feature"
      )
    )
  }

  @Test("A system framework is excluded")
  func systemFramework() {
    #expect(
      !scope.contains(
        imagePath:
          "/System/Library/PrivateFrameworks/SensitiveContentAnalysisUI.framework/SensitiveContentAnalysisUI"
      )
    )
    #expect(
      !scope.contains(
        imagePath:
          "/Library/Developer/CoreSimulator/Volumes/iOS/RuntimeRoot/System/Library/PrivateFrameworks/SensitiveContentAnalysisUI.framework/SensitiveContentAnalysisUI"
      )
    )
  }

  @Test("A sibling with the same path prefix is excluded")
  func siblingBundle() {
    #expect(
      !scope.contains(
        imagePath:
          "/private/var/containers/Bundle/Application/UUID/Example.app-copy/Example"
      )
    )
  }

  @Test("A path that escapes the bundle is excluded")
  func escapingPath() {
    #expect(
      !scope.contains(
        imagePath:
          "/private/var/containers/Bundle/Application/UUID/Example.app/../System.framework/System"
      )
    )
  }
}
