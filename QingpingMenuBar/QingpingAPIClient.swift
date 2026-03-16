import Foundation

actor QingpingAPIClient {

    private static let tokenURL = URL(string: "https://oauth.cleargrass.com/oauth2/token")!
    private static let devicesURL = URL(string: "https://apis.cleargrass.com/v1/apis/devices")!
    private static let settingsURL = URL(string: "https://apis.cleargrass.com/v1/apis/devices/settings")!
    private static let historyURL = URL(string: "https://apis.cleargrass.com/v1/apis/devices/data")!

    private var cachedToken: String?
    private var tokenExpiry: Date = .distantPast
    private let session: URLSession

    init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
    }

    // MARK: - Public

    func fetchLatestReading(appKey: String, appSecret: String) async throws -> (AirQualityReading, Device) {
        let token = try await getToken(appKey: appKey, appSecret: appSecret)
        let devices = try await fetchDevices(token: token)

        guard let device = devices.first else {
            throw QingpingError.noDevices
        }

        let reading = mapToReading(device.data)
        return (reading, device)
    }

    func fetchAllDevices(appKey: String, appSecret: String) async throws -> [Device] {
        let token = try await getToken(appKey: appKey, appSecret: appSecret)
        return try await fetchDevices(token: token)
    }

    func updateDeviceSettings(
        appKey: String,
        appSecret: String,
        mac: String,
        reportInterval: Int,
        collectInterval: Int
    ) async throws {
        let token = try await getToken(appKey: appKey, appSecret: appSecret)

        var components = URLComponents(url: Self.settingsURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "timestamp", value: String(Int(Date().timeIntervalSince1970 * 1000)))
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "mac": [mac],
            "report_interval": reportInterval,
            "collect_interval": collectInterval
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        try validateResponse(response, data: data)
    }

    /// Fetch 24h historical data for a device.
    func fetchHistory(appKey: String, appSecret: String, mac: String) async throws -> [HistoryDataPoint] {
        let token = try await getToken(appKey: appKey, appSecret: appSecret)

        let endTime = Int(Date().timeIntervalSince1970)
        let startTime = endTime - (24 * 3600)
        var allPoints: [HistoryDataPoint] = []
        var currentStart = startTime

        let maxPages = 20
        var page = 0
        while currentStart < endTime, page < maxPages {
            page += 1
            var components = URLComponents(url: Self.historyURL, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "mac", value: mac),
                URLQueryItem(name: "start_time", value: String(currentStart)),
                URLQueryItem(name: "end_time", value: String(endTime)),
                URLQueryItem(name: "timestamp", value: String(Int(Date().timeIntervalSince1970 * 1000))),
                URLQueryItem(name: "limit", value: "200"),
            ]

            var request = URLRequest(url: components.url!)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await session.data(for: request)
            try validateResponse(response, data: data)

            let historyResponse = try JSONDecoder().decode(HistoryResponse.self, from: data)

            guard let points = historyResponse.data, !points.isEmpty else {
                break
            }

            allPoints.append(contentsOf: points)

            // If we got fewer than 200, we've reached the end
            if points.count < 200 {
                break
            }

            // Move start past the latest point we got
            if let lastTimestamp = points.last?.timestamp?.value {
                currentStart = lastTimestamp + 1
            } else {
                break
            }
        }

        return allPoints
    }

    // MARK: - Token

    private func getToken(appKey: String, appSecret: String) async throws -> String {
        if let token = cachedToken, tokenExpiry > Date().addingTimeInterval(60) {
            return token
        }
        // Clear expired token from memory
        cachedToken = nil

        var request = URLRequest(url: Self.tokenURL)
        request.httpMethod = "POST"

        let credentials = "\(appKey):\(appSecret)"
        guard let credData = credentials.data(using: .utf8) else {
            throw QingpingError.invalidCredentials
        }
        let base64Creds = credData.base64EncodedString()
        request.setValue("Basic \(base64Creds)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "grant_type=client_credentials&scope=device_full_access"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)

        cachedToken = tokenResponse.accessToken
        tokenExpiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))

        return tokenResponse.accessToken
    }

    // MARK: - Devices

    private func fetchDevices(token: String) async throws -> [Device] {
        var components = URLComponents(url: Self.devicesURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "timestamp", value: String(Int(Date().timeIntervalSince1970 * 1000)))
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        do {
            let deviceResponse = try JSONDecoder().decode(DeviceListResponse.self, from: data)
            return deviceResponse.devices
        } catch {
            print("[QingpingAPI] Decoding error: \(error)")
            throw QingpingError.decodingFailed(detail: String(describing: error))
        }
    }

    // MARK: - Helpers

    private func validateResponse(_ response: URLResponse, data: Data? = nil) throws {
        guard let http = response as? HTTPURLResponse else {
            throw QingpingError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "no body"
            throw QingpingError.httpError(statusCode: http.statusCode, body: body)
        }
    }

    private func mapToReading(_ data: DeviceData) -> AirQualityReading {
        let date: Date
        if let ts = data.timestamp?.value {
            date = Date(timeIntervalSince1970: TimeInterval(ts))
        } else {
            date = .now
        }

        return AirQualityReading(
            timestamp: date,
            temperature: data.temperature?.value,
            humidity: data.humidity?.value,
            co2: data.co2?.value,
            pm25: data.pm25?.value,
            pm10: data.pm10?.value,
            battery: data.battery?.value,
            tvoc: data.tvoc?.value
        )
    }
}

// MARK: - Errors

nonisolated enum QingpingError: LocalizedError, Sendable {
    case invalidCredentials
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case noDevices
    case decodingFailed(detail: String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid API credentials."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .httpError(let code, _):
            return "Qingping API request failed (HTTP \(code))."
        case .noDevices:
            return "No devices found on your Qingping account."
        case .decodingFailed(let detail):
            return "Failed to parse API response: \(detail)"
        }
    }
}
