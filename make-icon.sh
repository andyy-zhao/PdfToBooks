#!/bin/bash
# Regenerates AppIcon.icns from AppIcon-source.png
# Run from the BookReader directory: ./make-icon.sh
# Requires: Python 3 with Pillow (pip install Pillow)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export SCRIPT_DIR
cd "$SCRIPT_DIR"

SOURCE="$SCRIPT_DIR/Resources/AppIcon-source.png"
ICONSET="$SCRIPT_DIR/Resources/AppIcon.iconset"

if [ ! -f "$SOURCE" ]; then
    echo "Error: AppIcon-source.png not found in Resources/"
    exit 1
fi

echo "Creating square crop with rounded corners..."
python3 << 'PYEOF'
from PIL import Image, ImageDraw
import os

script_dir = os.environ.get("SCRIPT_DIR", ".")
src = Image.open(os.path.join(script_dir, "Resources/AppIcon-source.png")).convert("RGBA")
w, h = src.size
size = min(w, h)
left = (w - size) // 2
top = (h - size) // 2
img = src.crop((left, top, left + size, top + size))

# macOS-style rounded corner radius (~22% of half-size = squircle-like)
radius = int(size * 0.2237)
# Mask: draw rounded rect (white inside, black outside)
mask = Image.new("L", (size, size), 0)
draw = ImageDraw.Draw(mask)
draw.rounded_rectangle([(0, 0), (size - 1, size - 1)], radius=radius, fill=255)
# Apply mask to get rounded corners (transparent outside)
output = Image.new("RGBA", (size, size), (0, 0, 0, 0))
output.paste(img, (0, 0), mask)
output.save(os.path.join(script_dir, "Resources/AppIcon-square.png"))
PYEOF

echo "Generating icon sizes (full macOS set)..."
mkdir -p "$ICONSET"
python3 << 'EOF'
from PIL import Image
import os

script_dir = os.environ.get("SCRIPT_DIR", os.path.dirname(os.path.abspath("Resources")))
src = Image.open(os.path.join(script_dir, "Resources/AppIcon-square.png")).convert("RGBA")
iconset = os.path.join(script_dir, "Resources/AppIcon.iconset")
os.makedirs(iconset, exist_ok=True)

# Full macOS app icon set (size and dimensions match standard Mac apps)
sizes = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for name, size in sizes:
    img = src.resize((size, size), Image.Resampling.LANCZOS)
    img.save(os.path.join(iconset, name), "PNG")

EOF

echo "Creating AppIcon.icns..."
iconutil -c icns -o "$SCRIPT_DIR/Resources/AppIcon.icns" "$ICONSET"

echo "✓ Icon created: Resources/AppIcon.icns"
