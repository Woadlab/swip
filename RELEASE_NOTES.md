### Swip 1.0.1 — Radial Drag Alignment & Menu Bar Isolation

This update resolves critical cursor tracking issues during Finder drag gestures and eliminates false radial HUD triggers when interacting with macOS system status items.

### 🐛 Bug Fixes & Improvements

- **Finder List & Column View Drag Alignment**: Fixed an issue where dragging files starting from the tail of their name in Finder list or column view caused the radial wheel to appear misaligned visually while hit-testing operated at the drag start. `RadialView` and `RadialController` now dynamically synchronize `host.frame` with the cursor position on every drag.
- **Menu Bar & System Interaction Isolation**: Excluded the macOS status bar area (`pressOrigin.y >= screen.visibleFrame.maxY`) and eliminated false-positive drag activations when rearranging menu bar items (`⌘ Command + Drag`), moving background windows, or selecting text.
- **Strict Drag Session Verification**: The radial engine now strictly requires an active, newly initiated file drag session (`changeCount > pressChangeCount`) with verified file URLs before activating.

---

### ✨ Highlights

- **8-Petal Radial HUD**: Hold a modifier key and drag any file to summon the radial menu under your cursor without stealing window focus (`.nonactivatingPanel`).
  - `⇧ Shift + Drag`: 275+ offline format conversions (Images, Video, Audio, Documents, Archives).
  - `⌘ Command + Drag`: 26 pro media tools (Lossless Trim, Redaction brush, Canvas framing, Loudness normalization, PDF merge/split, Metadata scrubbing).
  - `⌃ Control + Drag`: Quick actions (Reveal, Quick Look, Trash, Stash to Shelf).
- **100% Local & Private**: Runs entirely offline on your Mac. Zero network requests, zero telemetry, zero cloud dependencies.
- **Hardware Accelerated**: Native Swift 5 / SwiftUI pipeline backed by `vImage`, `ImageIO`, `AVFoundation`, `CoreGraphics`, and embedded `FFmpeg`.
- **Swip Studio & Floating Shelf**: Dedicated utility window for batch conversions, format inspection, and an edge-docked shelf for staging files.

---

### 📦 Installation

#### Option 1: Quick Install (Terminal)
```bash
curl -fsSL https://raw.githubusercontent.com/Woadlab/swip/main/install.sh | bash
```

#### Option 2: Disk Image (DMG) — Recommended
Download **`Swip.dmg`** from the Assets below, open it, and drag `Swip` to your Applications folder.

#### Option 3: Standalone Archive (ZIP)
Download **`Swip.zip`** from the Assets below and unzip it into `/Applications`.

---

> **Note for first launch**: If macOS Gatekeeper asks for confirmation, right-click (Control-click) `Swip.app` &rarr; **Open**, or allow it under *System Settings &rarr; Privacy & Security*.
