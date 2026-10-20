#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
SOURCE="$PWD/团团桌面宠物.app"
if [[ ! -d "$SOURCE" ]]; then SOURCE="$PWD/dist/团团桌面宠物.app"; fi
TARGET="$HOME/Applications/团团桌面宠物.app"
if [[ ! -d "$SOURCE" ]]; then
    printf '没有找到应用。请把安装程序和「团团桌面宠物.app」放在同一文件夹。\n'
    exit 1
fi
codesign --verify --deep --strict "$SOURCE"
mkdir -p "$HOME/Applications"
if [[ -d "$TARGET" ]]; then
    ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$TARGET/Contents/Info.plist")
    if [[ "$ID" != 'com.mochipet.desktop' ]]; then
        printf '安装位置已有其他应用，请先手动移开它。\n'
        exit 1
    fi
    printf '团团已经安装好了，正在为你打开。\n'
    open "$TARGET" --args --show-settings
else
    STAGE=$(mktemp -d "$HOME/Applications/.mochi-install.XXXXXX")
    trap 'rmdir "$STAGE" 2>/dev/null || true' EXIT
    ditto "$SOURCE" "$STAGE/团团桌面宠物.app"
    codesign --verify --deep --strict "$STAGE/团团桌面宠物.app"
    mv "$STAGE/团团桌面宠物.app" "$TARGET"
    open "$TARGET" --args --show-settings
    printf '\n团团已安装到：%s\n' "$TARGET"
fi
printf '想每次开机都见到它？在「更多设置」里打开「登录 Mac 时来找我」。\n'
