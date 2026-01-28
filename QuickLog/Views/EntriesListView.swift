import SwiftUI

struct EntriesListView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Saved")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    let visibleEntries: [Entry] = {
                        if let pending = appState.pendingEntry {
                            // Don't show a duplicate if an identical entry already exists at the top.
                            if let first = appState.entries.first, first.content == pending.content {
                                return appState.entries
                            }
                            return [pending] + appState.entries
                        }
                        return appState.entries
                    }()

                    ForEach(visibleEntries) { entry in
                        let isCurrent = (appState.pendingEntry?.id == entry.id) || (appState.editorContext == .entry(id: entry.id))

                        Button {
                            appState.openEntryForEditing(entry.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(entry.preview.isEmpty ? "(empty)" : entry.preview)
                                        .lineLimit(2)
                                    if appState.pendingEntry?.id == entry.id {
                                        Text("draft")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(.white.opacity(0.08))
                                            .clipShape(Capsule())
                                    }
                                }

                                HStack(spacing: 6) {
                                    Text(entry.target.displayName)
                                        .foregroundStyle(.secondary)
                                    Text("·")
                                        .foregroundStyle(.secondary)
                                    Text(DateFormatters.relative.localizedString(for: entry.updatedAt, relativeTo: Date()))
                                        .foregroundStyle(.secondary)
                                }
                                .font(.caption2)
                            }
                            .padding(.vertical, 7)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                ZStack {
                                    if isCurrent {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(.white.opacity(0.14))
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(.white.opacity(0.22), lineWidth: 1)
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                appState.deleteEntry(entry.id)
                            } label: {
                                Text("Delete")
                            }
                        }

                        Rectangle()
                            .fill(.white.opacity(0.08))
                            .frame(height: 1)
                    }
                }
                .padding(.top, 2)
            }
        }
    }
}
