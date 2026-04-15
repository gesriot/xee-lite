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
- **Full screen mode** with auto-hiding chrome and cursor

### Navigation
| Key | Action |
|-----|--------|
| `←` / `→` | Previous / Next image |
| `Space` | Next image |
| `Backspace` | Previous image |
| `Home` / `End` | First / Last image |
| `⌘←` / `⌘→` | Jump back / forward 10 images |

### Tabs and multiple windows
- Native macOS window tabs – `⌘T` opens a new tab in the same window
- Each tab has its own fully independent state: current folder, zoom, slideshow, crop, and color adjustments
- Standard tab bar and shortcuts (`⌃⇥` to cycle, drag tabs between windows)

### Folder browser
- Separate grid window (`⌘B`) showing every image in the current folder as a large thumbnail
- Sort by **Name**, **Date Modified**, or **File Size**
- Filter by format (JPEG, PNG, RAW, etc.) based on what's actually in the folder
- Double-click any cell to load that image into the active viewer tab and bring it to the front
- Thumbnails loaded lazily and cached so scrolling stays smooth on large folders

### Thumbnail strip
- Horizontal filmstrip along the bottom of the viewer showing all images in the folder
- Click to jump directly to any image; the strip auto-scrolls to keep the current image centered
- Toggle with `⌥⌘T`; auto-hides during slideshow and crop

### Slideshow
- Auto-advance with configurable interval (1.5s to 12s)
- **Fade** or **slide** transitions
- Enters full screen and fits the image on screen automatically
- Previous/next slide with arrow keys; exiting full screen pauses playback
- Toggle with `⌘⌥S`

### Crop
- Interactive rectangular selection with draggable handles
- Aspect ratio presets: **Freeform**, **Square**, **4:3**, **16:9**
- Live selection size readout in the status bar
- **Save** (`⌘S`) overwrites the original in place (atomic write via temp file + replace)
- **Save As…** (`⇧⌘S`) writes a new file via the system save panel
- Toggle with `⌘K`; `Esc` cancels
- Preserves the source image's color space when possible (direct CGImage path with bitmap fallback)

### Color adjustments
- Floating panel with sliders for **Brightness**, **Contrast**, and **Gamma**
- Non-destructive live preview via Core Image (`CIColorControls` + `CIGammaAdjust`)
- Works on animated GIF / APNG too – the adjustment follows the currently displayed frame
- Toggle with `⌘⌥C`; `Esc` closes the panel

### Animated images
- Plays animated **GIF** and **APNG** with correct per-frame timing
- Status bar controls: play/pause, step backward/forward, playback speed menu (0.25× – 8×)
- Frame counter

### Format support
63 formats including JPEG, PNG, GIF, APNG, TIFF, BMP, WebP, HEIC/HEIF, AVIF, JPEG 2000, OpenEXR, PSD, ICNS, ICO, TGA, NetPBM, and all major RAW camera formats (CR2, CR3, NEF, ARW, DNG, RAF, ORF, RW2, and more).

### Status bar
Displays filename, pixel dimensions, file size, format, folder position (N/M), and current zoom level. Also hosts slideshow, animation, and crop controls when those modes are active. Toggle with `⌘/`.

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
| Set Finder color label (none / red / orange / yellow / green / blue / purple / grey) | `⌘⌥0` – `⌘⌥7` |

Transfer destinations are up to 9 configurable folders. Assign them once via **Transfer → Manage Destinations…**, then move or copy the current image to any slot with a single keypress. After a move, the viewer automatically advances to the next image.

---

## Keyboard shortcuts summary

| Shortcut | Action |
|----------|--------|
| `⌘O` | Open image |
| `⌘T` | New tab |
| `⌘B` | Show folder browser |
| `⌘R` | Rename |
| `⌘⌫` | Move to Trash |
| `⌘F` | Toggle full screen |
| `⌘+` / `⌘-` | Zoom in / out |
| `⌘0` | Fit in Window |
| `⌘1` | Actual Size |
| `⌘/` | Toggle status bar |
| `⌘I` | Toggle metadata inspector |
| `⌥⌘T` | Toggle thumbnail strip |
| `⌘⌥S` | Toggle slideshow |
| `⌘K` | Crop |
| `⌘S` / `⇧⌘S` | Save crop / Save crop as… |
| `⌘⌥C` | Toggle color adjustments |
| `⌘⌥0` – `⌘⌥7` | Set Finder color label |
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

### Export and system integration
- [ ] Export / Convert – Save As with format selection (JPEG, PNG, TIFF, HEIC, WebP), quality control, optional resize
- [ ] Print – `⌘P` with fit/fill options and print preview
- [ ] Clipboard – `⌘C` to copy the current image, `⌘V` to open from clipboard; drag & drop into the window
- [ ] Set as Desktop Picture – one menu item, current screen
- [ ] File system watcher – auto-refresh the folder list when files are added or removed

### Themes and preferences
- [ ] Background themes – black, dark, light, or automatic (follows system appearance)
- [ ] Preferences window (`⌘,`) – zoom behavior on open, slideshow interval, keyboard shortcut customization

### Archive support
- [ ] Browse images inside ZIP, RAR, 7z, and TAR archives without extracting them; password-protected archives supported

---

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon or Intel
