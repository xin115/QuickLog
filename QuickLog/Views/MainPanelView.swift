import SwiftUI

struct MainPanelView: View {
    @EnvironmentObject var appState: AppState

    static let dividerWidth: CGFloat = 1

    @State private var leftWidth: CGFloat = 260
    @State private var centerWidth: CGFloat = 560
    @State private var rightWidth: CGFloat = 260

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Single, clean top divider line like Unclutter.
                Rectangle()
                    .fill(.white.opacity(0.10))
                    .frame(height: 1)

                HStack(spacing: 0) {
                    panelColumn(edge: .leading) { ClipboardHistoryView() }
                        .frame(width: clamp(leftWidth, min: 220, max: geo.size.width - 520))

                    Splitter { dx in
                        leftWidth = clamp(leftWidth + dx, min: 220, max: geo.size.width - 520)
                        persistWidths(totalWidth: geo.size.width)
                    }

                    panelColumn(edge: .center) { DraftEditorView() }
                        .frame(width: clamp(centerWidth, min: 420, max: geo.size.width - 440))

                    Splitter { dx in
                        centerWidth = clamp(centerWidth + dx, min: 420, max: geo.size.width - 440)
                        persistWidths(totalWidth: geo.size.width)
                    }

                    Rectangle()
                        .fill(.white.opacity(0.08))
                        .frame(width: Self.dividerWidth)

                    panelColumn(edge: .trailing) { EntriesListView() }
                        .frame(width: clamp(rightWidth, min: 220, max: geo.size.width - 520))
                }
                // IMPORTANT: without this, the HStack will shrink to its content width
                // and end up centered inside the full-width panel, making left/right
                // columns look "pulled in".
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .topLeading) {
                    if DebugLog.enabled {
                        let used = leftWidth + centerWidth + rightWidth + (Splitter.width * 2) + Self.dividerWidth
                        Text("geo=\(Int(geo.size.width)) used=\(Int(used)) L=\(Int(leftWidth)) C=\(Int(centerWidth)) R=\(Int(rightWidth))")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .padding(6)
                    }
                }
                .overlay {
                    if DebugLog.enabled {
                        Rectangle()
                            .stroke(.red.opacity(0.35), lineWidth: 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onAppear {
                leftWidth = CGFloat(appState.settings.leftPanelWidth)
                centerWidth = CGFloat(appState.settings.centerPanelWidth)
                rightWidth = CGFloat(appState.settings.rightPanelWidth)
                normalizeToFit(totalWidth: geo.size.width)
                // Ensure the right column fills remaining space even on first render.
                persistWidths(totalWidth: geo.size.width)
            }
            .onChange(of: geo.size.width) { newWidth in
                // Keep layout filling the window when the panel/frame changes.
                persistWidths(totalWidth: newWidth)
            }
            .background(.ultraThinMaterial)
        }
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
        // Remove the outermost padding so the left/right columns sit flush to the window edges.
        .padding(.leading, edge == .leading ? 0 : 12)
        .padding(.trailing, edge == .trailing ? 0 : 12)
        .padding(.vertical, 10)
    }

    private func persistWidths(totalWidth: CGFloat) {
        // Adjust right width to fill remaining space.
        let chrome: CGFloat = (Splitter.width * 2) + Self.dividerWidth
        // Fill the remaining space exactly.
        rightWidth = max(220, totalWidth - leftWidth - centerWidth - chrome)
        appState.updatePanelWidths(left: leftWidth, center: centerWidth, right: rightWidth)
    }

    private func normalizeToFit(totalWidth: CGFloat) {
        let chrome: CGFloat = (Splitter.width * 2) + Self.dividerWidth
        let available = max(0, totalWidth - chrome)
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
