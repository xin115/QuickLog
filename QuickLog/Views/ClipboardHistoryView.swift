import SwiftUI
import AppKit

struct ClipboardHistoryView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(appState.clipboardHistory) { item in
                            ClipboardRow(item: item)
                                .id(item.id)

                            Rectangle()
                                .fill(.white.opacity(0.08))
                                .frame(height: 1)
                        }
                    }
                    .padding(.top, 2)
                }
                .scrollIndicators(.hidden)
                .onChange(of: appState.clipboardHistory.first?.id) { newId in
                    // Keep newest item visible.
                    guard let newId else { return }
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(newId, anchor: .top)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Clipboard")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("\(appState.clipboardHistory.count)/\(appState.settings.clipboardHistorySize)")
                .font(.caption2)
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
            VStack(alignment: .leading, spacing: 6) {
                switch item.content {
                case .text:
                    Text(item.preview)
                        .font(.system(size: 12))
                        .lineLimit(3)
                case .image:
                    if let img = item.nsImage {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(.white.opacity(0.18), lineWidth: 1)
                            )
                    } else {
                        Text("(image)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(item.formattedTimestamp)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Button {
                    copyToPasteboard(item)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy to clipboard")

                Button {
                    if let text = item.content.text {
                        appState.insertIntoEditor(text + "\n")
                    }
                } label: {
                    Image(systemName: "arrow.down.left")
                }
                .disabled(item.content.text == nil)
                .buttonStyle(.borderless)
                .help("Insert into draft")
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            copyToPasteboard(item)
        }
        .contextMenu {
            Button("Copy") { copyToPasteboard(item) }
            if let text = item.content.text {
                Button("Insert into Draft") { appState.insertIntoEditor(text + "\n") }
            }
        }
    }

    private func copyToPasteboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()

        switch item.content {
        case .text(let s):
            pb.setString(s, forType: .string)
        case .image(let data):
            if let img = NSImage(data: data) {
                pb.writeObjects([img])
            }
        }
    }
}
