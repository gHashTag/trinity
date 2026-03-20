import SwiftUI

struct TriangleLogo: View {
    @Binding var selectedScreen: Screen?
    @State private var hoveredBlock: Int? = nil
    @State private var ralphPulseTime: Double = 0

    // SVG viewBox constants from photon_trinity_canvas.zig
    static let svgWidth: CGFloat = 596
    static let svgHeight: CGFloat = 526
    static let svgCenterX: CGFloat = 298
    static let svgCenterY: CGFloat = 263

    // 27 blocks x 4 vertices — exact coordinates from photon_trinity_canvas.zig:2387-2442
    static let rawBlocks: [[CGPoint]] = [
        // Block 0 (RAZUM)
        [CGPoint(x: 296.767, y: 435.228), CGPoint(x: 236.563, y: 329.491), CGPoint(x: 211.501, y: 373.56), CGPoint(x: 296.767, y: 523.496)],
        // Block 1
        [CGPoint(x: 235.71, y: 328.065), CGPoint(x: 177.201, y: 224.57), CGPoint(x: 126.893, y: 224.57), CGPoint(x: 210.755, y: 372.182)],
        // Block 2
        [CGPoint(x: 116.304, y: 118.557), CGPoint(x: 175.824, y: 223.238), CGPoint(x: 126.022, y: 223.26), CGPoint(x: 42.177, y: 74.909)],
        // Block 3
        [CGPoint(x: 43.019, y: 73.555), CGPoint(x: 117.106, y: 116.68), CGPoint(x: 235.544, y: 116.68), CGPoint(x: 211.46, y: 73.525)],
        // Block 4
        [CGPoint(x: 213.1, y: 73.52), CGPoint(x: 237.875, y: 116.409), CGPoint(x: 356.58, y: 116.741), CGPoint(x: 381.646, y: 73.509)],
        // Block 5
        [CGPoint(x: 477.724, y: 116.854), CGPoint(x: 358.701, y: 116.802), CGPoint(x: 383.404, y: 73.803), CGPoint(x: 550.969, y: 73.877)],
        // Block 6
        [CGPoint(x: 477.056, y: 118.915), CGPoint(x: 418.023, y: 223.109), CGPoint(x: 468.886, y: 223.131), CGPoint(x: 553.143, y: 74.338)],
        // Block 7
        [CGPoint(x: 358.646, y: 327.197), CGPoint(x: 384.221, y: 372.152), CGPoint(x: 468.192, y: 224.521), CGPoint(x: 416.976, y: 224.579)],
        // Block 8
        [CGPoint(x: 298.138, y: 434.656), CGPoint(x: 357.793, y: 328.533), CGPoint(x: 383.376, y: 373.808), CGPoint(x: 298.138, y: 523.876)],
        // Block 9 (MATERIYA)
        [CGPoint(x: 297.148, y: 352.965), CGPoint(x: 260.326, y: 288.171), CGPoint(x: 237.943, y: 327.796), CGPoint(x: 297.148, y: 432.004)],
        // Block 10
        [CGPoint(x: 259.613, y: 286.78), CGPoint(x: 224.371, y: 224.818), CGPoint(x: 179.6, y: 224.818), CGPoint(x: 237.048, y: 326.301)],
        // Block 11
        [CGPoint(x: 223.536, y: 223.354), CGPoint(x: 187.285, y: 159.675), CGPoint(x: 120.085, y: 120.508), CGPoint(x: 178.781, y: 223.779)],
        // Block 12
        [CGPoint(x: 121.863, y: 119.193), CGPoint(x: 187.937, y: 158.358), CGPoint(x: 260.042, y: 158.355), CGPoint(x: 237.348, y: 118.746)],
        // Block 13
        [CGPoint(x: 261.857, y: 158.313), CGPoint(x: 333.559, y: 158.29), CGPoint(x: 356.01, y: 118.829), CGPoint(x: 239.269, y: 118.829)],
        // Block 14
        [CGPoint(x: 335.294, y: 158.3), CGPoint(x: 407.736, y: 158.226), CGPoint(x: 474.496, y: 118.923), CGPoint(x: 357.761, y: 118.923)],
        // Block 15
        [CGPoint(x: 408.358, y: 159.547), CGPoint(x: 372.034, y: 223.421), CGPoint(x: 416.476, y: 223.315), CGPoint(x: 475.012, y: 120.916)],
        // Block 16
        [CGPoint(x: 336.052, y: 286.778), CGPoint(x: 358.165, y: 325.872), CGPoint(x: 415.649, y: 224.808), CGPoint(x: 371.244, y: 224.759)],
        // Block 17
        [CGPoint(x: 298.893, y: 352.826), CGPoint(x: 335.156, y: 288.19), CGPoint(x: 357.382, y: 327.328), CGPoint(x: 298.893, y: 430.179)],
        // Block 18 (DUKH)
        [CGPoint(x: 296.258, y: 272.716), CGPoint(x: 282.337, y: 248.309), CGPoint(x: 260.496, y: 286.972), CGPoint(x: 296.258, y: 349.653)],
        // Block 19
        [CGPoint(x: 259.547, y: 285.675), CGPoint(x: 281.633, y: 246.705), CGPoint(x: 269.336, y: 225.016), CGPoint(x: 225.274, y: 224.996)],
        // Block 20
        [CGPoint(x: 254.956, y: 199.798), CGPoint(x: 268.406, y: 223.578), CGPoint(x: 224.465, y: 223.598), CGPoint(x: 189.037, y: 161.206)],
        // Block 21
        [CGPoint(x: 255.476, y: 198.549), CGPoint(x: 282.068, y: 198.538), CGPoint(x: 260.192, y: 160.039), CGPoint(x: 189.751, y: 160.07)],
        // Block 22
        [CGPoint(x: 261.646, y: 160.062), CGPoint(x: 283.582, y: 198.505), CGPoint(x: 309.702, y: 198.505), CGPoint(x: 331.733, y: 160.062)],
        // Block 23
        [CGPoint(x: 338.542, y: 198.607), CGPoint(x: 311.435, y: 198.595), CGPoint(x: 333.423, y: 160.068), CGPoint(x: 404.244, y: 160.099)],
        // Block 24
        [CGPoint(x: 338.85, y: 199.978), CGPoint(x: 325.556, y: 223.591), CGPoint(x: 369.518, y: 223.61), CGPoint(x: 404.907, y: 161.243)],
        // Block 25
        [CGPoint(x: 334.38, y: 285.625), CGPoint(x: 312.392, y: 246.733), CGPoint(x: 324.681, y: 224.989), CGPoint(x: 368.779, y: 224.969)],
        // Block 26
        [CGPoint(x: 298.025, y: 272.637), CGPoint(x: 311.561, y: 248.279), CGPoint(x: 333.297, y: 287.01), CGPoint(x: 298.025, y: 349.402)],
    ]

    // 27 world names + formulas from sacred_worlds.zig:99-141
    static let worlds: [(name: String, formula: String)] = [
        // RAZUM (0-8)
        ("CHAT", "phi = 1.618"),
        ("CODE", "pi*phi*e = 13.82"),
        ("EXPLAIN", "L(10) = 123"),
        ("DEBUG", "1/a = 137.036"),
        ("REVIEW", "phi2 = phi+1 = 2.618"),
        ("TRANSLATE", "Feigenbaum d = 4.669"),
        ("VIBEE", "F(7) = 13"),
        ("VOICE", "sqrt(5) = 2.236"),
        ("COMPOSE", "999 = 37 x 27"),
        // MATERIYA (9-17)
        ("FILES", "pi = 3.14159"),
        ("EDITOR", "27 = 3^3"),
        ("BUILD", "CHSH = 2*sqrt(2) = 2.83"),
        ("TEST", "m_p/m_e = 1836"),
        ("TERMINAL", "pi2 = 9.87"),
        ("GIT", "e^pi = 23.14"),
        ("DEPLOY", "E8 dim = 248"),
        ("DePIN NODE", "phi2+1/phi2 = 3 = $TRI"),
        ("SETTINGS", "76 photons"),
        // DUKH (18-26)
        ("DOCS", "phi2+1/phi2 = 3 = TRINITY"),
        ("REELS", "tau = 2*pi = 6.283"),
        ("FEED", "Menger D = ln20/ln3"),
        ("ROADMAP", "mu = 0.0382"),
        ("BENCHMARKS", "chi = 0.0618"),
        ("RESEARCH", "sigma = phi = 1.618"),
        ("FORMULAS", "e = 2.71828"),
        ("COMMUNITY", "Universe = 13.82 Gyr"),
        ("ABOUT", "H0 = 70.74 km/s/Mpc"),
    ]

    // Realm colors from sacred_worlds.zig
    static let realmColors: [Color] = [
        Color(red: 1.0, green: 215.0/255.0, blue: 0),       // Gold (RAZUM)
        Color(red: 80.0/255.0, green: 250.0/255.0, blue: 250.0/255.0), // Cyan (MATERIYA)
        Color(red: 189.0/255.0, green: 147.0/255.0, blue: 249.0/255.0), // Purple (DUKH)
    ]

    // Realm labels
    static let realmLabels: [(name: String, symbol: String)] = [
        ("RAZUM", "phi"),
        ("MATERIYA", "pi"),
        ("DUKH", "e"),
    ]

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / Self.svgWidth, geo.size.height / Self.svgHeight) * 0.63
            let offsetX = geo.size.width / 2
            let offsetY = geo.size.height / 2

            makeTimelineView(scale: scale, offsetX: offsetX, offsetY: offsetY)
        }
    }

    private func makeTimelineView(scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> some View {
        LogoTimelineView { time in
            makeContentView(time: time, scale: scale, offsetX: offsetX, offsetY: offsetY)
        }
    }

    private func makeContentView(time: TimeInterval, scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> some View {
        ZStack {
            makePetalCanvas(time: time, scale: scale, offsetX: offsetX, offsetY: offsetY)
            makeRealmLabels(scale: scale, offsetX: offsetX, offsetY: offsetY)
            makeTooltipView(scale: scale, offsetX: offsetX, offsetY: offsetY)
        }
    }

    private func makePetalCanvas(time: TimeInterval, scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> some View {
        Canvas { context, _ in
            for (idx, block) in Self.rawBlocks.enumerated() {
                let path = petalPath(block, scale: scale, ox: offsetX, oy: offsetY)
                let realm = idx / 9
                let isHovered = hoveredBlock == idx
                let isSelected = selectedScreen == Screen.screenForBlock(idx)

                // Fill: black (normal), white (hover), realm color (selected)
                let fillColor: Color = {
                    if isSelected {
                        return Self.realmColors[realm]
                    } else if isHovered {
                        return .white
                    } else if idx == 2 {
                        // Ralph pulse: cyan with oscillating alpha sin(t*3)*40+80 → 40-120/255
                        let alpha = sin(time * 3.0) * (40.0 / 255.0) + (80.0 / 255.0)
                        return Color(red: 0, green: 0xCC / 255.0, blue: 1.0).opacity(alpha)
                    } else {
                        return .black
                    }
                }()

                context.fill(path, with: .color(fillColor))
                // Outline: always white, always 1.0px
                context.stroke(path, with: .color(.white), lineWidth: 1.0)
            }
        }
        .onTapGesture { location in
            if let idx = hitTest(location, scale: scale, ox: offsetX, oy: offsetY) {
                selectedScreen = Screen.screenForBlock(idx)
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(let loc):
                hoveredBlock = hitTest(loc, scale: scale, ox: offsetX, oy: offsetY)
            case .ended:
                hoveredBlock = nil
            @unknown default:
                hoveredBlock = nil
            }
        }
    }

    private func makeRealmLabels(scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> some View {
        ZStack {
            realmLabel("RAZUM (phi)", color: Self.realmColors[0],
                       x: offsetX + (100 - Self.svgCenterX) * scale,
                       y: offsetY + (60 - Self.svgCenterY) * scale)
            realmLabel("MATERIYA (pi)", color: Self.realmColors[1],
                       x: offsetX + (490 - Self.svgCenterX) * scale,
                       y: offsetY + (60 - Self.svgCenterY) * scale)
            realmLabel("DUKH (e)", color: Self.realmColors[2],
                       x: offsetX,
                       y: offsetY + (520 - Self.svgCenterY) * scale)
        }
    }

    @ViewBuilder
    private func makeTooltipView(scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> some View {
        if let hov = hoveredBlock, hov >= 0, hov < Self.worlds.count {
            let world = Self.worlds[hov]
            let screen = Screen.screenForBlock(hov)
            Text("\(screen.icon) \(world.name) — \(world.formula)")
                .font(WernickeTypography.smallSemiboldMono)
                .foregroundStyle(.black)
                .padding(.horizontal, ParietalSpacing.sm)
                .padding(.vertical, ParietalSpacing.xs)
                .background(Color.white.opacity(0.94))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .position(tooltipPosition(hov, scale: scale, ox: offsetX, oy: offsetY))
                .allowsHitTesting(false)
        }
    }

    // MARK: - Geometry helpers

    private func petalPath(_ block: [CGPoint], scale: CGFloat, ox: CGFloat, oy: CGFloat) -> Path {
        Path { path in
            for (i, pt) in block.enumerated() {
                let x = ox + (pt.x - Self.svgCenterX) * scale
                let y = oy + (pt.y - Self.svgCenterY) * scale
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.closeSubpath()
        }
    }

    /// Ray-casting point-in-polygon — same algorithm as photon_trinity_canvas.zig:2552
    private func hitTest(_ location: CGPoint, scale: CGFloat, ox: CGFloat, oy: CGFloat) -> Int? {
        for (idx, block) in Self.rawBlocks.enumerated() {
            let transformed = block.map { pt in
                CGPoint(x: ox + (pt.x - Self.svgCenterX) * scale,
                        y: oy + (pt.y - Self.svgCenterY) * scale)
            }
            if pointInPoly(transformed, px: location.x, py: location.y) {
                return idx
            }
        }
        return nil
    }

    private func pointInPoly(_ verts: [CGPoint], px: CGFloat, py: CGFloat) -> Bool {
        var inside = false
        let count = verts.count
        var j = count - 1
        for i in 0..<count {
            let yi = verts[i].y
            let yj = verts[j].y
            let xi = verts[i].x
            let xj = verts[j].x
            if ((yi > py) != (yj > py)) &&
                (px < (xj - xi) * (py - yi) / (yj - yi) + xi) {
                inside = !inside
            }
            j = i
        }
        return inside
    }

    private func tooltipPosition(_ idx: Int, scale: CGFloat, ox: CGFloat, oy: CGFloat) -> CGPoint {
        let block = Self.rawBlocks[idx]
        let cx = block.reduce(0.0) { $0 + $1.x } / CGFloat(block.count)
        let cy = block.reduce(0.0) { $0 + $1.y } / CGFloat(block.count)
        return CGPoint(
            x: ox + (cx - Self.svgCenterX) * scale,
            y: oy + (cy - Self.svgCenterY) * scale - 30
        )
    }

    private func realmLabel(_ text: String, color: Color, x: CGFloat, y: CGFloat) -> some View {
        Text(text)
            .font(WernickeTypography.miniBoldMono)
            .foregroundStyle(color)
            .position(x: x, y: y)
            .allowsHitTesting(false)
    }
}

// MARK: - Logo Timeline View Helper

struct LogoTimelineView<Content: View>: View {
    let content: (TimeInterval) -> Content
    @State private var timer: Timer?
    @State private var startTime = Date()

    init(@ViewBuilder content: @escaping (TimeInterval) -> Content) {
        self.content = content
    }

    var body: some View {
        content(Date().timeIntervalSince(startTime))
            .onAppear {
                startTime = Date()
            }
    }
}

