# 5sAvailator

Give practical new life to an **iPhone 5s on iOS 12** by combining:

- **Local Web Mode** — simple, compatible pages rendered directly in `WKWebView` on the device
- **Remote Browser Mode** — modern websites rendered by a Chromium browser on the server, with JPEG frames streamed to the iPhone

---

## Projects

### `server/` — Node.js + TypeScript + Playwright backend

Runs a headless Chromium browser and exposes a simple REST API for the iOS client.

#### Setup

```bash
cd server
npm install
npx playwright install chromium   # download Chromium
npm run build                     # compile TypeScript
npm start                         # start on port 3000
```

Override the port with the `PORT` environment variable.

#### API

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/sessions` | Create a new remote browser session |
| `POST` | `/sessions/:id/navigate` | Navigate to a URL |
| `GET` | `/sessions/:id/frame` | Get the current page as a JPEG |
| `POST` | `/sessions/:id/input/tap` | Send a tap/click |
| `POST` | `/sessions/:id/input/scroll` | Send a scroll event |
| `POST` | `/sessions/:id/input/text` | Type text |
| `GET` | `/sessions/:id/state` | Get session state |
| `DELETE` | `/sessions/:id` | Close the session |

All endpoints except `POST /sessions` require a `Bearer <token>` Authorization header using the token returned when the session was created.

#### Tests

```bash
cd server
npm test
```

---

### `ios-app/` — UIKit iOS app (iPhone 5s, iOS 12)

Open `ios-app/5sAvailator.xcodeproj` in Xcode 11+ and build for an iPhone 5s device or simulator running iOS 12.

Set the `SERVER_URL` environment variable in the Xcode scheme to point to your server (e.g. `http://192.168.1.100:3000`).

#### Components

| File | Role |
|------|------|
| `AppDelegate.swift` | App entry point, bootstraps the launcher |
| `ServiceDefinition.swift` | Service model (name, URL, mode: local/remote) |
| `NetworkClient.swift` | URLSession-based HTTP client for the server API |
| `SessionStore.swift` | Remote session lifecycle management |
| `LauncherViewController.swift` | Home screen listing services |
| `WebContainerViewController.swift` | WKWebView container for local-compatible pages |
| `RemoteCanvasViewController.swift` | Remote frame display, touch/scroll/text input |

---

## Protocol Contract

The viewport default is **320 × 568** (iPhone 5s logical resolution).

Coordinate mapping: touch points in the frame image view are scaled to server viewport coordinates proportionally.

Frame delivery: JPEG polling at ~500 ms interval.

Authentication: per-session UUID token via `Authorization: Bearer <token>` header.

Session idle timeout: 10 minutes of inactivity.

