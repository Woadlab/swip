### Swip 1.1.1 — New Icon & Installer

A fresh identity and a proper installer, on top of everything new in 1.1.0.

- **New App Icon**: The mark is now the 8-petal radial wheel itself, frozen mid-gesture, with the selected petal popping outward just like in the HUD. It follows the macOS icon grid, and the menu bar icon and the menu bar panel use the same shape.
- **Redesigned Installer**: The DMG opens to a designed window: drag Swip onto Applications, guided by an arrow and the wheel around the app icon.

---

### Swip 1.1.0 — Menu Bar Panel, Single Instance & Studio Refinements

This release replaces the menu bar's plain menu with a dedicated panel that shows live job state, guarantees a single running copy of Swip per session, and refines Swip Studio and the media tools.

### ✨ What's New

- **Menu Bar Panel**: Clicking the menu bar icon opens a compact, non-activating panel anchored under the status item, replacing the stock menu. It offers Studio, Settings, convert, tools, file actions, the shelf, logs and quit, and shows live job state. Every action dismisses the panel first, like a real menu.
- **Single Instance Guard**: Only one Swip runs per session, even if an installed copy and a development build are both launched (for example as login items). An installed copy in `/Applications` takes precedence over a development build; otherwise the older process wins. The other instance quits automatically.
- **Refined Swip Studio**: Reworked layout and controls in Swip Studio, plus updated image, audio and video tool views.

### 🐛 Fixes & Refinements

- **Open at Login**: The "Open at login" setting is available only in an installed copy, so a development build can't register itself as a login item.
- **Smoother Updates**: The one-line installer now quits a running Swip before replacing it, and installs to `~/Applications` when `/Applications` is not writable.
- **Smaller Fixes**: Minor corrections in the export engine, the shared media player and theme tokens.

---

### ✨ Highlights

- **8-Petal Radial HUD**: Hold a modifier key and drag any file to summon the radial menu under your cursor without stealing window focus.
  - `⇧ Shift + Drag`: 275+ offline format conversions (Images, Video, Audio, Documents, Archives).
  - `⌘ Command + Drag`: 26 pro media tools (Lossless Trim, Redaction brush, Canvas framing, Loudness normalization, PDF merge/split, Metadata scrubbing).
  - `⌃ Control + Drag`: Quick actions (Reveal, Quick Look, Trash, Stash to Shelf).
- **100% Local & Private**: Runs entirely offline on your Mac. Zero network requests, zero telemetry, zero cloud dependencies.
- **Hardware Accelerated & Native**: Built on Apple Silicon Accelerate, `vImage`, `ImageIO`, `AVFoundation` and `CoreGraphics`, with seamless use of system FFmpeg when available.
- **Swip Studio & Floating Shelf**: A utility window for batch conversions and format inspection, plus an edge-docked shelf for staging files.

---

### 📦 Installation

Requires macOS 14 (Sonoma) or later.

#### Option 1: Quick Install (Terminal) — Recommended
```bash
curl -fsSL https://raw.githubusercontent.com/Woadlab/swip/main/install.sh | bash
```
Installs the latest release to `/Applications` and launches it. Running it again updates Swip.

#### Option 2: Disk Image (DMG)
Download **`Swip.dmg`** from the Assets below, open it, and drag `Swip` to your Applications folder.

#### Option 3: Standalone Archive (ZIP)
Download **`Swip.zip`** from the Assets below and unzip it into `/Applications`.

---

> **First launch with the DMG or ZIP**: Swip is not notarized yet, so macOS may block the first launch. Open *System Settings &rarr; Privacy & Security* and click **Open Anyway** next to the Swip message (on macOS 14 you can also Control-click `Swip.app` &rarr; **Open**). Quit any older Swip before replacing it.
