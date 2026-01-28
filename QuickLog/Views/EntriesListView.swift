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

            List {
                ForEach(appState.entries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.preview.isEmpty ? "(empty)" : entry.preview)
                            .lineLimit(2)

                        HStack(spacing: 6) {
                            Text(entry.target.displayName)
                                .foregroundStyle(.secondary)
                            Text("·")
                                .foregroundStyle(.secondary)
                            Text(DateFormatters.relative.localizedString(for: entry.createdAt, relativeTo: Date()))
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption2)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            appState.deleteEntry(entry.id)
                        } label: {
                            Text("Delete")
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}
