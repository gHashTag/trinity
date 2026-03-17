// Empty State View — Empty State Illustrations and Messages
import SwiftUI

// MARK: - Empty State View

struct DetailedEmptyState: View {
    let icon: String?
    let title: String
    let message: String
    let actionTitle: String?
    let action: () -> Void

    init(
        icon: String? = nil,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: @escaping () -> Void = {}
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Icon or illustration
            if let icon = icon {
                ZStack {
                    Circle()
                        .fill(TrinityTheme.bgCardBorder.opacity(0.3))
                        .frame(width: 80, height: 80)

                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundStyle(TrinityTheme.textMuted)
                }
            } else {
                // Default illustration
                emptyIllustration
            }

            // Title and message
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(TrinityTheme.textPrimary)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(TrinityTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            // Action button
            if let actionTitle = actionTitle {
                Button {
                    action()
                } label: {
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(TrinityTheme.accent)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    private var emptyIllustration: some View {
        ZStack {
            Circle()
                .fill(TrinityTheme.bgCardBorder.opacity(0.3))
                .frame(width: 100, height: 100)

            VStack(spacing: 4) {
                ForEach(0..<3) { _ in
                    Rectangle()
                        .fill(TrinityTheme.bgCardBorder)
                        .frame(width: 40, height: 3)
                }
            }
        }
    }
}

// MARK: - Compact Empty State

struct CompactEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(TrinityTheme.textMuted)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TrinityTheme.textPrimary)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
            }

            Spacer()
        }
        .padding(16)
        .background(TrinityTheme.bgCard)
        .cornerRadius(TrinityTheme.cornerMedium)
    }
}

// MARK: - List Empty State

struct ListEmptyState: View {
    let title: String
    let message: String
    let icon: String?

    init(
        title: String = "No Items",
        message: String = "There are no items to display",
        icon: String? = nil
    ) {
        self.title = title
        self.message = message
        self.icon = icon
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon ?? "tray")
                .font(.system(size: 40))
                .foregroundStyle(TrinityTheme.bgCardBorder)

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(TrinityTheme.textPrimary)

            Text(message)
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background(TrinityTheme.bgCard)
    }
}

// MARK: - Search Empty State

struct SearchEmptyState: View {
    let query: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(TrinityTheme.bgCardBorder)

            Text("No results for \"\(query)\"")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(TrinityTheme.textPrimary)

            Text("Try adjusting your search terms")
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Error Empty State

struct ErrorEmptyState: View {
    let title: String
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(TrinityTheme.statusWarn)

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(TrinityTheme.textPrimary)

            Text(message)
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)

            Button {
                retry()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                    Text("Try Again")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(TrinityTheme.accent)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Placeholder Views

struct PlaceholderViews {
    static func noThreads() -> some View {
        ListEmptyState(
            title: "No Threads",
            message: "Start a conversation to see it here",
            icon: "bubble.left.and.bubble.right"
        )
    }

    static func noMessages() -> some View {
        ListEmptyState(
            title: "No Messages",
            message: "Be the first to send a message",
            icon: "message"
        )
    }

    static func noFiles() -> some View {
        ListEmptyState(
            title: "No Files",
            message: "Upload files to get started",
            icon: "doc"
        )
    }

    static func noNotifications() -> some View {
        ListEmptyState(
            title: "All Caught Up",
            message: "You have no new notifications",
            icon: "bell"
        )
    }

    static func noSearchResults(query: String) -> some View {
        SearchEmptyState(query: query)
    }
}

// MARK: - Preview

struct DetailedEmptyStates_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DetailedEmptyState(
                icon: "tray",
                title: "No Data",
                message: "There's nothing here yet. Create your first item to get started.",
                actionTitle: "Create Item"
            )
            .frame(width: 400, height: 300)
            .padding()
            .background(TrinityTheme.bgWindow)

            CompactEmptyState(
                icon: "folder.badge.questionmark",
                title: "Empty Folder",
                message: "This folder contains no items"
            )
            .frame(width: 350)
            .padding()
            .background(TrinityTheme.bgWindow)

            PlaceholderViews.noSearchResults(query: "test")
                .frame(width: 400, height: 200)
                .padding()
                .background(TrinityTheme.bgWindow)
        }
    }
}
