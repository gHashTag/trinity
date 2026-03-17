import SwiftUI

struct KingdomSidebar: View {
    @Binding var selection: Screen?

    // Realm colors from photon_trinity_canvas.zig
    static let realmColors: [Kingdom: Color] = [
        .brain: Color(red: 1.0, green: 215.0/255.0, blue: 0),           // Gold (RAZUM)
        .body: Color(red: 80.0/255.0, green: 250.0/255.0, blue: 250.0/255.0), // Cyan (MATERIYA)
        .spirit: Color(red: 189.0/255.0, green: 147.0/255.0, blue: 249.0/255.0), // Purple (DUKH)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Kingdom.allCases) { kingdom in
                    // Realm header
                    Text(realmTitle(kingdom))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Self.realmColors[kingdom] ?? .white)
                        .padding(.top, 16)
                        .padding(.bottom, 4)
                        .padding(.horizontal, 16)

                    // Screen items
                    ForEach(Screen.screens(for: kingdom)) { screen in
                        Button {
                            selection = screen
                        } label: {
                            HStack(spacing: 8) {
                                Text(screen.icon)
                                    .font(.system(size: 13))
                                Text(screen.rawValue)
                                    .font(.system(size: 13, design: .monospaced))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 16)
                            .background(
                                selection == screen
                                    ? (Self.realmColors[screen.kingdom] ?? .white).opacity(0.15)
                                    : Color.clear
                            )
                            .foregroundStyle(
                                selection == screen
                                    ? .white
                                    : TrinityTheme.textMuted
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
