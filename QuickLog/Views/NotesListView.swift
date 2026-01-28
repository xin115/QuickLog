import SwiftUI

struct NotesListView: View {
    @EnvironmentObject var appState: AppState

    @State private var showingCreate = false
    @State private var newTitle: String = ""
    @State private var editingNoteId: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Notes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    editingNoteId = nil
                    newTitle = ""
                    showingCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }

            List(selection: $appState.selectedNoteId) {
                Text("Today's Log")
                    .tag(UUID?.none)

                ForEach(appState.notes) { note in
                    Text(note.title)
                        .tag(Optional(note.id))
                        .contextMenu {
                            Button("Rename") {
                                editingNoteId = note.id
                                newTitle = note.title
                                showingCreate = true
                            }

                            Button(role: .destructive) {
                                appState.deleteNote(noteId: note.id)
                            } label: {
                                Text("Delete")
                            }
                        }
                }
            }
            .listStyle(.plain)
        }
        .sheet(isPresented: $showingCreate) {
            VStack(alignment: .leading, spacing: 12) {
                Text("New / Rename Note")
                    .font(.headline)

                TextField("Title", text: $newTitle)

                HStack {
                    Button("Cancel") {
                        showingCreate = false
                        newTitle = ""
                        editingNoteId = nil
                    }

                    Spacer()

                    Button("Save") {
                        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }

                        if let id = editingNoteId {
                            appState.renameNote(noteId: id, newTitle: trimmed)
                        } else {
                            appState.createNote(title: trimmed)
                        }

                        showingCreate = false
                        newTitle = ""
                        editingNoteId = nil
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(width: 360)
        }
    }
}
