import SwiftUI

struct DraftEditorView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Notes")
                    .font(.headline)

                Spacer()

                Text("Target: \(appState.saveTargetName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Mode", selection: $appState.editorMode) {
                    ForEach(EditorMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                if appState.editorMode == .markdown {
                    Toggle("Preview", isOn: $appState.showMarkdownPreview)
                        .toggleStyle(.switch)
                }
            }

            if appState.editorMode == .markdown, appState.showMarkdownPreview {
                ScrollView {
                    if let attributed = try? AttributedString(markdown: appState.draftContent) {
                        Text(attributed)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(appState.draftContent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(10)
                .background(.background.opacity(0.6))
                .cornerRadius(8)
            } else {
                TextEditor(text: $appState.draftContent)
                    .font(.body)
                    .padding(6)
                    .background(.background.opacity(0.6))
                    .cornerRadius(8)
            }

            HStack {
                Button("Save") {
                    appState.saveOnly()
                }
                .keyboardShortcut("s", modifiers: [.command])

                Button("Save & Next") {
                    appState.saveAndNext()
                }
                .keyboardShortcut(.return, modifiers: [.option])

                Spacer()

                Text("Autosaves every 5s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
