# Contributing to LumaEdge 💡✨

First off, thank you for considering contributing to LumaEdge! Whether you're fixing a bug, adding a new lighting preset, optimizing Metal/CoreAnimation shaders, or writing documentation, your contributions are warmly welcomed.

---

## Development Setup

### Requirements
- **macOS 14.0 Sonoma** or **macOS 15.0 Sequoia**
- **Xcode 15.0+** (or Swift 5.10+ / Swift 6 toolchain)
- Apple Silicon (M1/M2/M3/M4) recommended for accurate ProMotion & EDR testing

### Building & Running from Source
1. Clone the repository:
   ```bash
   git clone https://github.com/aditya/LumaEdge.git
   cd LumaEdge
   ```
2. Build release binary via Swift Package Manager:
   ```bash
   swift build -c release
   ```
3. Run unit tests to verify your environment:
   ```bash
   swift test
   ```
4. Launch the application:
   ```bash
   open build/LumaEdge.app
   # Or directly: .build/release/LumaEdgeApp
   ```

---

## Architectural Principles & Coding Standards

1. **Native AppKit & SwiftUI Only**: Do not introduce web views (`WKWebView`), third-party UI bridges, or external C/C++ dependencies unless strictly required for hardware interaction.
2. **Swift 6 Concurrency**: Ensure all new types adhere to `Sendable` requirements. Annotate UI or master state mutations with `@MainActor`.
3. **Rendering Efficiency**: Any changes to `CanvasEdgeView.swift` or `EdgeRenderer.swift` must maintain zero-copy `CALayer` rendering. Do not add continuous polling loops or heavy `body` re-computations inside SwiftUI during animations.
4. **Sandboxing & IPC**: Preserve App Sandbox compatibility wherever possible. When communicating between `LumaEdgeApp` and `lumaedge` CLI, use local `DistributedNotificationCenter` commands.

---

## Testing Guidelines

Every new feature or bug fix must include automated unit tests inside `Tests/LumaEdgeTests/`.
We currently maintain five isolated test phases (`LumaEdgeCoreTests`, `LumaEdgePhase2Tests`, `LumaEdgePhase3Tests`, `LumaEdgePhase4Tests`, and `LumaEdgePhase5Tests`).
Ensure your changes pass 100% of the test suite before submitting a Pull Request:
```bash
swift test --parallel
```

---

## Pull Request Process

1. Fork the repository and create a descriptive feature branch (`feature/custom-presets` or `fix/multi-monitor-hotplug`).
2. Include a clear summary of changes, rationale, and screenshots/recordings if modifying UI or optical rendering.
3. Ensure all unit tests pass locally (`swift test`).
4. Submit your PR for review!
