# LumaEdge 💡✨

**The definitive open-source edge lighting and virtual ring light utility for macOS.**  
Designed from the ground up for Apple Silicon and macOS 14+ Sonoma / macOS 15 Sequoia, LumaEdge transforms the perimeter of your displays into a soft, diffused, professional studio light source during video calls.

---

## Why LumaEdge?

Unlike basic overlays or web-based/Electron/Qt utilities that consume heavy CPU resources or block display interactions, LumaEdge is built purely in **modern Swift 6**, **SwiftUI**, and **CoreAnimation/Metal**. It feels and operates like a first-party tool built directly into macOS:

- **GPU-Accelerated & 120Hz ProMotion Ready**: Uses zero-copy `CALayer` hierarchies (`GlowHostLayer`, `BorderGlowLayer`) with `smoothstep` Signed Distance Field (`SDF`) gradients and HDR rendering (`EDR` headroom). Runs at `< 1% CPU` and negligible memory footprint during active calls.
- **Click-Through & Non-Blocking**: Windows sit perfectly above your applications (`NSWindow.Level.statusBar + 1`) while remaining `100% click-through` (`ignoresMouseEvents = true`).
- **Optical Glass Diffusion & Bloom Control**: Features layered, directional inward linear decay (`100% -> 55% -> 18% -> 0%`), razor-sharp bezel rim anchoring (`0.12x` scale core), and tight smoothstep end feathering (`~3.5%` span) so the studio light looks like optical diffuser glass rather than a stretched, foggy smear.
- **Global Border Width / Thickness Adjustment**: Easily adjust border thickness from `16px` up to `400px` via menu bar slider, `Settings -> Edges`, CLI (`lumaedge width 180`), or deep links (`lumaedge://width?px=180`).
- **Virtual Ring Light Mode (`Center 50%`)**: Need directional illumination for webcam calls without lighting up your entire screen? Enable the Virtual Ring Light anchored to your top center webcam (`34%` centered width for authentic studio bar proportions) or corners.
- **Camera-Gated Lighting**: Uses `AVCaptureDevice.isInUseByAnotherApplication` with CoreMediaIO's documented `kCMIODevicePropertyDeviceIsRunningSomewhere` fallback to show the light only while a video device is performing I/O.
- **Layered Adaptive UI Avoidance**: Never obscures active scrollbars, menu titles, or full-screen video (`RegionCarver` + `AXUIInspector` multi-layer avoidance strategy).
- **Circadian & Battery Saver Automation**: Automatically shifts color temperature from crisp `5600K` daylight at noon down to a warm amber `2700K` glow at night (`TimeOfDayPlugin`), while automatically dimming on battery power (`AdaptiveBrightnessPlugin`) to conserve MacBook energy.
- **Automation CLI & Deep Links**: Fully scriptable via the `lumaedge` terminal command (`lumaedge preset sunset`) and deep links (`lumaedge://toggle`).

---

## Inspirations & Clean-Room Implementation

LumaEdge was inspired by and built to improve upon two pioneering open-source projects:
1. **[MacOSEdgeLight](https://github.com/chrisdoc/MacOSEdgeLight)** by @chrisdoc
2. **[GlowEdge](https://github.com/cataWalter/GlowEdge)** by @cataWalter

While studying their architectural choices, monitor management, and UX patterns, **LumaEdge was built 100% from scratch without copying any code verbatim**. We eliminated heavy CPU draw cycles, replaced flat capsule rendering with 4-layer optical glass diffusion, added precise client PID camera gating, and implemented zero-network local IPC (`DistributedNotificationCenter`).

For a detailed breakdown of architectural comparison and credits, see [`INSPIRATIONS.md`](INSPIRATIONS.md).

---

## Installation & Quick Start

### Option 1: Build & Launch locally via Swift Package Manager
1. Clone this repository:
   ```bash
   git clone https://github.com/aditya/LumaEdge.git
   cd LumaEdge
   ```
2. Build a fresh signed app bundle:
   ```bash
   ./Scripts/build-app.sh
   ```
3. Launch it:
   ```bash
   open build/LumaEdge.app
   ```

For an iterative development run without creating an app bundle, use `swift run LumaEdgeApp`.

---

## Architecture & Module Overview

LumaEdge is organized into cleanly isolated Swift Package modules:

| Module | Responsibility |
| :--- | :--- |
| **`LumaEdgeCore`** | Core data models (`GlowPreset`, `EdgeSegment`), `LightingEngine` master state, exact Kelvin-to-RGB color science. |
| **`RenderingEngine`** | High-performance `CoreAnimation` / `CALayer` hierarchy, `smoothstep` gradient rendering, HDR (`EDR`) headroom support, 4-layer optical diffuser engine (`CanvasEdgeView`). |
| **`DisplayManager`** | Multi-monitor orchestration, display hot-plugging (`CGDisplayRegisterReconfigurationCallback`), notch & safe area calculations. |
| **`OverlayManager`** | Invisible border `NSWindow` management (`.canJoinAllSpaces`, `.ignoresMouseEvents`), space transitions. |
| **`MenuBar`** | Native SwiftUI `MenuBarExtra` accessory item, quick toggle, Brightness / Width (`Thickness`) sliders, instant preset picker. |
| **`Settings`** | Comprehensive preferences UI across General, Edges & Ring Light, Profiles & Automation, Smart Workspace, and Plugins. |
| **`ApplicationProfiles`** | App focus monitoring (`NSWorkspace.didActivateApplicationNotification`), automatic profile switching (e.g., *Zoom -> Daylight*). |
| **`CameraDetection`** | Hardware active camera/microphone monitoring (`AVCaptureDevice` plus CoreMediaIO video-I/O state). |
| **`WindowManager`** | Optional `SmartWorkspaceManager` window insetting (`CGWindowListCopyWindowInfo`, `AXUIElement`). |
| **`AccessibilityManager`** | `RegionCarver` & `AXUIInspector` multi-layer avoidance strategy. Carves edge intervals around window scrollbars/toolbars. |
| **`PluginAPI`** | Automation plugin registry (`TimeOfDayPlugin`, `AdaptiveBrightnessPlugin`), local `DistributedNotificationCenter` IPC. |
| **`LumaEdgeCLI`** | Command-line utility (`lumaedge toggle | on | off | preset <id> | brightness <val> | width <px> | kelvin <val>`). |

For full system diagrams and technical specifications, see [`ARCHITECTURE.md`](ARCHITECTURE.md).

---

## Command Line & Deep Link Reference

### `lumaedge` CLI
```bash
lumaedge toggle                  # Toggles master light on/off
lumaedge on                      # Turns edge light master switch ON
lumaedge off                     # Turns edge light master switch OFF
lumaedge preset daylight         # Applies a built-in or custom preset (`studio_white`, `daylight`, `sunset`, `ring_light`)
lumaedge brightness 0.8          # Sets overall brightness (0.0 to 1.0)
lumaedge width 180               # Sets border thickness in pixels (16 to 400)
lumaedge kelvin 3200             # Sets color temperature in Kelvin (2000K to 10000K)
lumaedge status                  # Lists available presets
```

### Deep Links (`lumaedge://`)
Use `lumaedge://` URLs inside Apple Shortcuts, Raycast, Alfred, or browser automations:
- `lumaedge://toggle`
- `lumaedge://on`
- `lumaedge://off`
- `lumaedge://preset?id=studio_white`
- `lumaedge://brightness?value=0.75`
- `lumaedge://width?px=180`
- `lumaedge://kelvin?value=4200`

---

## Testing & Verification

LumaEdge includes a 22-test automated suite across all 5 phases verifying domain models, lighting state, safe area math, interval avoidance, and IPC handling.

To run the full unit test suite:
```bash
swift test --parallel
```

---

## Contributing & License

We welcome contributions! Please review [`CONTRIBUTING.md`](CONTRIBUTING.md) for coding standards and PR workflows.

Licensed under the [MIT License](LICENSE).
