import SwiftUI

struct DraftEditorView: View {
    @EnvironmentObject var appState: AppState

    @State private var showingManageNotes = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("Draft")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Picker("Target", selection: $appState.selectedNoteId) {
                    Text("Today's Log").tag(UUID?.none)
                    ForEach(appState.notes) { note in
                        Text(note.title).tag(Optional(note.id))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .font(.caption)

                Button {
                    showingManageNotes = true
                } label: {
                    Image(systemName: "note.text")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Manage notes")

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
        .sheet(isPresented: $showingManageNotes) {
            NotesListView()
                .environmentObject(appState)
                .padding(14)
                .frame(minWidth: 360, minHeight: 420)
        }
    }
}
