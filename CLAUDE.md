# CLAUDE.md

## Project overview

QingpingMenuBar is a macOS menu bar app that monitors Qingping Air Monitor Lite (CGDN1) devices via the Cleargrass Cloud API. It displays real-time CO2, PM2.5, PM10, temperature, humidity, and battery data with 24h sparkline charts.

## Build & run

- Open `QingpingMenuBar.xcodeproj` in Xcode 26+
- Build target: macOS 26 (Tahoe)
- No SPM dependencies — pure SwiftUI + system frameworks
- App Sandbox and Hardened Runtime are enabled
- The app requires outgoing network connections entitlement (already configured)

## Architecture

- **SwiftUI** with `MenuBarExtra` (`.window` style) — no dock icon (`LSUIElement = YES`)
- **@Observable** pattern (not ObservableObject) for Swift 6.2 `MainActor` default isolation
- **Actor-isolated API client** (`QingpingAPIClient`) — separate from MainActor, handles all HTTP
- **All model types are `nonisolated` and `Sendable`** — they cross actor boundaries freely
- **Ephemeral URLSession** — no disk caching of API responses

## Key files

| File | Purpose |
|------|---------|
| `QingpingMenuBarApp.swift` | App entry point, Keychain migration |
| `AirQualityViewModel.swift` | Central state, polling, history management |
| `QingpingAPIClient.swift` | OAuth2 + REST API calls (actor) |
| `Models.swift` | Codable types matching API JSON |
| `MenuBarPopoverView.swift` | Popover UI, charts, settings, supporting types |
| `MenuBarLabel.swift` | Menu bar icon and value display |
| `AirQualityThresholds.swift` | Quality level definitions and thresholds |
| `CredentialsStore.swift` | Keychain read/write/migrate |

## Conventions

- All types default to `MainActor` isolation (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`)
- Data models must be marked `nonisolated` to be usable from `QingpingAPIClient`
- Keychain service name must match the bundle ID (`com.andreugordillo.QingpingMenuBar`)
- No debug logging of secrets — auth headers and API response bodies are never printed
- History arrays are capped at 500 points per metric to limit memory
- Temperature thresholds evaluate in Celsius regardless of display unit

## Common tasks

- **Adding a new sensor metric**: Add field to `DeviceData`, `AirQualityReading`, `HistoryDataPoint`. Add history array in viewmodel. Add `SensorRow` in popover. Add threshold function in `AirQualityThresholds`.
- **Changing poll interval**: Edit `PollSettings.interval` in `MenuBarPopoverView.swift`
- **Changing history refresh interval**: Edit the `600` second check in `AirQualityViewModel.refresh()`
