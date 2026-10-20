# AIpet

团团：一只住在 macOS 桌面上的毛绒小狗。

原生 Objective-C / AppKit 客户端，支持桌面漫游、鼠标互动、拖动、睡觉、跳跃、转圈、奔跑、打滚、翻身、握爪和上厕所动作。提供菜单栏入口、偏好设置和登录自启开关。

## 仓库内容

本仓库只保存文本源码、构建脚本和说明文档。**不上传应用程序、安装包、编译产物、图片或视频等二进制文件。**

- `Mochi/Sources/`：客户端与动画逻辑。
- `Mochi/Tools/`：素材裁切、图标生成和图标打包工具的源码。
- `Mochi/Info.plist`：应用配置。
- `Mochi/build.sh`：本地构建。
- `Mochi/package.sh`：本地打包。
- `Mochi/安装团团.command`：本地安装脚本。

## 本地构建

需要 macOS 13+、Apple Command Line Tools，以及 Python 3。默认构建当前机器架构。

图片素材不在 Git 仓库中，因此克隆后需要先自行准备透明姿势图集，并保存为 `Mochi/Assets/puppy-atlas.png`。图集布局和生成提示词见 [素材说明](Mochi/ASSETS.md)。

```bash
bash Mochi/build.sh
```

产物位于 `Mochi/dist/团团桌面宠物.app`，该目录被 Git 忽略。

详细使用方式、构建检查和当前限制见 [项目说明](Mochi/README.md)。
