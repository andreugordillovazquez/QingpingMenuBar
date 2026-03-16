import SwiftUI
import ServiceManagement
import Charts

struct MenuBarPopoverView: View {
    var viewModel: AirQualityViewModel
    @State private var showSettings: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            header
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            if let error = viewModel.errorMessage {
                errorBanner(error)
                    .padding(16)
            }

            if viewModel.reading != .placeholder || viewModel.errorMessage == nil {
                sensorList
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }

            if showSettings {
                settingsSection
                    .padding(16)
            }

            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 320)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(viewModel.deviceName)
                        .font(.headline)
                    if let battery = viewModel.reading.battery {
                        HStack(spacing: 2) {
                            Image(systemName: batteryIcon(battery))
                                .font(.caption2)
                            Text("\(Int(battery))%")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                if viewModel.isDeviceOffline {
                    HStack(spacing: 4) {
                        Image(systemName: "wifi.slash")
                            .font(.caption2)
                        Text("Device offline")
                            .font(.caption)
                    }
                    .foregroundStyle(.red)
                } else if viewModel.reading != .placeholder {
                    HStack(spacing: 4) {
                        if viewModel.isStale {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                        Text(viewModel.reading.timestamp, style: .relative)
                            .font(.caption)
                            .foregroundStyle(viewModel.isStale ? .yellow : .secondary)
                        + Text(" ago")
                            .font(.caption)
                            .foregroundStyle(viewModel.isStale ? .yellow : .secondary)
                    }
                }
            }
            Spacer()
            overallBadge
        }
    }

    private var overallBadge: some View {
        let level = AirQualityThresholds.overallLevel(reading: viewModel.reading)
        return HStack(spacing: 4) {
            Image(systemName: level.systemImage)
            Text(level.rawValue)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(level.color)
    }

    // MARK: - Sensor List with Sparklines

    private var sensorList: some View {
        VStack(spacing: 8) {
            if let co2 = viewModel.reading.co2 {
                SensorRow(
                    title: "CO₂", icon: "carbon.dioxide.cloud",
                    value: "\(Int(co2))", unit: "ppm",
                    level: AirQualityThresholds.co2Level(co2),
                    history: viewModel.co2History,
                    thresholdColor: { AirQualityThresholds.co2Level($0).color }
                )
            }
            if let pm25 = viewModel.reading.pm25 {
                SensorRow(
                    title: "PM2.5", icon: "aqi.medium",
                    value: String(format: "%.0f", pm25), unit: "µg/m³",
                    level: AirQualityThresholds.pm25Level(pm25),
                    history: viewModel.pm25History,
                    thresholdColor: { AirQualityThresholds.pm25Level($0).color }
                )
            }
            if let pm10 = viewModel.reading.pm10 {
                SensorRow(
                    title: "PM10", icon: "aqi.low",
                    value: String(format: "%.0f", pm10), unit: "µg/m³",
                    level: AirQualityThresholds.pm10Level(pm10),
                    history: viewModel.pm10History,
                    thresholdColor: { AirQualityThresholds.pm10Level($0).color }
                )
            }
            if let temp = viewModel.reading.temperature {
                let unit = viewModel.temperatureUnit
                SensorRow(
                    title: "Temp", icon: "thermometer.medium",
                    value: String(format: "%.1f", unit.convert(temp)), unit: unit.symbol,
                    level: AirQualityThresholds.temperatureLevel(temp),
                    history: viewModel.tempHistory,
                    thresholdColor: { AirQualityThresholds.temperatureLevel($0).color }
                )
            }
            if let humidity = viewModel.reading.humidity {
                SensorRow(
                    title: "Humidity", icon: "humidity",
                    value: String(format: "%.0f", humidity), unit: "%",
                    level: AirQualityThresholds.humidityLevel(humidity),
                    history: viewModel.humidityHistory,
                    thresholdColor: { AirQualityThresholds.humidityLevel($0).color }
                )
            }
        }
    }

    private func batteryIcon(_ percent: Double) -> String {
        switch percent {
        case ..<25:  return "battery.25percent"
        case ..<50:  return "battery.50percent"
        case ..<75:  return "battery.75percent"
        default:     return "battery.100percent"
        }
    }

    // MARK: - Settings Section

    @State private var appKey: String = CredentialsStore.appKey ?? ""
    @State private var appSecret: String = CredentialsStore.appSecret ?? ""
    @State private var saved: Bool = false
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @State private var editingCredentials: Bool = false
    @State private var selectedMetric: MenuBarMetric = MenuBarMetric.from(stored: MenuBarMetricSetting.metric)
    @State private var selectedTempUnit: TemperatureUnit = .current

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Credentials
            if CredentialsStore.hasCredentials && !editingCredentials {
                HStack {
                    Label("API connected", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Spacer()
                    Button("Edit") {
                        editingCredentials = true
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("API Credentials")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("App Key", text: $appKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    SecureField("App Secret", text: $appSecret)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    HStack {
                        Button("Save") {
                            CredentialsStore.appKey = appKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            CredentialsStore.appSecret = appSecret.trimmingCharacters(in: .whitespacesAndNewlines)
                            editingCredentials = false
                            saved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
                        }
                        .font(.caption)
                        .disabled(appKey.isEmpty || appSecret.isEmpty)

                        if CredentialsStore.hasCredentials {
                            Button("Cancel") {
                                appKey = CredentialsStore.appKey ?? ""
                                appSecret = CredentialsStore.appSecret ?? ""
                                editingCredentials = false
                            }
                            .font(.caption)
                            .buttonStyle(.borderless)
                        }

                        if saved {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }
                }
            }

            // Menu bar metric
            HStack {
                Text("Menu Bar Metric")
                    .font(.caption)
                Spacer()
                Picker("Menu Bar Metric", selection: $selectedMetric) {
                    ForEach(MenuBarMetric.allCases) { metric in
                        Text(metric.label(unit: viewModel.temperatureUnit)).tag(metric)
                    }
                }
                .labelsHidden()
                .font(.caption)
            }
            .onChange(of: selectedMetric) { _, newValue in
                MenuBarMetricSetting.metric = newValue.rawValue
                viewModel.menuBarMetric = newValue
            }

            // Temperature unit
            HStack {
                Text("Temperature")
                    .font(.caption)
                Spacer()
                Picker("Temperature", selection: $selectedTempUnit) {
                    ForEach(TemperatureUnit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .labelsHidden()
                .font(.caption)
            }
            .onChange(of: selectedTempUnit) { _, newValue in
                TemperatureUnitSetting.unit = newValue.rawValue
                viewModel.temperatureUnit = newValue
            }

            // Launch at login
            HStack {
                Text("Launch at login")
                    .font(.caption)
                Spacer()
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        print("[QingpingMenuBar] Launch at login error: \(error)")
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.isLoading)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSettings.toggle()
                }
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .font(.caption)
            }
            .buttonStyle(.borderless)

            Spacer()
                .frame(width: 12)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
    }
}

// MARK: - Sensor Row with Sparkline

struct SensorRow: View {
    let title: String
    let icon: String
    let value: String
    let unit: String
    let level: QualityLevel
    let history: [HistoryPoint]
    let thresholdColor: (Double) -> Color

    @State private var expanded = false

    private var trend: Trend {
        Trend.from(history: history)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(value)
                            .font(.title3.monospacedDigit().weight(.semibold))
                            .foregroundStyle(level.color)
                        Text(unit)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        if trend != .stable {
                            Image(systemName: trend.systemImage)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(trend.color(for: level))
                        }
                    }
                }
                .frame(maxWidth: expanded ? .infinity : 110, alignment: .leading)

                if !expanded, history.count >= 2 {
                    SparklineView(points: history, thresholdColor: thresholdColor)
                        .frame(height: 32)
                        .frame(maxWidth: .infinity)
                } else if !expanded {
                    Spacer()
                }
            }

            if expanded && history.count >= 2 {
                ExpandedChartView(points: history, unit: unit, thresholdColor: thresholdColor)
                    .frame(height: 120)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                expanded.toggle()
            }
        }
    }
}

// MARK: - Expanded Chart View

struct ExpandedChartView: View {
    let points: [HistoryPoint]
    let unit: String
    let thresholdColor: (Double) -> Color

    @State private var selectedPoint: HistoryPoint?

    private var yMin: Double {
        let values = points.map(\.value)
        let dataMin = values.min() ?? 0
        let dataMax = values.max() ?? 1
        let pad = max((dataMax - dataMin) * 0.1, 1)
        return max(0, dataMin - pad)
    }

    private var yMax: Double {
        let values = points.map(\.value)
        let dataMin = values.min() ?? 0
        let dataMax = values.max() ?? 1
        let pad = max((dataMax - dataMin) * 0.1, 1)
        return dataMax + pad
    }

    /// Split points into segments of the same threshold color, overlapping by one point for continuity.
    private var segments: [ChartSegment] {
        guard points.count >= 2 else { return [] }
        var result: [ChartSegment] = []
        var currentColor = thresholdColor(points[0].value)
        var currentPoints = [points[0]]

        for i in 1..<points.count {
            let color = thresholdColor(points[i].value)
            if color != currentColor {
                result.append(ChartSegment(color: currentColor, points: currentPoints))
                currentColor = color
                currentPoints = [points[i - 1]]
            }
            currentPoints.append(points[i])
        }
        result.append(ChartSegment(color: currentColor, points: currentPoints))
        return result
    }

    @ChartContentBuilder
    private var lineMarks: some ChartContent {
        ForEach(Array(segments.enumerated()), id: \.offset) { idx, segment in
            ForEach(segment.points) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value),
                    series: .value("Segment", idx)
                )
                .foregroundStyle(segment.color)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.catmullRom)
            }
        }
    }

    @ChartContentBuilder
    private var cursorMarks: some ChartContent {
        if let selected = selectedPoint {
            PointMark(
                x: .value("Time", selected.timestamp),
                y: .value("Value", selected.value)
            )
            .foregroundStyle(thresholdColor(selected.value))
            .symbolSize(30)
        }
    }

    private func annotationLabel(for point: HistoryPoint) -> some View {
        VStack(spacing: 2) {
            Text(point.timestamp, format: .dateTime.hour().minute().second())
                .foregroundStyle(.secondary)
            Text("\(formatValue(point.value)) \(unit)")
                .fontWeight(.semibold)
                .foregroundStyle(thresholdColor(point.value))
        }
        .font(.system(size: 9).monospacedDigit())
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
    }

    var body: some View {
        Chart {
            lineMarks
            cursorMarks
        }
        .chartYScale(domain: yMin ... yMax)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel(format: .dateTime.hour().minute())
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel()
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                guard let plotFrame = proxy.plotFrame else { return }
                                let origin = geo[plotFrame].origin
                                let x = location.x - origin.x
                                if let date: Date = proxy.value(atX: x) {
                                    selectedPoint = closestPoint(to: date)
                                }
                            case .ended:
                                selectedPoint = nil
                            }
                        }

                    if let selected = selectedPoint,
                       let plotFrame = proxy.plotFrame {
                        let frame = geo[plotFrame]
                        if let xPos: CGFloat = proxy.position(forX: selected.timestamp) {
                            // Dashed vertical line
                            Path { path in
                                path.move(to: CGPoint(x: frame.origin.x + xPos, y: frame.origin.y))
                                path.addLine(to: CGPoint(x: frame.origin.x + xPos, y: frame.origin.y + frame.height))
                            }
                            .stroke(.white.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [4, 3]))

                            // Annotation tooltip
                            annotationLabel(for: selected)
                                .position(x: frame.origin.x + xPos, y: frame.origin.y - 4)
                        }
                    }
                }
            }
        }
    }

    private func closestPoint(to date: Date) -> HistoryPoint? {
        points.min(by: { abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date)) })
    }

    private func formatValue(_ value: Double) -> String {
        if abs(value) >= 100 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}

nonisolated struct ChartSegment {
    let color: Color
    let points: [HistoryPoint]
}

// MARK: - Sparkline View (threshold-colored segments)

struct SparklineView: View {
    let points: [HistoryPoint]
    let thresholdColor: (Double) -> Color

    var body: some View {
        GeometryReader { geo in
            let values = points.map(\.value)
            let minVal = values.min() ?? 0
            let maxVal = values.max() ?? 1
            let range = maxVal - minVal
            let safeRange = range > 0 ? range : 1

            Canvas { context, size in
                guard points.count >= 2 else { return }

                for i in 1..<points.count {
                    let x0 = size.width * CGFloat(i - 1) / CGFloat(points.count - 1)
                    let y0 = size.height * (1 - CGFloat((points[i - 1].value - minVal) / safeRange))
                    let x1 = size.width * CGFloat(i) / CGFloat(points.count - 1)
                    let y1 = size.height * (1 - CGFloat((points[i].value - minVal) / safeRange))

                    var segment = Path()
                    segment.move(to: CGPoint(x: x0, y: y0))
                    segment.addLine(to: CGPoint(x: x1, y: y1))

                    let color = thresholdColor(points[i].value)
                    context.stroke(segment, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }
            }
        }
    }
}

// MARK: - Trend

nonisolated enum Trend {
    case rising
    case falling
    case stable

    var systemImage: String {
        switch self {
        case .rising:  return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .stable:  return ""
        }
    }

    func color(for level: QualityLevel) -> Color {
        switch (self, level) {
        case (.falling, .good), (.falling, .moderate):
            return .green   // falling toward good
        case (.rising, .poor), (.rising, .veryPoor):
            return .red     // rising toward worse
        default:
            return .secondary
        }
    }

    /// Compare the average of the last hour to the average of the hour before that.
    /// Requires at least 2 points. Uses a 5% threshold to avoid noise.
    static func from(history: [HistoryPoint]) -> Trend {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let recentPoints = history.filter { $0.timestamp >= oneHourAgo }
        let olderPoints = history.filter { $0.timestamp < oneHourAgo }

        guard !recentPoints.isEmpty, !olderPoints.isEmpty else { return .stable }

        let recentAvg = recentPoints.map(\.value).reduce(0, +) / Double(recentPoints.count)
        let olderAvg = olderPoints.map(\.value).reduce(0, +) / Double(olderPoints.count)

        guard olderAvg > 0 else { return .stable }
        let change = (recentAvg - olderAvg) / olderAvg

        if change > 0.05 { return .rising }
        if change < -0.05 { return .falling }
        return .stable
    }
}

// MARK: - Menu Bar Metric

enum MenuBarMetric: String, CaseIterable, Identifiable {
    case co2 = "co2"
    case pm25 = "pm25"
    case pm10 = "pm10"
    case temperature = "temperature"
    case humidity = "humidity"

    var id: String { rawValue }

    func label(unit: TemperatureUnit = .current) -> String {
        switch self {
        case .co2:         return "CO₂ (ppm)"
        case .pm25:        return "PM2.5 (µg/m³)"
        case .pm10:        return "PM10 (µg/m³)"
        case .temperature: return "Temperature (\(unit.symbol))"
        case .humidity:    return "Humidity (%)"
        }
    }

    static func from(stored: String) -> MenuBarMetric {
        MenuBarMetric(rawValue: stored) ?? .co2
    }
}

enum MenuBarMetricSetting {
    private static let key = "menuBarMetric"
    static var metric: String {
        get { UserDefaults.standard.string(forKey: key) ?? "co2" }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

// MARK: - Temperature Unit

enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius = "celsius"
    case fahrenheit = "fahrenheit"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .celsius:    return "°C"
        case .fahrenheit: return "°F"
        }
    }

    var symbol: String { label }

    func convert(_ celsius: Double) -> Double {
        switch self {
        case .celsius:    return celsius
        case .fahrenheit: return celsius * 9 / 5 + 32
        }
    }

    static var current: TemperatureUnit {
        TemperatureUnit(rawValue: TemperatureUnitSetting.unit) ?? .celsius
    }
}

enum TemperatureUnitSetting {
    private static let key = "temperatureUnit"
    static var unit: String {
        get { UserDefaults.standard.string(forKey: key) ?? "celsius" }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

// MARK: - Poll Settings

enum PollSettings {
    static let interval: TimeInterval = 60
}
