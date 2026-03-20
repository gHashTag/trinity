import SwiftUI

// Cortex: Entorhinal Cortex — Navigation & Grid Cells
struct KingdomSidebar: View {
    @Binding var selection: Screen?

    // Realm colors from photon_trinity_canvas.zig
    static let realmColors: [Kingdom: Color] = [
        .brain: Color(red: 1.0, green: 215.0/255.0, blue: 0),           // Gold (RAZUM)
        .body: Color(red: 80.0/255.0, green: 250.0/255.0, blue: 250.0/255.0), // Cyan (MATERIYA)
        .spirit: Color(red: 189.0/255.0, green: 147.0/255.0, blue: 249.0/255.0), // Purple (DUKH)
    ]

    var body: some View {
        // Cortex: Entorhinal Sidebar — Responsive 220-400px
        EntorhinalSidebar {
            sidebarContent
        }
    }

    private var sidebarContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Kingdom.allCases) { kingdom in
                    // Realm header
                    Text(realmTitle(kingdom))
                        .font(WernickeTypography.caption2Bold.monospaced())
                        .foregroundStyle(Self.realmColors[kingdom] ?? .white)
                        .padding(.vertical, LayoutConstants.compactSpacing)
                        .padding(.horizontal, LayoutConstants.standardPadding)

                    // Screen items
                    ForEach(Screen.screens(for: kingdom)) { screen in
                        Button {
                            selection = screen
                        } label: {
                            HStack(spacing: ParietalSpacing.sm) {
                                Text(screen.icon)
                                    .font(WernickeTypography.small)
                                Text(screen.rawValue)
                                    .font(WernickeTypography.small.monospaced())
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, ParietalSpacing.xxxs)
                            .padding(.horizontal, ParietalSpacing.md)
                            .background(
                                selection == screen
                                    ? (Self.realmColors[screen.kingdom] ?? .white).opacity(V2Depth.bgSidebarHover)
                                    : Color.clear
                            )
                            .foregroundStyle(
                                selection == screen
                                    ? .white
                                    : V4Color.textSecondary
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 8)
        }
        .background(Color.black)
    }

    private func realmTitle(_ kingdom: Kingdom) -> String {
        switch kingdom {
        case .brain: return "RAZUM"
        case .body: return "MATERIYA"
        case .spirit: return "DUKH"
        }
    }
}
