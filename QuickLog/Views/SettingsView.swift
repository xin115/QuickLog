import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Panel") {
                HStack {
                    Text("Height ratio")
                    Slider(value: $appState.settings.panelHeightRatio, in: 0.25...0.60, step: 0.01)
                    Text(String(format: "%.2f", appState.settings.panelHeightRatio))
                        .monospacedDigit()
                }

                HStack {
                    Text("Width")
                    Slider(value: $appState.settings.panelWidth, in: 800...1400, step: 10)
                    Text("\(Int(appState.settings.panelWidth))")
                        .monospacedDigit()
                }
            }

            Section("Clipboard") {
                Stepper("History size: \(appState.settings.clipboardHistorySize)", value: $appState.settings.clipboardHistorySize, in: 10...200, step: 5)
            }

            Section("Editor") {
                Picker("Default mode", selection: $appState.settings.defaultEditorMode) {
                    ForEach(EditorMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

                Toggle("Markdown preview default", isOn: $appState.settings.markdownPreviewDefault)
            }

            Button("Save Settings") {
                appState.saveSettings()
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
