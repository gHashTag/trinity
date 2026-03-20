// Rating View — Stars, Ratings, Reviews
import SwiftUI

// MARK: - Star Rating

struct StarRating: View {
    @Binding var rating: Double
    let maximumRating: Int
    let interactive: Bool

    init(
        rating: Binding<Double>,
        maximumRating: Int = 5,
        interactive: Bool = false
    ) {
        self._rating = rating
        self.maximumRating = maximumRating
        self.interactive = interactive
    }

    var body: some View {
        HStack(spacing: ParietalSpacing.xs) {
            ForEach(1...maximumRating, id: \.self) { index in
                starImage(for: index)
                    .onTapGesture {
                        if interactive {
                            withAnimation(.spring(response: 0.3)) {
                                rating = Double(index)
                            }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func starImage(for index: Int) -> some View {
        let fullStars = Int(rating)
        let partialStar = rating.truncatingRemainder(dividingBy: 1)

        if index <= fullStars {
            filledStar
        } else if index == fullStars + 1 && partialStar > 0 {
            partialStarView(fill: partialStar)
        } else {
            emptyStar
        }
    }

    private var filledStar: some View {
        Image(systemName: "star.fill")
            .font(WernickeTypography.size14)
            .foregroundStyle(.yellow)
    }

    private var emptyStar: some View {
        Image(systemName: "star")
            .font(WernickeTypography.size14)
            .foregroundStyle(interactive ? V4Color.textSecondary : .yellow.opacity(V2Depth.stateHover))
    }

    private func partialStarView(fill: Double) -> some View {
        ZStack {
            emptyStar
            filledStar
                .mask(
                    GeometryReader { geo in
                        Rectangle()
                            .fill(.black)
                            .frame(width: geo.size.width * CGFloat(fill))
                    }
                )
        }
    }
}

// MARK: - Interactive Rating

struct InteractiveRating: View {
    @Binding var rating: Int
    let maximumRating: Int
    let size: StarSize

    enum StarSize {
        case small, medium, large

        var pointSize: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 18
            case .large: return 24
            }
        }
    }

    @State private var hoverRating: Int?

    init(
        rating: Binding<Int>,
        maximumRating: Int = 5,
        size: StarSize = .medium
    ) {
        self._rating = rating
        self.maximumRating = maximumRating
        self.size = size
    }

    var body: some View {
        HStack(spacing: ParietalSpacing.sm - 2) {
            ForEach(1...maximumRating, id: \.self) { index in
                starView(for: index)
            }
        }
        .onExitCommand {
            hoverRating = nil
        }
    }

    @ViewBuilder
    private func starView(for index: Int) -> some View {
        let isActive = index <= (hoverRating ?? rating)

        Image(systemName: isActive ? "star.fill" : "star")
            .font(.system(size: size.pointSize))
            .foregroundStyle(isActive ? .yellow : V4Color.textSecondary)
            .onHover { hovering in
                if hovering {
                    hoverRating = index
                } else {
                    hoverRating = nil
                }
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    rating = index
                }
            }
    }
}

// MARK: - Review Card

struct ReviewCard: View {
    let reviewer: String
    let avatar: String?
    let rating: Int
    let title: String
    let comment: String
    let date: Date
    let helpfulCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm + 2) {
            HStack(spacing: ParietalSpacing.sm + 2) {
                // Avatar
                if let avatar = avatar {
                    Image(systemName: avatar)
                        .font(WernickeTypography.size20)
                        .foregroundStyle(V4Color.accent)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(V4Color.accent.opacity(V2Depth.bgSidebarHover))
                        )
                } else {
                    Circle()
                        .fill(V4Color.border)
                        .frame(width: 36, height: 36)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(reviewer)
                        .font(WernickeTypography.smallMedium)
                        .foregroundStyle(V4Color.textPrimary)

                    HStack(spacing: ParietalSpacing.sm - 2) {
                        StaticStarRating(rating: rating, size: .small)

                        Text(dateString)
                            .font(.caption2)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                }

                Spacer()
            }

            Text(title)
                .font(WernickeTypography.smallMedium)
                .foregroundStyle(V4Color.textPrimary)

            Text(comment)
                .font(WernickeTypography.size12)
                .foregroundStyle(V4Color.textSecondary)
                .lineLimit(4)

            HStack(spacing: ParietalSpacing.xs) {
                Image(systemName: "hand.thumbsup")
                    .font(WernickeTypography.size11)
                Text("\(helpfulCount) helpful")
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)
            }
        }
        .padding(14)
        .background(V4Color.surface)
        .cornerRadius(V1Theme.cornerMedium)
    }

    private var dateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Static Star Rating

struct StaticStarRating: View {
    let rating: Int
    let size: StarSize

    enum StarSize {
        case small, medium, large

        var pointSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 13
            case .large: return 16
            }
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1..<6) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.system(size: size.pointSize))
                    .foregroundStyle(.yellow)
            }
        }
    }
}

// MARK: - Rating Summary

struct RatingSummary: View {
    let averageRating: Double
    let totalReviews: Int
    let ratingDistribution: [Int]

    var body: some View {
        HStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
            // Average rating
            VStack(spacing: ParietalSpacing.xs) {
                Text(String(format: "%.1f", averageRating))
                    .font(WernickeTypography.size36Light.weight(.bold))
                    .foregroundStyle(V4Color.textPrimary)

                StaticStarRating(rating: Int(round(averageRating)), size: .medium)

                Text("\(totalReviews) reviews")
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
            }
            .frame(width: ParietalSpacing.avatarLarge + ParietalSpacing.lg)

            // Distribution bars
            VStack(spacing: ParietalSpacing.xs) {
                ForEach((1...5).reversed(), id: \.self) { star in
                    HStack(spacing: ParietalSpacing.sm) {
                        Text("\(star)")
                            .font(WernickeTypography.size11)
                            .foregroundStyle(V4Color.textSecondary)
                            .frame(width: 12)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(V4Color.border)

                                let count = ratingDistribution[safe: star - 1] ?? 0
                                let maxCount = ratingDistribution.max() ?? 1
                                let width = count > 0 ? CGFloat(count) / CGFloat(maxCount) * geometry.size.width : 0

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.yellow)
                                    .frame(width: width)
                            }
                        }
                        .frame(height: 6)

                        Text("\(ratingDistribution[safe: star - 1] ?? 0)")
                            .font(.caption2)
                            .foregroundStyle(V4Color.textSecondary)
                            .frame(width: 30)
                    }
                }
            }
        }
        .padding(ParietalSpacing.lg)
        .background(V4Color.surface)
        .cornerRadius(V1Theme.cornerMedium)
    }
}

// MARK: - Rating Input

struct RatingInput: View {
    @Binding var rating: Int
    let title: String
    let categories: [RatingCategory]

    struct RatingCategory: Identifiable {
        let id = UUID()
        let name: String
        @Binding var rating: Int

        init(name: String, rating: Binding<Int>) {
            self.name = name
            self._rating = rating
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.lg) {
            VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                Text(title)
                    .font(WernickeTypography.body14Medium)
                    .foregroundStyle(V4Color.textPrimary)

                InteractiveRating(rating: $rating, size: .large)

                Text(ratingText)
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
            }

            if !categories.isEmpty {
                Divider()

                VStack(spacing: ParietalSpacing.md) {
                    ForEach(categories) { category in
                        HStack {
                            Text(category.name)
                                .font(WernickeTypography.size12)
                                .foregroundStyle(V4Color.textPrimary)

                            Spacer()

                            InteractiveRating(
                                rating: category.$rating,
                                size: .small
                            )
                        }
                    }
                }
            }
        }
        .padding(ParietalSpacing.lg)
        .background(V4Color.surface)
        .cornerRadius(V1Theme.cornerMedium)
    }

    private var ratingText: String {
        switch rating {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Very Good"
        case 5: return "Excellent"
        default: return ""
        }
    }
}

// MARK: - Helper Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

struct RatingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: ParietalSpacing.lg) {
                StarRating(rating: .constant(3.5))
                StarRating(rating: .constant(4.8))

                InteractiveRating(rating: .constant(4))

                RatingSummary(
                    averageRating: 4.3,
                    totalReviews: 128,
                    ratingDistribution: [8, 12, 24, 45, 39]
                )
                .frame(width: ParietalSpacing.xl * 12)

                ReviewCard(
                    reviewer: "John Doe",
                    avatar: "person.fill",
                    rating: 5,
                    title: "Excellent product!",
                    comment: "Really happy with this purchase. Would definitely recommend to others.",
                    date: Date().addingTimeInterval(-86400 * 3),
                    helpfulCount: 24
                )
                .frame(width: ParietalSpacing.xl * 12)
            }
            .padding()
        }
        .padding()
        .background(V4Color.background)
    }
}
