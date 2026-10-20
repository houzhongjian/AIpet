#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="dist/团团桌面宠物.app"
codesign --verify --deep --strict "$APP"
STAGE=$(mktemp -d "$PWD/build/package.XXXXXX")
ROOT="$STAGE/团团桌面宠物"
mkdir -p "$ROOT"
ditto "$APP" "$ROOT/团团桌面宠物.app"
cp 安装团团.command "$ROOT/"
cp dist/动作预览.png "$ROOT/"
cat > "$ROOT/先读我.txt" <<'TEXT'
团团 · 你的桌面小狗

安装：双击「安装团团.command」，应用会安装到你个人的 Applications 文件夹。
也可以直接双击「团团桌面宠物.app」。

点一下：摸摸。双击：跳跳。拖动：抱起来。右键：更多动作。
屏幕顶部菜单栏有一个爪印，可以打开小窝、叫回小狗、暂停或退出。
关闭小窝窗口不会退出小狗。

开机启动：更多设置 → 登录 Mac 时来找我。
若系统要求批准，请到 macOS 系统设置 → 通用 → 登录项确认。

支持 Apple Silicon Mac，macOS 13 或更新版本。
当前为本机生成、ad-hoc 签名的个人版本，未做 Apple 公证。
动画采用透明毛绒姿势图与连续变换。
无需账号、网络、辅助功能或屏幕录制权限。

卸载：先关闭登录自启，退出后把应用移到废纸篓。
TEXT
python3 - "$ROOT" "$PWD/dist/团团桌面宠物-macOS-AppleSilicon.zip" <<'PY'
from pathlib import Path
import sys
import zipfile
root, output = map(Path, sys.argv[1:])
with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in sorted(root.rglob("*")):
        archive.write(path, path.relative_to(root.parent))
PY
printf 'Packaged: %s/dist/团团桌面宠物-macOS-AppleSilicon.zip\n' "$PWD"
