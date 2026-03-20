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
            case .online: return V4Color.success
            case .away: return V4Color.warning
            case .busy: return V4Color.error
            case .offline: return V4Color.textSecondary
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
                            .stroke(V4Color.surface, lineWidth: 1)
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
        VStack(spacing: ParietalSpacing.md) {
            Avatar(name: name, imageURL: imageURL, size: .xLarge)

            VStack(spacing: ParietalSpacing.xs) {
                HStack(spacing: ParietalSpacing.xs) {
                    Text(name)
                        .font(WernickeTypography.body16Medium)
                        .foregroundStyle(V4Color.textPrimary)

                    if isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(WernickeTypography.size12)
                            .foregroundStyle(V4Color.accent)
                    }
                }

                if let username = username {
                    Text("@\(username)")
                        .font(.caption)
                        .foregroundStyle(V4Color.textSecondary)
                }

                if let bio = bio {
                    Text(bio)
                        .font(WernickeTypography.size13)
                        .foregroundStyle(V4Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
            }

            if let followers = followers, let following = following {
                HStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
                    StatItem(label: "Followers", value: "\(followers)")
                    StatItem(label: "Following", value: "\(following)")
                }
            }

            Button {
                onAction()
            } label: {
                Text("Follow")
                    .font(WernickeTypography.body14Medium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ParietalSpacing.sm + 2)
                    .background(V4Color.accent)
                    .cornerRadius(V1Theme.cornerBase)
            }
            .buttonStyle(.plain)
        }
        .padding(ParietalSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(V4Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(V4Color.border, lineWidth: 1)
        )
    }

    private struct StatItem: View {
        let label: String
        let value: String

        var body: some View {
            VStack(spacing: 2) {
                Text(value)
                    .font(WernickeTypography.body14Semibold)
                    .foregroundStyle(V4Color.textPrimary)

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)
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
                            .fill(V4Color.accent)
                    )
                    .offset(x: size.dimension / 8, y: size.dimension / 8)
            }
        }
        .buttonStyle(.plain)
    }

    private var placeholder: some View {
        ZStack {
            Circle()
                .fill(V4Color.border)
                .frame(width: size.dimension, height: size.dimension)

            Image(systemName: "person.fill")
                .font(.system(size: size.dimension * 0.4))
                .foregroundStyle(V4Color.textSecondary)
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
        HStack(spacing: ParietalSpacing.sm - 2) {
            Text("@")
                .font(WernickeTypography.size11)
                .foregroundStyle(V4Color.accent)

            Text(mention)
                .font(WernickeTypography.size13)
                .foregroundStyle(V4Color.textPrimary)

            Spacer()
        }
        .padding(.horizontal, ParietalSpacing.sm + 2)
        .padding(.vertical, ParietalSpacing.xs + 2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(V4Color.accent.opacity(V2Depth.bgSubtle))
        )
    }
}

// MARK: - User Status Indicator

struct UserStatusIndicator: View {
    let status: Avatar.UserStatus
    let showLabel: Bool

    var body: some View {
        HStack(spacing: ParietalSpacing.sm - 2) {
            Circle()
                .fill(status.color)
                .frame(width: ParietalSpacing.xs, height: ParietalSpacing.xs)

            if showLabel {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
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
            VStack(spacing: ParietalSpacing.lg) {
                HStack(spacing: ParietalSpacing.md) {
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
        .background(V4Color.background)
    }
}
