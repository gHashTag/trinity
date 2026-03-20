import SwiftUI

/// Tri Tools Panel — collapsible sidebar panel
public struct TriToolsPanel: View {
    @Binding var isExpanded: Bool

    public init(isExpanded: Binding<Bool>) {
        self._isExpanded = isExpanded
    }

    public var body: some View {
        if isExpanded {
            VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                Text("Tri Tools")
                    .font(.caption.weight(.bold))
                Text("Coming soon")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(ParietalSpacing.xs)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }
}
