# XeeLite

Minimal macOS image viewer

## What it does

- Opens one image and discovers other images in the same folder
- Moves with `Prev` / `Next`
- Supports keyboard navigation with left and right arrow keys

## Build

```bash
./scripts/build.sh
```

## Package as .app

```bash
./scripts/package-app.sh
```

If `./Resources/icon.png` exists, it will be converted into the app icon automatically.

The app bundle will be created here:

```bash
dist/XeeLite.app
```

You can open it with a double-click in Finder or from Terminal:

```bash
open dist/XeeLite.app
```

## Run

```bash
./scripts/run.sh
```

You can also start it with an image path:

```bash
./scripts/run.sh /path/to/image.jpg
```
