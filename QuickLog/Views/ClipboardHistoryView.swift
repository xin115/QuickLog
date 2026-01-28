import SwiftUI
import AppKit

struct ClipboardHistoryView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            List {
                ForEach(appState.clipboardHistory) { item in
                    ClipboardRow(item: item)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(.clear)
        }
    }

    private var header: some View {
        HStack {
            Text("Clipboard")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }
}

private struct ClipboardRow: View {
    @EnvironmentObject var appState: AppState
    let item: ClipboardItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.preview)
                    .font(.system(size: 12))
                    .lineLimit(3)

                Text(item.formattedTimestamp)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Button {
                    copyToPasteboard(item.content)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy to clipboard")

                Button {
                    appState.insertIntoEditor(item.content + "\n")
                } label: {
                    Image(systemName: "arrow.down.left")
                }
                .buttonStyle(.borderless)
                .help("Insert into draft")
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            copyToPasteboard(item.content)
        }
        .contextMenu {
            Button("Copy") { copyToPasteboard(item.content) }
            Button("Insert into Draft") { appState.insertIntoEditor(item.content + "\n") }
        }
    }

    private func copyToPasteboard(_ string: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
    }
}
