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
                    ForEach(appState.entries) { entry in
                        Button {
                            appState.openEntryForEditing(entry.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.preview.isEmpty ? "(empty)" : entry.preview)
                                    .lineLimit(2)

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
                            .padding(.vertical, 6)
                            .padding(.horizontal, 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
