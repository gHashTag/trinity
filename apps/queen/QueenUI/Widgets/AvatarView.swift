// Avatar View — User Avatars and Profiles
import SwiftUI

// MARK: - Avatar

struct Avatar: View {
    let name: String
    let imageURL: URL?
    let size: AvatarSize
    let status: UserStatus?

    enum AvatarSize {
        case small, medium, large, xLarge

        var dimension: CGFloat {
            switch self {
            case .small: return 28
            case .medium: return 40
            case .large: return 56
            case .xLarge: return 80
            }
        }
    }

    enum UserStatus {
        case online, away, busy, offline

        var color: Color {
            switch self {
            case .online: return TrinityTheme.statusOK
            case .away: return TrinityTheme.statusWarn
            case .busy: return TrinityTheme.statusError
            case .offline: return TrinityTheme.textMuted
            }
        }
    }

    init(
        name: String,
        imageURL: URL? = nil,
        size: AvatarSize = .medium,
        status: UserStatus? = nil
    ) {
        self.name = name
        self.imageURL = imageURL
        self.size = size
        self.status = status
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let imageURL = imageURL {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholder
                }
                .frame(width: size.dimension, height: size.dimension)
                .clipShape(Circle())
            } else {
                placeholder
            }

            if let status = status {
                Circle()
                    .fill(status.color)
                    .frame(width: size.dimension / 4, height: size.dimension / 4)
                    .overlay(
                        Circle()
                            .stroke(TrinityTheme.bgCard, lineWidth: 1)
                    )
                    .offset(x: size.dimension / 8, y: size.dimension / 8)
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Circle()
                .fill(initialsBackground)
                .frame(width: size.dimension, height: size.dimension)

            Text(initials)
                .font(.system(size: size.dimension * 0.35, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var initials: String {
        let components = name.components(separatedBy: .whitespacesAndNewlines)
        return components
            .filter { !$0.isEmpty }
            .prefix(2)
            .map { String($0.first!).uppercased() }
            .joined()
    }

    private var initialsBackground: Color {
        let hash = name.reduce(0) { $0 + Int($1.asciiValue ?? 0) }
        let colors: [Color] = [.blue, .purple, .pink, .red, .orange, .yellow, .green, .teal]
        return colors[hash % colors.count]
    }
}

// MARK: - Avatar Group

struct AvatarGroup: View {
    let avatars: [AvatarGroupItem]
    let maxVisible: Int
    let overlapAmount: CGFloat

    struct AvatarGroupItem {
        let name: String
        let imageURL: URL?
    }

    init(
        avatars: [AvatarGroupItem],
        maxVisible: Int = 5,
        overlapAmount: CGFloat = 12
    ) {
        self.avatars = avatars
        self.maxVisible = maxVisible
        self.overlapAmount = overlapAmount
    }

    var body: some View {
        ZStack(alignment: .leading) {
            ForEach(Array(avatars.prefix(maxVisible).enumerated()), id: \.offset) { index, item in
                Avatar(name: item.name, imageURL: item.imageURL, size: .small)
                    .offset(x: CGFloat(index) * (28 - overlapAmount))
            }

            if avatars.count > maxVisible {
                Avatar(
                    name: "+\(avatars.count - maxVisible)",
                    size: .small
                )
                .offset(x: CGFloat(maxVisible) * (28 - overlapAmount))
            }
        }
        .frame(height: 28)
    }
}

// MARK: - User Profile Card

struct UserProfileCard: View {
    let name: String
    let username: String?
    let bio: String?
    let imageURL: URL?
    let followers: Int?
    let following: Int?
    let isVerified: Bool
    let onAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Avatar(name: name, imageURL: imageURL, size: .xLarge)

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(TrinityTheme.textPrimary)

                    if isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(TrinityTheme.accent)
                    }
                }

                if let username = username {
                    Text("@\(username)")
                        .font(.caption)
                        .foregroundStyle(TrinityTheme.textMuted)
                }

                if let bio = bio {
                    Text(bio)
                        .font(.system(size: 13))
                        .foregroundStyle(TrinityTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
            }

            if let followers = followers, let following = following {
                HStack(spacing: 20) {
                    StatItem(label: "Followers", value: "\(followers)")
                    StatItem(label: "Following", value: "\(following)")
                }
            }

            Button {
                onAction()
            } label: {
                Text("Follow")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(TrinityTheme.accent)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(TrinityTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
    }

    private struct StatItem: View {
        let label: String
        let value: String

        var body: some View {
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TrinityTheme.textPrimary)

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.textMuted)
            }
        }
    }
}

// MARK: - Editable Avatar

struct EditableAvatar: View {
    let name: String
    @Binding var imageURL: URL?
    let size: Avatar.AvatarSize
    let onPickImage: () -> Void

    var body: some View {
        Button {
            onPickImage()
        } label: {
            ZStack(alignment: .bottomTrailing) {
                if let imageURL = imageURL {
                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        placeholder
                    }
                    .frame(width: size.dimension, height: size.dimension)
                    .clipShape(Circle())
                } else {
                    placeholder
                }

                Image(systemName: "camera.fill")
                    .font(.system(size: size.dimension * 0.2))
                    .foregroundStyle(.white)
                    .frame(width: size.dimension * 0.35, height: size.dimension * 0.35)
                    .background(
                        Circle()
                            .fill(TrinityTheme.accent)
                    )
                    .offset(x: size.dimension / 8, y: size.dimension / 8)
            }
        }
        .buttonStyle(.plain)
    }

    private var placeholder: some View {
        ZStack {
            Circle()
                .fill(TrinityTheme.bgCardBorder)
                .frame(width: size.dimension, height: size.dimension)

            Image(systemName: "person.fill")
                .font(.system(size: size.dimension * 0.4))
                .foregroundStyle(TrinityTheme.textMuted)
        }
    }

    private var initials: String {
        let components = name.components(separatedBy: .whitespacesAndNewlines)
        return components
            .filter { !$0.isEmpty }
            .prefix(2)
            .map { String($0.first!).uppercased() }
            .joined()
    }
}

// MARK: - Mention Avatar

struct MentionAvatar: View {
    let mention: String

    var body: some View {
        HStack(spacing: 6) {
            Text("@")
                .font(.system(size: 11))
                .foregroundStyle(TrinityTheme.accent)

            Text(mention)
                .font(.system(size: 13))
                .foregroundStyle(TrinityTheme.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(TrinityTheme.accent.opacity(0.1))
        )
    }
}

// MARK: - User Status Indicator

struct UserStatusIndicator: View {
    let status: Avatar.UserStatus
    let showLabel: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)

            if showLabel {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
            }
        }
    }

    private var statusText: String {
        switch status {
        case .online: return "Online"
        case .away: return "Away"
        case .busy: return "Busy"
        case .offline: return "Offline"
        }
    }
}

// MARK: - Preview

struct AvatarView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Avatar(name: "Alice", size: .small, status: .online)
                    Avatar(name: "Bob Smith", size: .medium, status: .away)
                    Avatar(name: "Charlie", size: .large, status: .busy)
                    Avatar(name: "Diana Prince", size: .xLarge, status: .offline)
                }

                AvatarGroup(
                    avatars: [
                        AvatarGroup.AvatarGroupItem(name: "Alice", imageURL: nil),
                        AvatarGroup.AvatarGroupItem(name: "Bob", imageURL: nil),
                        AvatarGroup.AvatarGroupItem(name: "Charlie", imageURL: nil),
                        AvatarGroup.AvatarGroupItem(name: "Diana", imageURL: nil),
                        AvatarGroup.AvatarGroupItem(name: "Eve", imageURL: nil)
                    ]
                )

                UserStatusIndicator(status: .online, showLabel: true)
            }
            .padding()
        }
        .padding()
        .background(TrinityTheme.bgWindow)
    }
}
