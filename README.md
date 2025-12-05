# Storybook for iOS

This library allows you to view UI components in a catalog-style format.  
In most cases, it works by simply adding a few lines of code, as it gathers SwiftUI preview codes at runtime.

<img width="150px" src="https://github.com/user-attachments/assets/c6819a8a-3685-422b-a561-16ab513ccd54" alt="storybook previewing">

## Setup

1. Install this package into your project.

2. Put the entrypoint view.

```swift
import StorybookKit
import SwiftUI

struct ContentView: View {
  var body: some View {
    Storybook()
  }
}
```

## Example

In app executable module

```swift
#Preview("Circle") {
  Circle()
    .fill(.purple)
    .frame(width: 100, height: 100)
}
```

In a dynamic framework module
```swift
#Preview("Circle") {
  Circle()
    .fill(.purple)
    .frame(width: 100, height: 100)
}
```

In a static library module
```swift
#Preview("Circle") {
  Circle()
    .fill(.purple)
    .frame(width: 100, height: 100)
}
```

> [!IMPORTANT]
> To display all preview codes in a statically linked binary, you may need to link the binary with the -all_load linker flag.
> This is because the linker does not load symbols into the target binary if it deems them unnecessary.

<img width="150px" src="https://github.com/user-attachments/assets/f849a5a1-c0df-4551-a9a8-c5a0367fe459" alt="list of modules">

## Maintainers

- [Hiroshi Kimura (Muukii)](https://github.com/muukii)
- [John Estropia](https://github.com/johnestropia)

## License

Storybook-ios is released under the MIT license.


