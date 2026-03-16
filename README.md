# <img src="Images/icon.png" width="28"> Qingping Menu Bar

A lightweight macOS menu bar app for monitoring your **Qingping Air Monitor Lite** (CGDN1) in real time.

![Screenshot](Images/app.png)

## What it does

- Shows your current CO₂, PM2.5, PM10, temperature, humidity, and battery level in a clean popover
- Displays the selected metric (CO₂ by default) directly in your menu bar for at-a-glance monitoring
- 24-hour sparkline charts for every metric, color-coded by air quality thresholds
- Tap any metric to expand an interactive chart with hover cursor showing exact values and timestamps
- Trend arrows (↗ ↘) show whether each metric is rising or falling over the last hour
- Relative timestamps ("3 min ago") with a stale data warning when readings are older than 15 minutes
- Device offline detection with visual indicator
- °C / °F temperature unit toggle
- Automatically configures your device for the fastest possible cloud reporting (10 min upload, 1 min recording)
- Launch at login support

## Color thresholds

The sparkline charts, values, and trend arrows change color based on indoor air quality guidelines:

| Metric | Good (green) | Moderate (yellow) | Poor (orange) | Very Poor (red) |
|--------|-------------|-------------------|---------------|-----------------|
| CO₂ | < 800 ppm | 800–1000 | 1000–1500 | > 1500 |
| PM2.5 | < 12 µg/m³ | 12–35 | 35–55 | > 55 |
| PM10 | < 54 µg/m³ | 54–154 | 154–254 | > 254 |
| Temperature | 18–24°C | 16–26°C | 14–28°C | Outside range |
| Humidity | 30–60% | 20–70% | Outside range | — |

The overall quality badge in the header shows the worst level across all metrics.

## Requirements

- macOS 26 (Tahoe) or later
- A [Qingping Air Monitor Lite](https://www.qingping.co/air-monitor-lite/overview) (model CGDN1) connected to WiFi
- The device must be in **Qingping mode** (not HomeKit mode) via the Qingping+ app
- Qingping developer API credentials (free — see setup below)

## Setup

### 1. Set up your device

Download the **Qingping+** app ([iOS](https://apps.apple.com/app/qingping/id1344636968) / [Android](https://play.google.com/store/apps/details?id=com.cleargrass.app.air)) and add your Air Monitor Lite. Make sure the device is connected to WiFi and set to Qingping mode.

### 2. Get your API credentials

1. Go to [developer.qingping.co](https://developer.qingping.co/personal/permissionApply)
2. Register or log in with your Qingping account
3. You'll get an **App Key** and **App Secret** — keep these handy

### 3. Install the app

**Option A: Download the release**

Download the latest `.dmg` from the [Releases](../../releases) page. Open it, drag the app to your Applications folder, and launch it.

**Option B: Build from source**

```bash
git clone https://github.com/yourusername/QingpingMenuBar.git
cd QingpingMenuBar
open QingpingMenuBar.xcodeproj
```

Build and run from Xcode (requires Xcode 26+).

### 4. Enter your credentials

Click the menu bar icon → click **Settings** → paste your App Key and App Secret → click **Save**.

That's it. The app will start fetching data immediately.

## How it works

The app polls the Qingping cloud API every minute. The device uploads new readings to the cloud every 10 minutes (the app automatically configures this on first launch). Historical data for the last 24 hours is loaded on startup and refreshed every 10 minutes.

Your API credentials are stored securely in the macOS Keychain — they never leave your machine.

## Settings

Click the Settings button in the popover footer to access:

- **API Credentials** — your Qingping App Key and Secret (shown as "API connected" once saved)
- **Menu Bar Metric** — choose which metric to display in the menu bar (CO₂, PM2.5, PM10, Temperature, or Humidity)
- **Temperature Unit** — switch between °C and °F
- **Launch at login** — start the app automatically when you log in

## Privacy & security

- API credentials are stored in the macOS Keychain, scoped to this app's sandbox
- All API communication is over HTTPS — no plaintext HTTP
- No telemetry, analytics, or data collection — the app only talks to the Qingping API
- App Sandbox and Hardened Runtime are enabled
- API response bodies are never logged or displayed to the user

## Tech stack

- SwiftUI with `MenuBarExtra` (`.window` style)
- Swift Charts for interactive expanded charts
- Swift concurrency (`async/await`, actors)
- `@Observable` (Observation framework)
- macOS Keychain for credential storage
- Canvas API for threshold-colored sparkline charts
- Qingping Cloud API (OAuth2 + REST)

## Data freshness

The Qingping Air Monitor Lite uploads data to the cloud at a configurable interval. This app sets it to the minimum: every 10 minutes for uploads, every 1 minute for sensor recording. The cloud API always returns the latest uploaded reading — polling faster than 10 minutes won't yield newer data, but ensures you catch new uploads promptly.

If the reading is older than 15 minutes, a yellow warning appears. If the device goes offline, a red "Device offline" indicator is shown.

## License

MIT

## Disclaimer

This project is not affiliated with, endorsed by, or sponsored by Qingping or Cleargrass. "Qingping" is a trademark of Beijing Qingping Technology Co., Ltd. This app uses the publicly available Qingping Developer API.

## Acknowledgments

- [Qingping](https://www.qingping.co/) for making affordable, hackable air quality monitors with an open API
