### Swip 1.1.0 — Menu Bar Panel, Single Instance & Studio Refinements

This release replaces the menu bar's plain menu with a dedicated panel that shows live job state, guarantees a single running copy of Swip per session, and refines Swip Studio and the media tools.

### ✨ What's New

- **Menu Bar Panel**: Clicking the menu bar icon opens a compact, non-activating panel anchored under the status item, replacing the stock menu. It offers Studio, Settings, convert, tools, file actions, the shelf, logs and quit, and shows live job state. Every action dismisses the panel first, like a real menu.
- **Single Instance Guard**: Only one Swip runs per session, even if an installed copy and a development build are both launched (for example as login items). An installed copy in `/Applications` takes precedence over a development build; otherwise the older process wins. The other instance quits automatically.
- **Refined Swip Studio**: Reworked layout and controls in Swip Studio, plus updated image, audio and video tool views.

### 🐛 Fixes & Refinements

- **Open at Login**: The "Open at login" setting is available only in an installed copy, so a development build can't register itself as a login item.
- **Smaller Fixes**: Minor corrections in the export engine, the shared media player and theme tokens.

---

### Swip 1.0.2 — Cardinal Muscle Memory, Menu Bar Status & Native Polish

This update introduces fixed cardinal petal positioning for rock-solid muscle memory, live animated conversion status in the macOS menu bar, and verified 100% native Apple Silicon hardware acceleration.

### ✨ What's New

- **Cardinal Muscle Memory**: Format petals now adhere to deterministic compass positions across all media categories. Dragging an image reliably places WebP at North, PNG at North-East, JPG at East, and PDF at South-East, completely preventing index shifting across different input formats.
- **Live Menu Bar Conversion Status**: Long-running background conversions now display a discreet, non-intrusive status in the macOS menu bar:
  - An animated notice appears upon starting, smoothly retracting to a minimal icon.
  - The Swip icon spins smoothly with a fixed center during active processing.
  - Morphs into a success checkmark (`checkmark.circle.fill`) for 2 seconds on completion before restoring the standard icon.
- **100% Native Architecture & Pure MIT**: Confirmed zero bundled GPL/FFmpeg binary bloat. All standard conversions leverage Apple Silicon hardware acceleration (`vImage`, `ImageIO`, `AVFoundation`, `CoreGraphics`, `PDFKit`), maintaining an ultra-lightweight 2.8 MB footprint.
- **Refined Assets & Documentation**: Added photorealistic macOS desktop demonstrations and updated technical specifications.

---

### 🐛 Bug Fixes & Refinements (from 1.0.1)

- **Finder List & Column View Drag Alignment**: Corrected radial HUD origin synchronization when initiating drags from file name labels.
- **Status Bar Drag Isolation**: Prevented accidental radial activations during menu bar icon rearrangement (`⌘ + Drag`) and system gestures.

---

### ✨ Highlights

- **8-Petal Radial HUD**: Hold a modifier key and drag any file to summon the radial menu under your cursor without stealing window focus (`.nonactivatingPanel`).
  - `⇧ Shift + Drag`: 275+ offline format conversions (Images, Video, Audio, Documents, Archives).
  - `⌘ Command + Drag`: 26 pro media tools (Lossless Trim, Redaction brush, Canvas framing, Loudness normalization, PDF merge/split, Metadata scrubbing).
  - `⌃ Control + Drag`: Quick actions (Reveal, Quick Look, Trash, Stash to Shelf).
- **100% Local & Private**: Runs entirely offline on your Mac. Zero network requests, zero telemetry, zero cloud dependencies.
- **Hardware Accelerated & 100% Native**: Built on Apple Silicon Accelerate, `vImage`, `ImageIO`, `AVFoundation`, and `CoreGraphics` for sub-second offline processing, with seamless integration for system FFmpeg when available.
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
