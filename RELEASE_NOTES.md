### Welcome to Swip 1.0.0

Swip is a zero-click, local-first drag-and-drop utility for macOS. It turns everyday media conversions and editing tasks into a physical reflex using an 8-petal radial HUD.

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
