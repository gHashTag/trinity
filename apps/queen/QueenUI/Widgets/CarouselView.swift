// Carousel View — Image/Content Sliders
import SwiftUI

// MARK: - Carousel

struct CarouselView<Content: View>: View {
    let content: Content
    @State private var currentIndex = 0
    let itemCount: Int
    let autoScroll: Bool
    let autoScrollInterval: TimeInterval
    let showIndicators: Bool
    let showsPagination: Bool

    init(
        itemCount: Int,
        autoScroll: Bool = false,
        autoScrollInterval: TimeInterval = 3.0,
        showIndicators: Bool = true,
        showsPagination: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.itemCount = itemCount
        self.autoScroll = autoScroll
        self.autoScrollInterval = autoScrollInterval
        self.showIndicators = showIndicators
        self.showsPagination = showsPagination
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentIndex) {
                content
                    .tag(0)
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: showsPagination ? .always : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            #endif
            .onAppear {
                if autoScroll {
                    startAutoScroll()
                }
            }

            if showIndicators {
                indicators
            }
        }
    }

    private var indicators: some View {
        HStack(spacing: 6) {
            ForEach(0..<itemCount, id: \.self) { index in
                Circle()
                    .fill(currentIndex == index ? TrinityTheme.accent : TrinityTheme.textMuted.opacity(0.4))
                    .frame(width: currentIndex == index ? 7 : 5, height: currentIndex == index ? 7 : 5)
                    .animation(.spring(response: 0.3), value: currentIndex)
            }
        }
        .padding(.top, 8)
    }

    private func startAutoScroll() {
        Timer.scheduledTimer(withTimeInterval: autoScrollInterval, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentIndex = (currentIndex + 1) % itemCount
            }
        }
    }
}

// MARK: - Banner Carousel

struct BannerCarousel: View {
    let banners: [BannerItem]
    @State private var currentIndex = 0

    struct BannerItem: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String?
        let backgroundColor: Color
        let action: (() -> Void)?
    }

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(banners.enumerated()), id: \.element.id) { index, banner in
                bannerView(for: banner)
                    .tag(index)
            }
        }
        #if os(iOS)
        .tabViewStyle(.page(indexDisplayMode: .never))
        #endif
        .frame(height: 160)
    }

    private func bannerView(for banner: BannerItem) -> some View {
        ZStack {
            banner.backgroundColor

            VStack(alignment: .leading, spacing: 6) {
                Text(banner.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                if let subtitle = banner.subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .cornerRadius(12)
        .padding(.horizontal, 4)
        .onTapGesture {
            banners[currentIndex].action?()
        }
    }
}

// MARK: - Card Carousel

struct CardCarousel<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let spacing: CGFloat
    let cardWidth: CGFloat
    let content: (Item) -> Content

    @State private var offset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0

    init(
        items: [Item],
        spacing: CGFloat = 12,
        cardWidth: CGFloat = 280,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.spacing = spacing
        self.cardWidth = cardWidth
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = CGFloat(items.count) * (cardWidth + spacing) - spacing
            let maxOffset = max(0, totalWidth - geometry.size.width)

            HStack(spacing: spacing) {
                ForEach(items) { item in
                    content(item)
                        .frame(width: cardWidth)
                }
            }
            .offset(x: -offset)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            offset = max(0, min(maxOffset, offset - value.translation.width))
                        }
                    }
            )
        }
        .clipped()
    }
}

// MARK: - Snapping Carousel

struct SnappingCarousel<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let itemWidth: CGFloat
    let spacing: CGFloat
    let content: (Item) -> Content

    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let itemSize = itemWidth + spacing

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(items) { item in
                        content(item)
                            .frame(width: itemWidth)
                    }
                }
                .offset(x: scrollOffset)
            }
            .onChange(of: scrollOffset) { _, newValue in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    let index = round(-newValue / itemSize)
                    scrollOffset = -index * itemSize
                }
            }
        }
    }
}

// MARK: - Gallery View

struct GalleryView: View {
    let images: [GalleryImage]
    @State private var selectedIndex = 0
    @State private var showFullscreen = false

    struct GalleryImage: Identifiable {
        let id = UUID()
        let image: Image
        let caption: String?
    }

    var body: some View {
        VStack(spacing: 12) {
            // Main image
            ZStack {
                images[selectedIndex].image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(12)
                    .onTapGesture(count: 2) {
                        showFullscreen = true
                    }

                // Navigation arrows
                if selectedIndex > 0 {
                    Button {
                        withAnimation {
                            selectedIndex -= 1
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 12)
                }

                if selectedIndex < images.count - 1 {
                    Button {
                        withAnimation {
                            selectedIndex += 1
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 12)
                }
            }
            .frame(height: 300)

            // Thumbnail strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                        image.image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(selectedIndex == index ? TrinityTheme.accent : Color.clear, lineWidth: 2)
                            )
                            .onTapGesture {
                                withAnimation {
                                    selectedIndex = index
                                }
                            }
                    }
                }
                .padding(.horizontal, 4)
            }

            // Caption
            if let caption = images[selectedIndex].caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showFullscreen) {
            images[selectedIndex].image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
                .onTapGesture {
                    showFullscreen = false
                }
        }
        #else
        .sheet(isPresented: $showFullscreen) {
            images[selectedIndex].image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 600, height: 600)
                .background(.black)
                .onTapGesture {
                    showFullscreen = false
                }
        }
        #endif
    }
}

// MARK: - Page Control

struct CustomPageControl: View {
    let numberOfPages: Int
    @Binding var currentPage: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<numberOfPages, id: \.self) { page in
                RoundedRectangle(cornerRadius: 2)
                    .fill(currentPage == page ? TrinityTheme.accent : TrinityTheme.textMuted.opacity(0.4))
                    .frame(width: currentPage == page ? 20 : 6, height: 6)
                    .animation(.spring(response: 0.3), value: currentPage)
                    .onTapGesture {
                        withAnimation {
                            currentPage = page
                        }
                    }
            }
        }
        .frame(height: 20)
    }
}

// MARK: - Preview

struct CarouselView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BannerCarousel(
                banners: [
                    BannerCarousel.BannerItem(title: "Welcome", subtitle: "Get started now", backgroundColor: .blue, action: nil),
                    BannerCarousel.BannerItem(title: "New Features", subtitle: "Check out what's new", backgroundColor: .purple, action: nil),
                    BannerCarousel.BannerItem(title: "Pro Tips", subtitle: "Learn advanced tricks", backgroundColor: .orange, action: nil)
                ]
            )
            .frame(height: 180)
            .padding()

            CustomPageControl(numberOfPages: 5, currentPage: .constant(2))
                .padding()
        }
        .padding()
        .background(TrinityTheme.bgWindow)
    }
}
