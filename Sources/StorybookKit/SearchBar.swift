import SwiftUI

struct SearchBar: View {

  @Binding var text: String

  var body: some View {

    ZStack {

      RoundedRectangle(cornerRadius: 8)
        .fill(Color(red: 239 / 255,
                    green: 239 / 255,
                    blue: 241 / 255))
        .frame(height: 36)

      HStack(spacing: 6) {

        Image(systemName: "magnifyingglass")
          .foregroundColor(.gray)

        TextField("Search", text: $text)
          .autocorrectionDisabled()
          #if canImport(UIKit)
          .textInputAutocapitalization(.never)
          #endif

        if !text.isEmpty {
          Button {
            text.removeAll()
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundColor(.gray)
          }
          .padding(.trailing, 6)
        }
      }
      .padding()
    }

  }
}

#if DEBUG

enum Preview_SearchBar: PreviewProvider {

  static var previews: some View {

    Group {
      SearchBar(text: .constant("A"))
    }

  }

}

#endif
