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
                ForEach(TriToolCommandCatalog.commands.prefix(3)) { command in
                    Label(command.title, systemImage: command.systemImage)
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                }
            }
            .padding(ParietalSpacing.xs)
            .background(V4Color.surface)
        }
    }
}
