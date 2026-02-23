# Book Reader

A native macOS app that turns PDF books and textbooks into an Apple Books–style reading experience.

## Features

- **Apple Books–style UI** – Clean, minimal interface with warm paper-like background
- **Two-page spread** – Pages displayed side by side like Apple Books with no gap between them; arrow keys to flip between spreads (no vertical scrolling)
- **Arrow key navigation** – ← and → keys to flip between pages/spreads
- **Table of Contents** – Access via the 3-dots (⋯) menu; uses PDF outline when available
- **Page indicator** – Shows current page at bottom
- **Highlighting** – Select text; a "Highlight" tooltip appears above the selection. Click it to highlight (saved with the PDF).
- **Notes** – Select text, right-click, and choose "Add Note"
- **Highlights & Notes view** – View all annotations via the 3-dots menu
- **Save** – Cmd+S to save, or **auto-save** when you add highlights/notes
- **Recent documents** – Recently opened PDFs on the welcome screen; click to reopen
- **Remember position** – Reopens at your last page
- **Remove highlight** – Right-click highlighted text → "Remove Highlight"
- **Title bar double-click** – Double-click the title bar (or top of window) to maximize/restore

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+ (for building)

## Building & Running

### Option 1: Standalone App (recommended)

Build a double-clickable `.app` you can move to Applications:

```bash
cd BookReader
chmod +x build-app.sh
./build-app.sh
```

The app will be at `build/Book Reader.app`. To install:

```bash
cp -r "build/Book Reader.app" /Applications/
```

Or open the `build` folder in Finder and double-click the app to run it.

### Option 2: Swift Package Manager (Terminal)

```bash
cd BookReader
swift build
swift run BookReader
```

### Option 3: Xcode

1. Open `BookReader` in Xcode (File → Open → select the `BookReader` folder)
2. Select the `BookReader` scheme
3. Press Cmd+R to build and run

## Usage

1. **Open a PDF** – Click "Open PDF" on the welcome screen or use File → Open PDF (Cmd+O)
2. **Navigate** – Scroll to move between pages
3. **Table of Contents** – Click the ⋯ button → "Table of Contents" (if the PDF has outline data)
4. **Highlight** – Select text → right-click → "Highlight"
5. **Add Note** – Select text → right-click → "Add Note"
6. **Save** – Highlights and notes auto-save when you add them. Use Cmd+S to manually save.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+O | Open PDF |
| Cmd+S | Save |
| Cmd+W | Close document |

## App Icon

The app uses a custom icon with macOS-style rounded corners and the full standard icon set (16–1024 px) so it matches other Mac apps in size and appearance. To change it, replace `Resources/AppIcon-source.png` with your image, then run:

```bash
pip install Pillow  # if needed
./make-icon.sh
./build-app.sh
```

## Note on Table of Contents

The table of contents is built from the PDF’s outline/bookmarks. If a PDF has no outline, the TOC will show "No table of contents."
