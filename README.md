# XeeLite

A fast, minimal image viewer for macOS, inspired by [Xee³](https://theunarchiver.com/xee). Built with SwiftUI and AppKit on top of native ImageIO – no dependencies, no Electron, no nonsense.

Opens an image, discovers everything else in the same folder, and gets out of your way.

---

## Features

### Viewing
- Smooth zoom via scroll wheel, trackpad pinch, or keyboard shortcuts
- Pan with click-and-drag at any zoom level
- Zoom modes: **Fit in Window**, **Fit on Screen** (resizes the window), **Actual Size** (1:1 pixels)
- Double-click the image to toggle between Fit and Actual Size; double-click outside the image to toggle full screen
- **Full screen mode** with auto-hiding status bar and cursor

### Navigation
| Key | Action |
|-----|--------|
| `←` / `→` | Previous / Next image |
| `Space` | Next image |
| `Backspace` | Previous image |
| `Home` / `End` | First / Last image |
| `⌘←` / `⌘→` | Jump back / forward 10 images |

### Animated images
- Plays animated **GIF** and **APNG** with correct per-frame timing
- Status bar controls: play/pause, step backward/forward, playback speed menu (0.25× – 8×)
- Frame counter

### Format support
63 formats including JPEG, PNG, GIF, APNG, TIFF, BMP, WebP, HEIC/HEIF, AVIF, JPEG 2000, OpenEXR, PSD, ICNS, ICO, TGA, NetPBM, and all major RAW camera formats (CR2, CR3, NEF, ARW, DNG, RAF, ORF, RW2, and more).

### Status bar
Displays filename, pixel dimensions, file size, format, folder position (N/M), and current zoom level. Toggle with `⌘/`.

### Metadata inspector
Side panel with EXIF, IPTC, GPS, and XMP metadata grouped into collapsible sections. Click any value to copy it. Toggle with `⌘I`.

### File management
| Action | Key |
|--------|-----|
| Rename | `⌘R` or `Return` |
| Move to Trash | `⌘⌫` (with confirmation) |
| Move to folder slot 1–9 | `1`–`9` |
| Copy to folder slot 1–9 | `⇧1`–`⇧9` |
| Manage destination folders | Transfer → Manage Destinations… |

Transfer destinations are up to 9 configurable folders. Assign them once via **Transfer → Manage Destinations…**, then move or copy the current image to any slot with a single keypress. After a move, the viewer automatically advances to the next image.

---

## Keyboard shortcuts summary

| Shortcut | Action |
|----------|--------|
| `⌘O` | Open image |
| `⌘R` | Rename |
| `⌘⌫` | Move to Trash |
| `⌘F` | Toggle full screen |
| `⌘+` / `⌘-` | Zoom in / out |
| `⌘0` | Fit in Window |
| `⌘1` | Actual Size |
| `⌘/` | Toggle status bar |
| `⌘I` | Toggle metadata inspector |
| `1`–`9` | Move to destination folder |
| `⇧1`–`⇧9` | Copy to destination folder |

---

## Installation

**Download (easiest):** grab `XeeLite.dmg` from the [Releases](../../releases) page, open it, and drag XeeLite into your Applications folder.

## Build and run

**Run in place (development):**
```bash
./scripts/run.sh
./scripts/run.sh /path/to/image.jpg
```

**Build:**
```bash
./scripts/build.sh
```

**Package as `.app`:**
```bash
./scripts/package-app.sh
```

**Package as `.dmg`** (builds the app and wraps it in a disk image):
```bash
./scripts/package-dmg.sh
```

Place an icon at `Resources/icon.png` and it will be baked into the bundle automatically.

The finished app is written to `dist/XeeLite.app` and the disk image to `dist/XeeLite.dmg`.

---

## Planned

### 4.4 – Finder color labels
Set a color label (red, orange, yellow, etc.) on the current file, same as in Finder. Keyboard shortcut per color.

### 5 – Slideshow and advanced viewing
- **Slideshow** – auto-advance with configurable interval, transitions (fade/slide), full screen mode
- **Crop** – interactive rectangular selection, fixed aspect ratios, save cropped result
- **Color correction** – non-destructive brightness/contrast/gamma/saturation sliders via Core Image

### 6 – Thumbnails and browsing
- **Thumbnail strip** – horizontal filmstrip of the current folder, lazily loaded
- **Folder browser** – separate grid view of all images in the folder, sortable by name/date/size
- **Tabs** – multiple folders/images in one window using native macOS tabs

### 7 – Export and system integration
- **Export / Convert** – Save As with format selection (JPEG, PNG, TIFF, HEIC, WebP), quality control, optional resize
- **Print** – `⌘P` with fit/fill options and print preview
- **Clipboard** – `⌘C` to copy the current image, `⌘V` to open from clipboard; drag & drop into the window
- **Set as Desktop Picture** – one menu item, current screen
- **File system watcher** – auto-refresh the folder list when files are added or removed

### 8 – Themes and preferences
- **Background themes** – black, dark, light, or automatic (follows system appearance)
- **Preferences window** (`⌘,`) – zoom behavior on open, slideshow interval, keyboard shortcut customization

### 9 – Archive support
Browse images inside ZIP, RAR, 7z, and TAR archives without extracting them. Password-protected archives supported.

---

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon or Intel
