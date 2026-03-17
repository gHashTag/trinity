// Stepper View — Numeric Input Controls
import SwiftUI

// MARK: - Stepper

struct CustomStepper: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let label: String?
    let format: Format

    enum Format {
        case integer
        case decimal(Int)
        case percent
        case currency

        func format(_ value: Double) -> String {
            switch self {
            case .integer:
                return String(format: "%.0f", value)
            case .decimal(let places):
                return String(format: "%.\(places)f", value)
            case .percent:
                return String(format: "%.0f%%", value * 100)
            case .currency:
                return String(format: "$%.2f", value)
            }
        }
    }

    init(
        value: Binding<Double>,
        in range: ClosedRange<Double> = 0...100,
        step: Double = 1,
        label: String? = nil,
        format: Format = .integer
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.label = label
        self.format = format
    }

    var body: some View {
        HStack(spacing: 8) {
            if let label = label {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(TrinityTheme.textPrimary)
            }

            // Decrement button
            StepperButton(direction: .decrement) {
                updateValue(-step)
            }

            // Value display
            Text(format.format(value))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(TrinityTheme.textPrimary)
                .frame(minWidth: 50)

            // Increment button
            StepperButton(direction: .increment) {
                updateValue(step)
            }
        }
    }

    private func updateValue(_ delta: Double) {
        let newValue = value + delta
        value = min(max(newValue, range.lowerBound), range.upperBound)
    }
}

// MARK: - Stepper Button

struct StepperButton: View {
    enum Direction { case increment, decrement }

    let direction: Direction
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: direction == .increment ? "plus" : "minus")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isEnabled ? TrinityTheme.textPrimary : TrinityTheme.textMuted)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(TrinityTheme.bgCardBorder)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var isEnabled: Bool {
        // Would need parent context to determine this
        return true
    }
}

// MARK: - Range Slider

struct CustomRangeSlider: View {
    @Binding var lowerValue: Double
    @Binding var upperValue: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        GeometryReader { geometry in
            let trackHeight: CGFloat = 4
            let thumbSize: CGFloat = 16
            let minY = geometry.size.height / 2

            ZStack {
                // Track
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(TrinityTheme.bgCardBorder)
                    .frame(height: trackHeight)
                    .frame(maxWidth: .infinity)
                    .position(y: minY)

                // Selected range
                let lowerX = xPosition(for: lowerValue, in: geometry.size.width)
                let upperX = xPosition(for: upperValue, in: geometry.size.width)

                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(TrinityTheme.accent)
                    .frame(height: trackHeight)
                    .frame(width: upperX - lowerX)
                    .position(x: (lowerX + upperX) / 2, y: minY)

                // Lower thumb
                thumb(at: lowerX, y: minY, isDragging: false)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                lowerValue = valueForPosition(value.location.x, in: geometry.size.width)
                            }
                    )

                // Upper thumb
                thumb(at: upperX, y: minY, isDragging: false)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                upperValue = valueForPosition(value.location.x, in: geometry.size.width)
                            }
                    )
            }
        }
        .frame(height: 40)
    }

    private func thumb(at x: CGFloat, y: CGFloat, isDragging: Bool) -> some View {
        Circle()
            .fill(.white)
            .frame(width: 16, height: 16)
            .shadow(color: .black.opacity(0.2), radius: 2)
            .position(x: x, y: y)
    }

    private func xPosition(for value: Double, in width: CGFloat) -> CGFloat {
        let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return normalized * width
    }

    private func valueForPosition(_ x: CGFloat, in width: CGFloat) -> Double {
        let normalized = max(0, min(1, x / width))
        let value = range.lowerBound + normalized * (range.upperBound - range.lowerBound)
        return (value / step).rounded() * step
    }
}

// MARK: - Segmented Stepper

struct SegmentedStepper: View {
    @Binding var selectedIndex: Int
    let segments: [String]
    let allowsEmpty: Bool

    init(
        selectedIndex: Binding<Int>,
        segments: [String],
        allowsEmpty: Bool = false
    ) {
        self._selectedIndex = selectedIndex
        self.segments = segments
        self.allowsEmpty = allowsEmpty
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                Button {
                    withAnimation {
                        if selectedIndex == index && allowsEmpty {
                            selectedIndex = -1
                        } else {
                            selectedIndex = index
                        }
                    }
                } label: {
                    Text(segment)
                        .font(.system(size: 12, weight: selectedIndex == index ? .medium : .regular))
                        .foregroundStyle(selectedIndex == index ? TrinityTheme.textPrimary : TrinityTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            selectedIndex == index ?
                                TrinityTheme.bgCardBorder :
                                Color.clear
                        )
                }
                .buttonStyle(.plain)

                if index < segments.count - 1 {
                    Divider()
                        .frame(height: 16)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Counter Stepper

struct CounterStepper: View {
    @Binding var count: Int
    let minimumValue: Int
    let maximumValue: Int
    let label: String?

    var body: some View {
        HStack(spacing: 8) {
            if let label = label {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(TrinityTheme.textMuted)
            }

            HStack(spacing: 0) {
                counterButton("-") {
                    count = Swift.max(minimumValue, count - 1)
                }

                Text("\(count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TrinityTheme.textPrimary)
                    .frame(minWidth: 30)

                counterButton("+") {
                    count = Swift.min(maximumValue, count + 1)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
            )
        }
    }

    private func counterButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                action()
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(TrinityTheme.accent)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quantity Selector

struct QuantitySelector: View {
    @Binding var quantity: Int
    let available: Int?

    var body: some View {
        HStack(spacing: 12) {
            stepperButton(icon: "minus", enabled: quantity > 0) {
                withAnimation {
                    quantity = max(0, quantity - 1)
                }
            }

            Text("\(quantity)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(TrinityTheme.textPrimary)
                .frame(minWidth: 30)

            stepperButton(icon: "plus", enabled: available == nil || quantity < (available ?? 0)) {
                withAnimation {
                    if let available = available {
                        quantity = min(available, quantity + 1)
                    } else {
                        quantity += 1
                    }
                }
            }

            Spacer()

            if let available = available {
                Text("\(available) available")
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
            }
        }
    }

    private func stepperButton(icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(enabled ? TrinityTheme.textPrimary : TrinityTheme.textMuted)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(enabled ? TrinityTheme.bgCardBorder : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Preview

struct StepperView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: 16) {
                CustomStepper(
                    value: .constant(5),
                    in: 0...10,
                    label: "Quantity"
                )

                CustomStepper(
                    value: .constant(3.5),
                    in: 0...10,
                    step: 0.5,
                    format: .decimal(1)
                )

                CounterStepper(
                    count: .constant(1),
                    minimumValue: 0,
                    maximumValue: 10,
                    label: "Items"
                )

                QuantitySelector(
                    quantity: .constant(2),
                    available: 5
                )

                SegmentedStepper(
                    selectedIndex: .constant(1),
                    segments: ["Small", "Medium", "Large"]
                )
            }
            .padding()
            .background(TrinityTheme.bgCard)
        }
        .padding()
        .background(TrinityTheme.bgWindow)
    }
}
