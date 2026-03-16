import SwiftUI

struct MenuBarLabel: View {
    var viewModel: AirQualityViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
            if let text = valueText {
                Text(text)
                    .monospacedDigit()
            }
        }
    }

    private var metric: MenuBarMetric {
        viewModel.menuBarMetric
    }

    private var iconName: String {
        if viewModel.isDeviceOffline {
            return "wifi.slash"
        }
        if viewModel.errorMessage != nil {
            return "exclamationmark.icloud"
        }
        switch metric {
        case .co2:         return "carbon.dioxide.cloud"
        case .pm25:        return "aqi.medium"
        case .pm10:        return "aqi.low"
        case .temperature: return "thermometer.medium"
        case .humidity:    return "humidity"
        }
    }

    private var valueText: String? {
        switch metric {
        case .co2:
            guard let v = viewModel.reading.co2 else { return nil }
            return "\(Int(v))"
        case .pm25:
            guard let v = viewModel.reading.pm25 else { return nil }
            return "\(Int(v))"
        case .pm10:
            guard let v = viewModel.reading.pm10 else { return nil }
            return "\(Int(v))"
        case .temperature:
            guard let v = viewModel.reading.temperature else { return nil }
            let unit = viewModel.temperatureUnit
            return String(format: "%.1f%@", unit.convert(v), unit.symbol)
        case .humidity:
            guard let v = viewModel.reading.humidity else { return nil }
            return "\(Int(v))%"
        }
    }
}
