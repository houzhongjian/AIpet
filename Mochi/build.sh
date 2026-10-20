#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ ! -f Assets/puppy-atlas.png ]]; then
    printf '缺少本地素材 Assets/puppy-atlas.png。此源码仓库不包含二进制图片，请按 ASSETS.md 准备素材后再构建。\n' >&2
    exit 1
fi
BUILD="$PWD/build"
APP="$PWD/dist/团团桌面宠物.app"
mkdir -p "$BUILD" "$APP/Contents/MacOS" "$APP/Contents/Resources/Assets"
CLANG=(xcrun clang -fobjc-arc -fno-modules -mmacosx-version-min=13.0 -Wall -Wextra -Wno-unused-parameter)
"${CLANG[@]}" Tools/prepare-assets.m -framework Cocoa -o "$BUILD/prepare-assets"
"$BUILD/prepare-assets" Assets/puppy-atlas.png Assets
"${CLANG[@]}" Sources/App.m Sources/PetModel.m Sources/PetRenderer.m \
    -framework Cocoa -framework ServiceManagement -O2 -o "$APP/Contents/MacOS/Mochi"
cp Info.plist "$APP/Contents/Info.plist"
for name in sit tilt sleep jump run-a run-b roll lie poop pee back paw; do
    cp "Assets/$name.png" "$APP/Contents/Resources/Assets/"
done
"${CLANG[@]}" Tools/make-icon.m -framework Cocoa -o "$BUILD/make-icon"
"$BUILD/make-icon" Assets/sit.png "$BUILD/icon-1024.png"
mkdir -p "$BUILD/AppIcon.iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$BUILD/icon-1024.png" --out "$BUILD/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size*2))
    sips -z "$double" "$double" "$BUILD/icon-1024.png" --out "$BUILD/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
if ! iconutil -c icns "$BUILD/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns" 2>"$BUILD/iconutil.log"; then
    python3 Tools/package-icon.py "$BUILD/AppIcon.iconset" "$APP/Contents/Resources/AppIcon.icns"
fi
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
plutil -lint "$APP/Contents/Info.plist"
printf '\nBuilt: %s\n' "$APP"
