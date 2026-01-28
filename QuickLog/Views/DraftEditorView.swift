import SwiftUI

struct DraftEditorView: View {
    @EnvironmentObject var appState: AppState

    @State private var autosaveTick: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(appState.editorContext.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if case .entry(let id) = appState.editorContext,
                   let entry = appState.entries.first(where: { $0.id == id }) {
                    Text(entry.target.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("autosave")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !appState.lastSaveStatus.isEmpty {
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(appState.lastSaveStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Button("New") {
                    appState.commitDraftAndNew()
                }
                .keyboardShortcut("n", modifiers: [.command])
                .disabled(appState.editorContext == .draft && appState.draftContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            TextEditor(text: $appState.draftContent)
                .font(.system(size: 13))
                .padding(6)
                .background(.clear)
                .scrollContentBackground(.hidden)
                .onChange(of: appState.draftContent) { _ in
                    autosaveTick &+= 1

                    // Keep the right panel in sync with what's being typed.
                    appState.saveDraft()

                    if case .entry = appState.editorContext {
                        appState.forceAutosaveNow()
                    }
                }

            HStack {
                Spacer()
                Text("autosave")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
