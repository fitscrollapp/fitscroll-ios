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
            case .minutes: return "Minutes"
            case .reps: return "Reps"
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
            Group {
                if sessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationTitle(Strings.History.title)
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "clock")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text(Strings.History.noSessions)
                .foregroundColor(.secondary)
        }
    }

    private var sessionList: some View {
        List {
            Section(Strings.History.totalAllTime) {
                HStack(spacing: DS.Spacing.md) {
                    StatCard(title: "Sessions", value: "\(totalSessions)", icon: "flame.fill", color: DS.Colors.accent)
                    StatCard(title: "Reps", value: "\(totalReps)", icon: "repeat", color: DS.Colors.primary)
                    StatCard(title: "Minutes", value: TimeFormatter.formatMinutes(totalMinutes), icon: "clock.fill", color: DS.Colors.success)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Activity") {
                activityChart
                    .listRowInsets(EdgeInsets(top: DS.Spacing.md, leading: DS.Spacing.md, bottom: DS.Spacing.md, trailing: DS.Spacing.md))
            }

            Section("Sessions") {
                ForEach(sessions) { session in
                    sessionCell(session)
                }
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
                Text("No activity in this range yet")
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
                    colors: [DS.Colors.primary, DS.Colors.secondary],
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
        HStack {
            if let exercise = session.exerciseType {
                ExerciseIconView(exerciseType: exercise, size: 24, color: DS.Colors.primary)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(exercise.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if session.statusRaw == SessionStatus.cancelled.rawValue {
                            Text("Cancelled")
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
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(session.repCount) reps")
                    .font(.subheadline)
                Text(TimeFormatter.formatMinutes(session.earnedMinutes))
                    .font(.caption)
                    .foregroundColor(DS.Colors.accent)
            }
        }
    }
}
