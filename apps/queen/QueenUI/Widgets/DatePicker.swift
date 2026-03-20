// Date Picker — Custom Date Range Picker with Presets
import SwiftUI

// MARK: - Date Range Picker

struct DateRangePicker: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let presets: [Preset]
    let onClear: () -> Void

    struct Preset: Identifiable {
        let id = UUID()
        let title: String
        let range: RangeDuration
    }

    enum RangeDuration {
        case today
        case yesterday
        case last7Days
        case last30Days
        case last90Days
        case thisWeek
        case thisMonth
        case thisYear
        case custom(Date, Date)

        var dateRange: (start: Date, end: Date) {
            let calendar = Calendar.current
            let now = Date()

            switch self {
            case .today:
                return (calendar.startOfDay(for: now), now)
            case .yesterday:
                let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
                return (calendar.startOfDay(for: yesterday), yesterday)
            case .last7Days:
                let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
                return (calendar.startOfDay(for: sevenDaysAgo), now)
            case .last30Days:
                let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!
                return (calendar.startOfDay(for: thirtyDaysAgo), now)
            case .last90Days:
                let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: now)!
                return (calendar.startOfDay(for: ninetyDaysAgo), now)
            case .thisWeek:
                let week = calendar.dateInterval(of: .weekOfYear, for: now)!
                return (week.start, week.end)
            case .thisMonth:
                let month = calendar.dateInterval(of: .month, for: now)!
                return (month.start, month.end)
            case .thisYear:
                let year = calendar.dateInterval(of: .year, for: now)!
                return (year.start, year.end)
            case .custom(let start, let end):
                return (start, end)
            }
        }
    }

    init(
        startDate: Binding<Date>,
        endDate: Binding<Date>,
        presets: [Preset] = defaultPresets,
        onClear: @escaping () -> Void = {}
    ) {
        self._startDate = startDate
        self._endDate = endDate
        self.presets = presets
        self.onClear = onClear
    }

    static var defaultPresets: [Preset] {
        [
            Preset(title: "Today", range: .today),
            Preset(title: "Yesterday", range: .yesterday),
            Preset(title: "Last 7 Days", range: .last7Days),
            Preset(title: "Last 30 Days", range: .last30Days),
            Preset(title: "This Month", range: .thisMonth),
            Preset(title: "This Year", range: .thisYear)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            // Presets
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ParietalSpacing.sm) {
                    ForEach(presets) { preset in
                        PresetChip(
                            title: preset.title,
                            isSelected: isSelected(preset.range)
                        ) {
                            applyPreset(preset.range)
                        }
                    }
                }
            }

            // Custom range
            HStack(spacing: ParietalSpacing.md) {
                VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                    Text("Start")
                        .font(.caption)
                        .foregroundStyle(V4Color.textSecondary)

                    DatePickerButton(date: $startDate)
                }

                Image(systemName: "arrow.right")
                    .font(WernickeTypography.size12)
                    .foregroundStyle(V4Color.textSecondary)

                VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                    Text("End")
                        .font(.caption)
                        .foregroundStyle(V4Color.textSecondary)

                    DatePickerButton(date: $endDate)
                }

                Spacer()

                Button {
                    onClear()
                } label: {
                    Text("Clear")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(ParietalSpacing.md)
        .background(V4Color.surface)
        .cornerRadius(V1Theme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(V4Color.border, lineWidth: 1)
        )
    }

    private func isSelected(_ range: RangeDuration) -> Bool {
        let selectedRange = RangeDuration.custom(startDate, endDate)
        return abs(selectedRange.dateRange.start.timeIntervalSince(range.dateRange.start)) < 1 &&
               abs(selectedRange.dateRange.end.timeIntervalSince(range.dateRange.end)) < 1
    }

    private func applyPreset(_ range: RangeDuration) {
        let dateRange = range.dateRange
        startDate = dateRange.start
        endDate = dateRange.end
    }
}

// MARK: - Preset Chip

struct PresetChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            Text(title)
                .font(isSelected ? WernickeTypography.captionMedium : WernickeTypography.caption)
                .foregroundStyle(isSelected ? .white : V4Color.textPrimary)
                .padding(.horizontal, ParietalSpacing.md)
                .padding(.vertical, ParietalSpacing.xs + 2)
                .background(isSelected ? V4Color.accent : V4Color.border)
                .cornerRadius(V1Theme.cornerXLarge)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Date Picker Button

struct DatePickerButton: View {
    @Binding var date: Date
    @State private var showPicker = false

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: ParietalSpacing.sm - 2) {
                Text(dateString)
                    .font(WernickeTypography.size13)
                    .foregroundStyle(V4Color.textPrimary)

                Image(systemName: "calendar")
                    .font(WernickeTypography.size12)
                    .foregroundStyle(V4Color.textSecondary)
            }
            .padding(.horizontal, ParietalSpacing.sm + 2)
            .padding(.vertical, ParietalSpacing.xs + 2)
            .background(V4Color.background.opacity(V2Depth.stateDisabled))
            .cornerRadius(V1Theme.cornerSmall)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPicker) {
            DatePickerSheet(date: $date, isPresented: $showPicker)
        }
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    @Binding var date: Date
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
                DatePicker(
                    "Select Date",
                    selection: $date,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
            }
            .navigationTitle("Select Date")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .frame(width: 400, height: 450)
    }
}

// MARK: - Relative Date Picker

struct RelativeDatePicker: View {
    @Binding var date: Date
    let label: String

    var body: some View {
        HStack(spacing: ParietalSpacing.sm) {
            Text(label)
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)

            Menu {
                Button("Today") {
                    date = Date()
                }
                Button("Tomorrow") {
                    date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                }
                Button("Next Week") {
                    date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                }
                Button("Next Month") {
                    date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
                }
                Divider()
                Button("Yesterday") {
                    date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                }
                Button("Last Week") {
                    date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                }
                Button("Last Month") {
                    date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
                }
                Divider()
                Button("Custom Date...") {
                    // Show date picker
                }
            } label: {
                HStack(spacing: ParietalSpacing.xs) {
                    Text(relativeDescription)
                        .font(WernickeTypography.size13)
                    Image(systemName: "chevron.down")
                        .font(WernickeTypography.size10)
                }
            }
        }
    }

    private var relativeDescription: String {
        let calendar = Calendar.current
        let now = Date()
        let days = calendar.dateComponents([.day], from: now, to: date).day ?? 0

        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        if days == -1 { return "Yesterday" }
        if days > 1 && days <= 7 { return "In \(days) days" }
        if days < -1 && days >= -7 { return "\(abs(days)) days ago" }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Preview

struct DatePicker_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DateRangePicker(
                startDate: .constant(Date()),
                endDate: .constant(Date().addingTimeInterval(7 * 24 * 3600))
            )
            .frame(width: ParietalSpacing.xl * 16)
            .padding()
            .background(V4Color.background)

            RelativeDatePicker(
                date: .constant(Date().addingTimeInterval(3 * 24 * 3600)),
                label: "Due Date"
            )
            .frame(width: ParietalSpacing.xl * 10)
            .padding()
            .background(V4Color.background)
        }
    }
}
