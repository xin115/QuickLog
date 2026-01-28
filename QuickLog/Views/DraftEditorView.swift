import SwiftUI

struct DraftEditorView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("Draft")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(appState.saveTargetName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Save") { appState.saveOnly() }
                    .keyboardShortcut("s", modifiers: [.command])

                Button("Next") { appState.saveAndNext() }
                    .keyboardShortcut(.return, modifiers: [.option])
            }

            TextEditor(text: $appState.draftContent)
                .font(.system(size: 13))
                .padding(6)
                .background(.clear)
                .scrollContentBackground(.hidden)

            HStack {
                Spacer()
                Text("autosave")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
