import SwiftUI

struct MainPanelView: View {
    @EnvironmentObject var appState: AppState

    @State private var leftWidth: CGFloat = 260
    @State private var centerWidth: CGFloat = 560
    @State private var rightWidth: CGFloat = 260

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                panelColumn { ClipboardHistoryView() }
                    .frame(width: clamp(leftWidth, min: 220, max: geo.size.width - 520))

                Splitter { dx in
                    leftWidth = clamp(leftWidth + dx, min: 220, max: geo.size.width - 520)
                    persistWidths(totalWidth: geo.size.width)
                }

                panelColumn { DraftEditorView() }
                    .frame(width: clamp(centerWidth, min: 420, max: geo.size.width - 440))

                Splitter { dx in
                    centerWidth = clamp(centerWidth + dx, min: 420, max: geo.size.width - 440)
                    persistWidths(totalWidth: geo.size.width)
                }

                panelColumn { NotesListView() }
                    .frame(width: clamp(rightWidth, min: 220, max: geo.size.width - 520))
            }
            .onAppear {
                leftWidth = CGFloat(appState.settings.leftPanelWidth)
                centerWidth = CGFloat(appState.settings.centerPanelWidth)
                rightWidth = CGFloat(appState.settings.rightPanelWidth)

                // If saved widths don't fit current window, normalize.
                normalizeToFit(totalWidth: geo.size.width)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            )
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private func panelColumn<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 10) {
            content()
        }
        .padding(10)
    }

    private func persistWidths(totalWidth: CGFloat) {
        // Adjust right width to fill remaining space.
        let splitterTotal: CGFloat = Splitter.width * 2
        rightWidth = max(220, totalWidth - leftWidth - centerWidth - splitterTotal - 24) // extra padding
        appState.updatePanelWidths(left: leftWidth, center: centerWidth, right: rightWidth)
    }

    private func normalizeToFit(totalWidth: CGFloat) {
        let splitterTotal: CGFloat = Splitter.width * 2
        let available = max(0, totalWidth - splitterTotal)
        let sum = leftWidth + centerWidth + rightWidth
        guard sum > 0, sum > available else { return }
        let scale = available / sum
        leftWidth *= scale
        centerWidth *= scale
        rightWidth *= scale
    }

    private func clamp(_ v: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.max(min, Swift.min(max, v))
    }
}

private struct Splitter: View {
    static let width: CGFloat = 8
    let onDrag: (CGFloat) -> Void

    init(_ onDrag: @escaping (CGFloat) -> Void) {
        self.onDrag = onDrag
    }

    var body: some View {
        Rectangle()
            .fill(.clear)
            .frame(width: Self.width)
            .contentShape(Rectangle())
            .overlay(
                Rectangle()
                    .fill(.white.opacity(0.10))
                    .frame(width: 1)
            )
            // cursor styling (optional)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        onDrag(value.translation.width)
                    }
            )
    }
}
