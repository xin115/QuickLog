import SwiftUI

struct RightPanelView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Right Panel", selection: $appState.rightPanelMode) {
                ForEach(RightPanelMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: appState.rightPanelMode) { _ in
                appState.saveSettings()
            }

            switch appState.rightPanelMode {
            case .notes:
                NotesListView()
            case .history:
                EntriesListView()
            }
        }
    }
}
