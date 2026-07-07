import SwiftUI
import SwiftData
import Charts

struct HistoryView: View {
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @State private var chartMetric: ChartMetric = .minutes
    @State private var chartRange: ChartRange = .week

    private enum ChartMetric: String, CaseIterable, Identifiable {
        case minutes
        case reps
        var id: String { rawValue }
        var label: String {
            switch self {
            case .minutes: return Strings.History.minutes
            case .reps: return Strings.History.reps
            }
        }
    }

    private enum ChartRange: String, CaseIterable, Identifiable {
        case week = "7D"
        case twoWeeks = "14D"
        case month = "30D"
        var id: String { rawValue }
        var days: Int {
            switch self {
            case .week: return 7
            case .twoWeeks: return 14
            case .month: return 30
            }
        }
    }

    private var completedSessions: [WorkoutSession] {
        sessions.filter { $0.statusRaw == SessionStatus.completed.rawValue }
    }

    private var totalReps: Int {
        completedSessions.reduce(0) { $0 + $1.repCount }
    }

    private var totalMinutes: Double {
        completedSessions.reduce(0) { $0 + $1.earnedMinutes }
    }

    private var totalSessions: Int {
        completedSessions.count
    }

    /// Aggregated data for the chart: one `DailyEntry` per day in the selected
    /// range, including days with no activity (so the chart shows a consistent
    /// baseline rather than collapsing gaps).
    private struct DailyEntry: Identifiable {
        let date: Date
        let reps: Int
        let minutes: Double
        var id: Date { date }
    }

    private var dailyEntries: [DailyEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let range = chartRange.days

        // Build an empty slot for each day, oldest first.
        var buckets: [Date: (reps: Int, minutes: Double)] = [:]
        for offset in (0..<range).reversed() {
            if let d = calendar.date(byAdding: .day, value: -offset, to: today) {
                buckets[d] = (0, 0)
            }
        }

        // Bucket completed sessions into their day.
        for session in completedSessions {
            let day = calendar.startOfDay(for: session.startedAt)
            if buckets[day] != nil {
                buckets[day]!.reps += session.repCount
                buckets[day]!.minutes += session.earnedMinutes
            }
        }

        return buckets
            .map { DailyEntry(date: $0.key, reps: $0.value.reps, minutes: $0.value.minutes) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    headerSection
                    statsCard
                    if sessions.isEmpty {
                        emptyState
                    } else {
                        chartCard
                        recentWorkoutsSection
                    }
                }
                .padding(DS.Spacing.lg)
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Strings.History.headerTitle)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(DS.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(Strings.History.headerSubtitle)
                    .font(.subheadline)
                    .foregroundColor(DS.Colors.textSecondary)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.caption2)
                Text(TimeFormatter.formatMinutes(totalMinutes))
                    .font(.caption2).fontWeight(.bold)
                    .monospacedDigit()
            }
            .foregroundColor(DS.Colors.neon)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 6)
            .background(Capsule().fill(DS.Colors.neon.opacity(0.12)))
            .overlay(Capsule().stroke(DS.Colors.neon.opacity(0.4), lineWidth: 1))
            .padding(.top, 8)
        }
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            statColumn(icon: "flame.fill", value: "\(totalSessions)", label: Strings.History.sessions, color: DS.Colors.accent)
            statDivider
            statColumn(icon: "repeat", value: "\(totalReps)", label: Strings.History.reps, color: DS.Colors.neon)
            statDivider
            statColumn(icon: "clock.fill", value: TimeFormatter.formatMinutes(totalMinutes), label: Strings.History.minutes, color: DS.Colors.secondary)
        }
        .padding(DS.Spacing.md)
        .dsCard()
    }

    private func statColumn(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            DuoIconBadge(systemName: icon, color: color, size: 36)
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(DS.Colors.textPrimary)
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(DS.Colors.border)
            .frame(width: 1, height: 32)
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "clock")
                .font(.system(size: 56))
                .foregroundColor(DS.Colors.textSecondary)
            Text(Strings.History.noSessions)
                .foregroundColor(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xxl)
    }

    private var chartCard: some View {
        activityChart
            .padding(DS.Spacing.md)
            .dsCard()
    }

    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text(Strings.History.recentWorkouts)
                    .font(.headline)
                    .foregroundColor(DS.Colors.textPrimary)
                Spacer()
                Text(Strings.History.seeAll)
                    .font(.subheadline)
                    .foregroundColor(DS.Colors.neon)
            }
            ForEach(sessions) { session in
                sessionCell(session)
            }
        }
    }

    // MARK: - Chart

    private var activityChart: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Picker("Metric", selection: $chartMetric) {
                    ForEach(ChartMetric.allCases) { metric in
                        Text(metric.label).tag(metric)
                    }
                }
                .pickerStyle(.segmented)

                Spacer(minLength: DS.Spacing.sm)

                Picker("Range", selection: $chartRange) {
                    ForEach(ChartRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            // Rendered as separate branches so the chart is fully re-created
            // when the metric changes — avoids BarMark value caching issues.
            Group {
                if chartMetric == .minutes {
                    chartView(valueLabel: "Minutes") { Double($0.minutes) }
                } else {
                    chartView(valueLabel: "Reps") { Double($0.reps) }
                }
            }
            .frame(height: 180)
            .id(chartMetric.rawValue + chartRange.rawValue)

            if totalForCurrentMetric == 0 {
                Text(Strings.History.noActivity)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    @ViewBuilder
    private func chartView(
        valueLabel: String,
        value: @escaping (DailyEntry) -> Double
    ) -> some View {
        Chart(dailyEntries) { entry in
            BarMark(
                x: .value("Day", entry.date, unit: .day),
                y: .value(valueLabel, value(entry))
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [DS.Colors.neon, DS.Colors.secondary],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: strideForRange)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }

    private var strideForRange: Int {
        switch chartRange {
        case .week: return 1
        case .twoWeeks: return 2
        case .month: return 5
        }
    }

    private var totalForCurrentMetric: Double {
        dailyEntries.reduce(0) { acc, entry in
            acc + (chartMetric == .reps ? Double(entry.reps) : entry.minutes)
        }
    }

    @ViewBuilder
    private func sessionCell(_ session: WorkoutSession) -> some View {
        HStack(spacing: DS.Spacing.md) {
            if let exercise = session.exerciseType {
                DuoIconBadge(systemName: exercise.iconName, color: Duo.color(for: exercise), size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(exercise.displayName)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(DS.Colors.textPrimary)
                        if session.statusRaw == SessionStatus.cancelled.rawValue {
                            Text(Strings.History.cancelled)
                                .font(.caption2)
                                .foregroundColor(DS.Colors.error)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(DS.Colors.error.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: Strings.History.repsFormat, session.repCount))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Colors.textPrimary)
                if session.earnedMinutes > 0 {
                    Text("+\(TimeFormatter.formatMinutes(session.earnedMinutes))")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(DS.Colors.neon)
                }
            }
        }
        .padding(DS.Spacing.md)
        .dsCard(cornerRadius: DS.Corner.large)
    }
}
