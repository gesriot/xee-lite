# XeeLite

A fast, minimal image viewer for macOS, inspired by [Xee³](https://theunarchiver.com/xee). Built with SwiftUI and AppKit on top of native ImageIO – no dependencies, no Electron, no nonsense.

Opens an image or archive, discovers everything else in the same folder, and gets out of your way.

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

### Archive browsing
- Open **ZIP, RAR, 7z, TAR** and related bundles (`.cbz`, `.cbr`, `.cb7`, `.cbt`, `.tar.gz`, `.tar.bz2`, `.tar.xz`, `.tgz`, `.tbz`, `.tbz2`, `.txz`) and page through images inside just like a folder
- Password-protected archives prompt for a passphrase and retry on incorrect input
- Extracted contents live in a temporary scratch directory that is wiped on close and swept on next launch after a crash or force-quit
- Built on top of the system `bsdtar` / libarchive – no bundled dependencies
- Archive mode disables file mutations (rename, trash, move/copy, Finder labels, crop-over-source, set-as-desktop) since the source is read-only

### Export and conversion
- **Export…** (`⇧⌘E`) saves the current image in another format
- Targets: JPEG, PNG, TIFF, HEIC, WebP
- Lossy-format quality slider and optional pixel-dimension resize
- Writes via `CGImageDestination` and the system save panel

### Print
- **Print…** (`⌘P`) with **Fit entire image** or **Fill entire page** scaling
- Standard macOS print panel and preview

### Clipboard and drag & drop
- `⌘C` copies the current image to the system pasteboard (archive entries supported)
- `⌘V` opens an image from the clipboard – a temporary file is created in a dedicated scratch directory and loaded into the active viewer
- Drop any supported image file (or a folder of images) onto the viewer window to open it
- Clipboard-sourced images are exempt from **Set as Desktop Picture** because the OS would clean them up underneath the desktop

### Set as Desktop Picture
- Single menu item assigns the current image as the wallpaper for the active screen
- Preserves the existing scaling/fill option so your current desktop layout isn't disturbed

### Folder watching
- The viewer watches the current folder and current file via `DispatchSourceFileSystemObject`
- Adds, removes, renames, and in-place edits refresh the folder listing and thumbnails automatically
- Renames preserve identity through `fileResourceIdentifierKey`, so the viewer keeps tracking the same image after the filename changes

### Appearance
- Themes: **Automatic**, **Light**, **Dark**, **Black** (pure-black background for OLED / cinematic viewing)
- Applies to the viewer, folder browser, and preferences window via a shared palette
- Auto mode follows the system appearance in real time
- Switch from the **Appearance** menu or from Preferences

### Preferences (`⌘,`)
Native macOS Settings scene with sections for:
- **Appearance** – theme selection
- **Viewing** – zoom behavior when opening a new image (remember current, fit in window, fit on screen, actual size)
- **Transfer Destinations** – configure the nine move/copy slots
- **Slideshow** – default interval and transition style; changes apply to running viewer windows on the next start / pause cycle
- **Keyboard Shortcuts** – full reference list

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
| `⌘O` | Open image or archive |
| `⌘T` | New tab |
| `⌘W` | Close tab / window |
| `⌘,` | Open Preferences |
| `⌘B` | Show folder browser |
| `⌘C` / `⌘V` | Copy image / Open from clipboard |
| `⌘P` | Print |
| `⇧⌘E` | Export as another format |
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

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon or Intel
