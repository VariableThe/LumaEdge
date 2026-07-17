# Inspirations & Comparative Analysis

LumaEdge is created as the definitive open-source native edge-light utility for macOS. While built from scratch in clean, modern **Swift 6**, **SwiftUI**, and **CoreAnimation/Metal**, LumaEdge draws architectural and concept inspiration from two pioneering open-source projects:

1. **[MacOSEdgeLight](https://github.com/chrisdoc/MacOSEdgeLight)** by @chrisdoc
2. **[GlowEdge](https://github.com/cataWalter/GlowEdge)** by @cataWalter

---

## 1. MacOSEdgeLight

### Overview & Contributions
`MacOSEdgeLight` demonstrated the utility and aesthetic value of turning display borders into soft studio lighting for video calls on macOS. It established core user interaction patterns:
- Using border overlays as a supplemental webcam light source.
- Providing quick toggle accessibility from the macOS menu bar.
- Basic color temperature and brightness adjustments.

### Study & Improvements Made by LumaEdge
While studying `MacOSEdgeLight`, we identified several opportunities for architectural and rendering improvements:
- **Rendering Performance & GPU Efficiency**: Instead of basic view overlays or heavy CPU drawing, LumaEdge utilizes zero-copy `CALayer` hierarchies (`GlowHostLayer`, `BorderGlowLayer`) with hardware-accelerated `smoothstep` Signed Distance Field (`SDF`) gradient calculations and Extended Dynamic Range (`EDR`) headroom. This reduces CPU usage during active calls to `< 1%`.
- **Optical Diffusion & Bloom Control**: LumaEdge replaces flat capsule/rectangle shapes with a 4-layer optical diffuser structure (`Bezel Rim`, `Inner Core Highlight Band`, `Studio Diffuser Body Light`, and `Diffuse Ambient Halo`) with inward linear decay (`100% -> 55% -> 18% -> 0%`), preventing the light from looking stretched or foggy on large displays.
- **Exact Camera Gating**: LumaEdge introduces precise client process inspection (`kCMIODevicePropertyProcessIsRunningSomewhere` probing `prsn` / `0x7072736e` PID data) to distinguish between actual video calls (Zoom, FaceTime, Teams) and background CoreMediaIO daemons or standby virtual cameras (Continuity Camera, OBS).

---

## 2. GlowEdge

### Overview & Contributions
`GlowEdge` explored advanced edge lighting configurations, customizable glow effects, and workflow integration for macOS users, demonstrating how ambient lighting can enhance focus and presentation quality.

### Study & Improvements Made by LumaEdge
- **Virtual Ring Light Mode**: Inspired by directional lighting needs, LumaEdge engineered `.webcamCenter` Virtual Ring Light mode (`startFraction: 0.33, endFraction: 0.67` across the top border) to frame the user's face naturally right below the camera without glaring across the entire screen width.
- **Layered Adaptive UI Avoidance**: To ensure LumaEdge never blocks critical interface elements during work sessions, we built `RegionCarver` and `AXUIInspector`. LumaEdge automatically carves non-illuminated intervals around active window scrollbars, full-screen video bars, and menu headers (`carveSegment()`).
- **Smart Workspace Management**: LumaEdge includes optional window insetting (`SmartWorkspaceManager`) that gently nudges standard application windows (`NSWindow.Level.normal`) inward within the `CGWindowListCopyWindowInfo` safe area, while explicitly respecting system spaces, Stage Manager, and full-screen apps.
- **Zero-Dependency Native Architecture**: LumaEdge contains no web views (`WKWebView`), no Electron, and no Qt bridges. It is purely compiled Swift binary code running sandboxed where possible on macOS 14+ Sonoma and macOS 15 Sequoia.

---

## Code Attribution & Clean-Room Implementation
In accordance with our engineering goals and licensing standards:
- **No code was copied verbatim** from either `MacOSEdgeLight` or `GlowEdge`.
- All modules (`LumaEdgeCore`, `RenderingEngine`, `DisplayManager`, `OverlayManager`, `MenuBar`, `Settings`, `ApplicationProfiles`, `CameraDetection`, `WindowManager`, `AccessibilityManager`, `PluginAPI`, and `LumaEdgeCLI`) were designed and written from scratch using modern Swift concurrency (`@MainActor`, `Sendable`, `DistributedNotificationCenter`).
- Both repository references were studied exclusively for comparative analysis, architecture evaluation, and UX benchmarking.
