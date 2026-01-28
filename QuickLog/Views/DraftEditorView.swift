import SwiftUI

struct DraftEditorView: View {
    @EnvironmentObject var appState: AppState

    @State private var showingManageNotes = false
    @State private var autosaveTick: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(appState.editorContext.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if case .note(let id) = appState.editorContext,
                   let note = appState.notes.first(where: { $0.id == id }) {
                    Text(note.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("autosave")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("New") {
                    appState.newDraft()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button {
                    showingManageNotes = true
                } label: {
                    Image(systemName: "note.text")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Manage notes")
            }

            TextEditor(text: $appState.draftContent)
                .font(.system(size: 13))
                .padding(6)
                .background(.clear)
                .scrollContentBackground(.hidden)
                .onChange(of: appState.draftContent) { _ in
                    // (Optional) view tick, compatible with older macOS.
                    autosaveTick &+= 1
                }

            HStack {
                Spacer()
                Text("autosave")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showingManageNotes) {
            NotesListView()
                .environmentObject(appState)
                .padding(14)
                .frame(minWidth: 360, minHeight: 420)
        }
    }
}
