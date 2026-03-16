import Foundation
import SwiftUI

@Observable
@MainActor
final class AirQualityViewModel {

    // MARK: - State

    var reading: AirQualityReading = .placeholder
    var deviceName: String = "—"
    var isLoading: Bool = false
    var errorMessage: String?
    var lastUpdated: Date?

    var co2History: [HistoryPoint] = []
    var pm25History: [HistoryPoint] = []
    var pm10History: [HistoryPoint] = []
    var tempHistory: [HistoryPoint] = []
    var humidityHistory: [HistoryPoint] = []

    var menuBarMetric: MenuBarMetric = MenuBarMetric.from(stored: MenuBarMetricSetting.metric)
    var temperatureUnit: TemperatureUnit = .current
    var isDeviceOffline: Bool = false

    /// Reading is older than 15 minutes.
    var isStale: Bool {
        reading != .placeholder && Date().timeIntervalSince(reading.timestamp) > 900
    }

    // MARK: - Private

    private let api = QingpingAPIClient()
    private var timer: Timer?
    @ObservationIgnored private var deviceMac: String?
    @ObservationIgnored private var hasPushedDeviceSettings = false
    @ObservationIgnored private var lastHistoryFetch: Date = .distantPast

    // MARK: - Lifecycle

    init() {
        startPolling()
    }

    // MARK: - Polling

    func startPolling() {
        Task { await refresh() }

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: PollSettings.interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Refresh

    func refresh() async {
        guard let appKey = CredentialsStore.appKey,
              let appSecret = CredentialsStore.appSecret else {
            errorMessage = "No API credentials configured. Open Settings to add them."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let (newReading, device) = try await api.fetchLatestReading(
                appKey: appKey,
                appSecret: appSecret
            )
            reading = newReading
            deviceMac = device.info.mac
            isDeviceOffline = device.info.status?.offline ?? false
            deviceName = device.info.name
                ?? device.info.product?.enName
                ?? device.info.product?.name
                ?? "Qingping Monitor"
            lastUpdated = .now

            if !hasPushedDeviceSettings {
                hasPushedDeviceSettings = true
                await pushOptimalDeviceSettings()
            }

            if Date().timeIntervalSince(lastHistoryFetch) > 600 {
                await fetchHistory()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - History

    func fetchHistory() async {
        guard let appKey = CredentialsStore.appKey,
              let appSecret = CredentialsStore.appSecret,
              let mac = deviceMac else { return }

        do {
            let points = try await api.fetchHistory(
                appKey: appKey,
                appSecret: appSecret,
                mac: mac
            )
            lastHistoryFetch = .now

            co2History = points.compactMap { p in
                guard let ts = p.timestamp?.value, let v = p.co2?.value else { return nil }
                return HistoryPoint(timestamp: Date(timeIntervalSince1970: TimeInterval(ts)), value: v)
            }
            pm25History = points.compactMap { p in
                guard let ts = p.timestamp?.value, let v = p.pm25?.value else { return nil }
                return HistoryPoint(timestamp: Date(timeIntervalSince1970: TimeInterval(ts)), value: v)
            }
            pm10History = points.compactMap { p in
                guard let ts = p.timestamp?.value, let v = p.pm10?.value else { return nil }
                return HistoryPoint(timestamp: Date(timeIntervalSince1970: TimeInterval(ts)), value: v)
            }
            tempHistory = points.compactMap { p in
                guard let ts = p.timestamp?.value, let v = p.temperature?.value else { return nil }
                return HistoryPoint(timestamp: Date(timeIntervalSince1970: TimeInterval(ts)), value: v)
            }
            humidityHistory = points.compactMap { p in
                guard let ts = p.timestamp?.value, let v = p.humidity?.value else { return nil }
                return HistoryPoint(timestamp: Date(timeIntervalSince1970: TimeInterval(ts)), value: v)
            }

            // Cap history to most recent 500 points to limit memory
            let maxPoints = 500
            if co2History.count > maxPoints { co2History = Array(co2History.suffix(maxPoints)) }
            if pm25History.count > maxPoints { pm25History = Array(pm25History.suffix(maxPoints)) }
            if pm10History.count > maxPoints { pm10History = Array(pm10History.suffix(maxPoints)) }
            if tempHistory.count > maxPoints { tempHistory = Array(tempHistory.suffix(maxPoints)) }
            if humidityHistory.count > maxPoints { humidityHistory = Array(humidityHistory.suffix(maxPoints)) }

            print("[QingpingMenuBar] Loaded \(points.count) history points")
        } catch {
            print("[QingpingMenuBar] Failed to load history: \(error.localizedDescription)")
        }
    }

    // MARK: - Device Settings

    private func pushOptimalDeviceSettings() async {
        guard let appKey = CredentialsStore.appKey,
              let appSecret = CredentialsStore.appSecret,
              let mac = deviceMac else { return }

        do {
            try await api.updateDeviceSettings(
                appKey: appKey,
                appSecret: appSecret,
                mac: mac,
                reportInterval: 600,
                collectInterval: 60
            )
            print("[QingpingMenuBar] Device intervals set to optimal: upload=600s, collect=60s")
        } catch {
            print("[QingpingMenuBar] Failed to set device intervals: \(error.localizedDescription)")
        }
    }
}
