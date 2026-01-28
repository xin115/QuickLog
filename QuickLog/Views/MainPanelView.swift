import SwiftUI

struct MainPanelView: View {
    @EnvironmentObject var appState: AppState

    static let dividerWidth: CGFloat = 1

    @State private var leftWidth: CGFloat = 260
    @State private var rightWidth: CGFloat = 260

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width

            VStack(spacing: 0) {
                Rectangle()
                    .fill(.white.opacity(0.10))
                    .frame(height: 1)

                columns(totalWidth: totalWidth)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.ultraThinMaterial)
            .onAppear {
                leftWidth = CGFloat(appState.settings.leftPanelWidth)
                rightWidth = CGFloat(appState.settings.rightPanelWidth)
                normalizeToFit(totalWidth: totalWidth)
                persistWidths(totalWidth: totalWidth)
            }
            .onChange(of: totalWidth) { newWidth in
                normalizeToFit(totalWidth: newWidth)
                persistWidths(totalWidth: newWidth)
            }
        }
    }

    @ViewBuilder
    private func columns(totalWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            panelColumn(edge: .leading) { ClipboardHistoryView() }
                .frame(width: leftWidth)

            Splitter { dx in
                leftWidth += dx
                normalizeToFit(totalWidth: totalWidth)
                persistWidths(totalWidth: totalWidth)
            }

            panelColumn(edge: .center) { DraftEditorView() }
                .frame(width: centerWidth(totalWidth: totalWidth))

            Splitter { dx in
                // Dragging this splitter adjusts the RIGHT column width.
                rightWidth -= dx
                normalizeToFit(totalWidth: totalWidth)
                persistWidths(totalWidth: totalWidth)
            }

            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(width: Self.dividerWidth)

            panelColumn(edge: .trailing) { EntriesListView() }
                .frame(width: rightWidth)
        }
        // Force the HStack to occupy the full width so it doesn't center itself.
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum ColumnEdge {
        case leading
        case center
        case trailing
    }

    @ViewBuilder
    private func panelColumn<Content: View>(edge: ColumnEdge, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 8) {
            content()
        }
        .padding(.leading, edge == .leading ? 12 : 12)
        .padding(.trailing, edge == .trailing ? 0 : 12)
        .padding(.vertical, 10)
    }

    private func chromeWidth() -> CGFloat {
        (Splitter.width * 2) + Self.dividerWidth
    }

    private func centerWidth(totalWidth: CGFloat) -> CGFloat {
        let c = totalWidth - leftWidth - rightWidth - chromeWidth()
        return max(420, c)
    }

    private func persistWidths(totalWidth: CGFloat) {
        appState.updatePanelWidths(left: leftWidth,
                                   center: centerWidth(totalWidth: totalWidth),
                                   right: rightWidth)
    }

    private func normalizeToFit(totalWidth: CGFloat) {
        let available = max(0, totalWidth - chromeWidth())
        let minCenter: CGFloat = 420
        let minSide: CGFloat = 220

        // Clamp sides so center can exist.
        let maxSide = max(minSide, (available - minCenter - minSide))
        leftWidth = clamp(leftWidth, min: minSide, max: maxSide)
        rightWidth = clamp(rightWidth, min: minSide, max: maxSide)

        // If still too tight, shrink the larger sidebar.
        var c = available - leftWidth - rightWidth
        if c < minCenter {
            let deficit = minCenter - c
            if leftWidth >= rightWidth {
                leftWidth = max(minSide, leftWidth - deficit)
            } else {
                rightWidth = max(minSide, rightWidth - deficit)
            }
        }
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
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        onDrag(value.translation.width)
                    }
            )
    }
}
