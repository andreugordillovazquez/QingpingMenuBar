import SwiftUI

// MARK: - Quality Level

enum QualityLevel: String {
    case good = "Good"
    case moderate = "Moderate"
    case poor = "Poor"
    case veryPoor = "Very Poor"

    var color: Color {
        switch self {
        case .good:      return .green
        case .moderate:  return .yellow
        case .poor:      return .orange
        case .veryPoor:  return .red
        }
    }

    var systemImage: String {
        switch self {
        case .good:      return "checkmark.circle.fill"
        case .moderate:  return "exclamationmark.circle.fill"
        case .poor:      return "exclamationmark.triangle.fill"
        case .veryPoor:  return "xmark.octagon.fill"
        }
    }
}

// MARK: - Thresholds

/// Evaluates air quality levels based on common indoor guidelines.
enum AirQualityThresholds {

    static func co2Level(_ ppm: Double) -> QualityLevel {
        switch ppm {
        case ..<800:   return .good
        case ..<1000:  return .moderate
        case ..<1500:  return .poor
        default:       return .veryPoor
        }
    }

    static func pm25Level(_ ugm3: Double) -> QualityLevel {
        switch ugm3 {
        case ..<12:   return .good
        case ..<35:   return .moderate
        case ..<55:   return .poor
        default:      return .veryPoor
        }
    }

    static func pm10Level(_ ugm3: Double) -> QualityLevel {
        switch ugm3 {
        case ..<54:    return .good
        case ..<154:   return .moderate
        case ..<254:   return .poor
        default:       return .veryPoor
        }
    }

    static func temperatureLevel(_ celsius: Double) -> QualityLevel {
        switch celsius {
        case 18..<24:  return .good
        case 16..<26:  return .moderate
        case 14..<28:  return .poor
        default:       return .veryPoor
        }
    }

    static func humidityLevel(_ percent: Double) -> QualityLevel {
        switch percent {
        case 30..<60:  return .good
        case 20..<70:  return .moderate
        default:       return .poor
        }
    }

    /// Overall quality based on the worst individual metric.
    static func overallLevel(reading: AirQualityReading) -> QualityLevel {
        var worst: QualityLevel = .good

        if let co2 = reading.co2 {
            worst = max(worst, co2Level(co2))
        }
        if let pm25 = reading.pm25 {
            worst = max(worst, pm25Level(pm25))
        }
        if let pm10 = reading.pm10 {
            worst = max(worst, pm10Level(pm10))
        }
        if let temp = reading.temperature {
            worst = max(worst, temperatureLevel(temp))
        }
        if let humidity = reading.humidity {
            worst = max(worst, humidityLevel(humidity))
        }

        return worst
    }
}

// MARK: - Comparable conformance for QualityLevel

extension QualityLevel: Comparable {
    private var severity: Int {
        switch self {
        case .good:      return 0
        case .moderate:  return 1
        case .poor:      return 2
        case .veryPoor:  return 3
        }
    }

    static func < (lhs: QualityLevel, rhs: QualityLevel) -> Bool {
        lhs.severity < rhs.severity
    }
}
