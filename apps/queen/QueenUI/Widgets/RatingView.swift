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
        HStack(spacing: 4) {
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
            .font(.system(size: 14))
            .foregroundStyle(.yellow)
    }

    private var emptyStar: some View {
        Image(systemName: "star")
            .font(.system(size: 14))
            .foregroundStyle(interactive ? TrinityTheme.textMuted : .yellow.opacity(0.3))
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
        HStack(spacing: 6) {
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
            .foregroundStyle(isActive ? .yellow : TrinityTheme.textMuted)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                // Avatar
                if let avatar = avatar {
                    Image(systemName: avatar)
                        .font(.system(size: 20))
                        .foregroundStyle(TrinityTheme.accent)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(TrinityTheme.accent.opacity(0.15))
                        )
                } else {
                    Circle()
                        .fill(TrinityTheme.bgCardBorder)
                        .frame(width: 36, height: 36)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(reviewer)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TrinityTheme.textPrimary)

                    HStack(spacing: 6) {
                        StaticStarRating(rating: rating, size: .small)

                        Text(dateString)
                            .font(.caption2)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                }

                Spacer()
            }

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(TrinityTheme.textPrimary)

            Text(comment)
                .font(.system(size: 12))
                .foregroundStyle(TrinityTheme.textMuted)
                .lineLimit(4)

            HStack(spacing: 4) {
                Image(systemName: "hand.thumbsup")
                    .font(.system(size: 11))
                Text("\(helpfulCount) helpful")
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.textMuted)
            }
        }
        .padding(14)
        .background(TrinityTheme.bgCard)
        .cornerRadius(TrinityTheme.cornerMedium)
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
        HStack(spacing: 20) {
            // Average rating
            VStack(spacing: 4) {
                Text(String(format: "%.1f", averageRating))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(TrinityTheme.textPrimary)

                StaticStarRating(rating: Int(round(averageRating)), size: .medium)

                Text("\(totalReviews) reviews")
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
            }
            .frame(width: 100)

            // Distribution bars
            VStack(spacing: 4) {
                ForEach((1...5).reversed(), id: \.self) { star in
                    HStack(spacing: 8) {
                        Text("\(star)")
                            .font(.system(size: 11))
                            .foregroundStyle(TrinityTheme.textMuted)
                            .frame(width: 12)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(TrinityTheme.bgCardBorder)

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
                            .foregroundStyle(TrinityTheme.textMuted)
                            .frame(width: 30)
                    }
                }
            }
        }
        .padding(16)
        .background(TrinityTheme.bgCard)
        .cornerRadius(TrinityTheme.cornerMedium)
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
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TrinityTheme.textPrimary)

                InteractiveRating(rating: $rating, size: .large)

                Text(ratingText)
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
            }

            if !categories.isEmpty {
                Divider()

                VStack(spacing: 12) {
                    ForEach(categories) { category in
                        HStack {
                            Text(category.name)
                                .font(.system(size: 12))
                                .foregroundStyle(TrinityTheme.textPrimary)

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
        .padding(16)
        .background(TrinityTheme.bgCard)
        .cornerRadius(TrinityTheme.cornerMedium)
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
            VStack(spacing: 16) {
                StarRating(rating: .constant(3.5))
                StarRating(rating: .constant(4.8))

                InteractiveRating(rating: .constant(4))

                RatingSummary(
                    averageRating: 4.3,
                    totalReviews: 128,
                    ratingDistribution: [8, 12, 24, 45, 39]
                )
                .frame(width: 300)

                ReviewCard(
                    reviewer: "John Doe",
                    avatar: "person.fill",
                    rating: 5,
                    title: "Excellent product!",
                    comment: "Really happy with this purchase. Would definitely recommend to others.",
                    date: Date().addingTimeInterval(-86400 * 3),
                    helpfulCount: 24
                )
                .frame(width: 300)
            }
            .padding()
        }
        .padding()
        .background(TrinityTheme.bgWindow)
    }
}
