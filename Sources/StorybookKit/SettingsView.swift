import SwiftUI

struct SettingsView: View {

  private static let userDefaults = UserDefaults(suiteName: "jp.eure.storybook2") ?? .standard

  @Environment(\.dismiss) private var dismiss

  @AppStorage("autoOpenLastPage", store: SettingsView.userDefaults)
  private var autoOpenLastPage: Bool = true

  var body: some View {
    NavigationStack {
      List {
        Section {
          Toggle(isOn: $autoOpenLastPage) {
            VStack(alignment: .leading, spacing: 4) {
              Text("Auto-open last page")
              Text("Automatically open the last visited page on launch")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        } header: {
          Text("Startup")
        }
      }
      .navigationTitle("Settings")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            dismiss()
          } label: {
            Text("Done")
              .fontWeight(.semibold)
          }
        }
      }
    }
  }
}
