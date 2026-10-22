# Swip

> **Zero-click, local-first drag-and-drop Swiss Army knife for macOS.**  
> 275+ offline file conversions &bull; 26 pro media tools &bull; 100% private.

[![macOS 14.0+](https://img.shields.io/badge/macOS-14.0%2B%20Sonoma%20%2F%20Sequoia-black?style=flat-square&logo=apple)](https://github.com/Woadlab/swip)
[![Swift 5](https://img.shields.io/badge/Swift-5.10%2B-F05138?style=flat-square&logo=swift&logoColor=white)](https://github.com/Woadlab/swip)
[![Architecture](https://img.shields.io/badge/Architecture-Apple%20Silicon%20%2F%20Intel-blue?style=flat-square)](https://github.com/Woadlab/swip)
[![Privacy](https://img.shields.io/badge/Privacy-100%25%20Offline-707BF5?style=flat-square)](https://github.com/Woadlab/swip)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

---

Converting an image to WebP, trimming a video clip, normalizing audio loudness, or stripping GPS coordinates from photos shouldn't require opening a browser, uploading private files to third-party cloud servers, or wrestling with bloated multi-gigabyte suites.

**Swip** turns everyday media tasks into a physical reflex on macOS. Pick up any file from Finder, hold a modifier key, and drop it onto an 8-petal radial HUD. The converted file or processed asset appears instantly right next to the original.

---

## Installation

### Method 1: One-Line Installer (cURL)

Install Swip directly to `/Applications` with a single terminal command:

```bash
curl -fsSL https://raw.githubusercontent.com/Woadlab/swip/main/install.sh | bash
```

### Method 2: Direct Download (DMG)

Download the pre-compiled disk image from GitHub Releases:

👉 **[Download Latest Swip (DMG)](https://github.com/Woadlab/swip/releases/latest)** *(or [Swip.zip](https://github.com/Woadlab/swip/releases/latest))*

1. Open `Swip.dmg` and drag `Swip` to your `/Applications` shortcut.
2. Launch `Swip` from Spotlight or Launchpad.

> *First launch note: If macOS Gatekeeper displays an unverified developer prompt, right-click (Control-click) `Swip.app` &rarr; **Open**, or click **Open Anyway** under System Settings &rarr; Privacy & Security.*

### Method 3: Homebrew Cask

```bash
brew tap woadlab/tap
brew install --cask swip
```

### Method 4: Build from Source

```bash
git clone https://github.com/Woadlab/swip.git
cd swip
./build.sh
```
The compiled bundle will be generated at `dist/Swip.app`.

---

## How It Works

Swip runs as a lightweight, non-activating status bar utility that monitors global drag gestures and modifier keys with zero background CPU overhead:

| Gesture | Mode | Description |
| :--- | :--- | :--- |
| **`⇧ Shift` + Drag** | **Instant Convert** | Spawns an 8-petal radial wheel tailored to the dragged file's type (e.g. dragging a `.heic` presents WebP, PNG, JPEG, AVIF, TIFF, PDF). Release over a petal to convert. |
| **`⌘ Command` + Drag** | **Pro Tools** | Opens fast utility tools for the target file (Lossless Trim, Redaction brush, Canvas framing, Loudness normalizer, PDF joiner). |
| **`⌃ Control` + Drag** | **File Actions** | Quick triage operations: Reveal in Finder, Quick Look preview, Move to Trash, or pin to the Floating Shelf. |
| **Drop on Menu Bar** | **Queue & Batch** | Stashes items into the batch processing queue for bulk format transformations. |

> *Tip: You can press the modifier either **before** dragging or **while actively dragging** a file.*

---

## Key Features

- **100% Local & Private**: Every conversion and tool runs entirely on your Mac. Zero network requests, zero telemetry, zero analytics, zero data harvesting.
- **Physical Gesture HUD**: A non-activating floating radial panel appears under your cursor when dragging files. Releasing the file triggers the action immediately without stealing window focus.
- **275+ Offline Conversion Pairs**: Instant transcoding across raster graphics, vectors, video containers, lossless audio, documents, archives, and subtitle formats.
- **26 Pro Media Tools**: Complete offline toolset for trimming, cropping, frame extraction, canvas framing, redaction, loudness normalization, PDF manipulation, and deep metadata editing.
- **Hardware Accelerated**: Native Swift 5 pipeline backed by Apple Silicon Accelerate, `vImage`, `ImageIO`, `AVFoundation`, `CoreGraphics`, and embedded `FFmpeg`.
- **Swip Studio & Floating Shelf**: Dedicated utility window for batch processing, format inspection, and an edge-docked shelf for staging files across multi-monitor setups.
- **Calibrated macOS Aesthetic**: Frosted glass HUD with dynamic theme accents (Pastel Indigo default, Pastel Mint, Pastel Rose, or System Accent).

---

## Conversions Matrix

Swip provides direct, offline format transformations across 275+ format pairs:

### 🖼️ Images
`PNG` &bull; `JPEG` &bull; `WebP` &bull; `AVIF` &bull; `HEIC` &bull; `TIFF` &bull; `BMP` &bull; `GIF` &bull; `SVG` &bull; `ICNS` &bull; `ICO` &bull; `PDF`

- High-precision lossless and lossy compression engines
- Lossless WebP encoding with transparent alpha channel preservation
- Direct ICNS iconset bundle packing via Apple `iconutil` specs
- Batch rasterization of vector SVG to Retina PNGs

### 🎬 Video
`MP4 (H.264 / HEVC)` &bull; `MOV (ProRes / H.264)` &bull; `WebM (VP9 / AV1)` &bull; `MKV` &bull; `AVI` &bull; `Animated GIF` &bull; `MP3 / M4A Extraction`

- Native `AVAssetExportSession` hardware acceleration for Apple Silicon media engines
- Zero-re-encoding stream copy for lossless format repackaging
- High-quality palette generation for GIF animations

### 🎵 Audio
`MP3` &bull; `WAV (PCM)` &bull; `AAC` &bull; `M4A` &bull; `FLAC` &bull; `OGG (Vorbis)` &bull; `AIFF` &bull; `CAF`

- Sample-rate conversion, bit-depth dithering, and multi-channel mixdown
- High-efficiency AAC encoding for podcasting and distribution

### 📄 Documents & Subtitles
- **Documents**: `PDF` &bull; `TXT` &bull; `RTF` &bull; `HTML` &bull; `DOCX` &bull; `Markdown` &bull; `CSV` &bull; `JSON` &bull; `YAML`
- **Subtitles**: `SRT` &bull; `VTT` &bull; `ASS` &bull; `SSA` &bull; `TTML`
- **Archives**: `ZIP` &bull; `TAR` &bull; `GZ` &bull; `BZ2` &bull; `XZ` &bull; `7Z`

---

## The 26 Pro Tools

When holding `⌘ Command` while dragging, Swip opens dedicated, non-modal workstations:

```
├── 🖼️ Image Tools
│   ├── Resize & Scale        Linear, lanczos, and aspect-ratio locked resizing
│   ├── Smart Crop            Preset aspect ratios (16:9, 4:3, 1:1, 9:16) and freeform crop
│   ├── Rotate & Flip         Lossless 90° rotation and horizontal/vertical flipping
│   ├── Frame & Mockup        Add macOS window titlebars, dropshadows, and custom padding
│   ├── Redact                Gaussian blur and pixelation brush for sensitive data
│   ├── Visual Adjustments    Exposure, contrast, saturation, vibrancy, and sharpen filters
│   ├── Collage Maker         Grid layouts with configurable gutters and background fills
│   └── Export to PDF         Multi-image document compilation with page sizing
│
├── 🎬 Video Tools
│   ├── Lossless Trim         Frame-accurate start/end trimming without quality loss
│   ├── Segment Splitter      Divide videos into equal duration segments or chapter markers
│   ├── Canvas Crop           Re-frame videos for vertical social reels or widescreen
│   ├── Speed Ramp            0.25x slow motion up to 4x fast forward with audio pitch correction
│   ├── Multi-Clip Joiner     Concatenate multiple clips with matching codecs
│   ├── Snapshot Extraction   Export full-resolution PNG stills from video frames
│   └── Video Redaction       Track and obscure static or moving screen regions
│
├── 🎵 Audio Tools
│   ├── Audio Trim            Millisecond-precise waveform trimming
│   ├── Speed Adjust          Time-stretch audio without altering pitch
│   ├── Volume Gain           Boost quiet recordings with soft-knee limiting
│   ├── Loudness Normalizer   EBU R128 broadcast-standard normalization (-14 to -23 LUFS)
│   └── Track Joiner          Stitch audio stems or podcast segments
│
├── 📑 PDF Tools
│   ├── Merge Documents       Combine multiple PDFs into a single file
│   ├── Split Pages           Burst PDF pages into standalone documents
│   ├── Extract Range         Select custom page ranges (1-3, 5, 8-10)
│   ├── Visual Reorder        Drag-and-drop page thumbnail arrangement
│   ├── Stream Compression    Reduce PDF file size while maintaining text vector sharpness
│   └── Watermarking          Overlay custom copyright text or image stamps
│
└── 📦 File & Security Tools
    ├── Deep Metadata View    Inspect EXIF, GPS coordinates, camera specs, IPTC, and XMP tags
    ├── Metadata Stripper     Sanitize private location, device serials, and author info
    └── Archive Compressor    High-ratio LZMA2 and Zstandard compression
```

---

## Architecture

```
Sources/
├── App/          # Application lifecycle, AppSettings, FloatingShelfController
├── Core/         # JobRunner, MediaInfo, SoundManager, DiagnosticLog, Shell execution
├── Engines/      # Hardware conversion engines (ImageEngine, VideoEngine, AVExporter, FFmpeg)
├── Formats/      # FileFormat definitions, UTI mapping, ConversionMatrix
├── Operations/   # High-level operations for Image, Video, Audio, PDF, Compressor, Metadata
├── Radial/       # Non-activating NSPanel HUD, RadialGeometry bezier layout, DragMonitor
├── Tools/        # 26 SwiftUI tool views (Shared MediaPlayer, ImageCanvas, ToolWindowManager)
└── UI/           # SwipStudioView, GlassSurface, Theme tokens, BrandArtwork vector mark
```

- **Zero Focus Theft**: Built using an `NSPanel` with `.nonactivatingPanel` and custom window levels, ensuring that dragging never steals focus from Finder, Xcode, Photoshop, or your browser.
- **Pure Swift Engine**: Written in modern Swift 5 and SwiftUI with zero runtime third-party dependencies.

---

## Contributing

Contributions, feature requests, and bug reports are welcome. Please open an issue or submit a pull request on [GitHub](https://github.com/Woadlab/swip).

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'feat: add new capability'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

---

## License

Swip is licensed under the [MIT License](LICENSE).

<p align="center">
  Crafted with intention by <a href="https://github.com/Woadlab"><strong>Woadlab</strong></a>.
</p>
