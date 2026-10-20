# 素材记录

生成方式：内置 `image_gen` 工具，开启透明背景；未使用 API/CLI 回退。

参考：用户提供的 `SaveTwitter.Net_OF80jjlXfAuFuKPl_(954p).mp4` 中提取的一帧，仅作为小狗外貌参考。参考视频没有复制到发行包。

项目素材：`Assets/puppy-atlas.png`。由该原图透明连通区域直接裁出的 12 个 PNG 放在同目录，裁切保持原始 alpha。图标使用坐姿素材放在圆角底色上生成。

这些图片仅保存在本地，按仓库要求全部被 Git 忽略，不随源码提交。克隆仓库后，请自行创建 `Assets/` 目录并放入原始透明图集，再运行 `build.sh`。

## 最终生成提示词

Use case: stylized-concept. Create ONE production-ready 4-column by 3-row sprite atlas (12 separate full-body poses), landscape 1536x1024, TRUE transparent alpha background. Reference image is subject reference only: the little BLACK Labrador-like puppy with floppy ears, shining dark round eyes and a tiny pink tongue. Reimagine as an exceptionally adorable premium 3D plush toy: huge round head, very short chubby paws, soft fluffy charcoal-black fur with cool soft rim light, round glossy eyes with bright catchlights, tiny wet button nose, slightly pink cheeks, little pink tongue, no accessories. Identical character, camera scale and soft lighting across every cell. Orthographic three-quarter front view unless pose requires otherwise. EXACTLY 4 equal-width columns and 3 equal-height rows; each sprite centered within its own 384x341 cell with at least 35 pixels of transparent padding on ALL sides; no overlap between cells. Max puppy height 260px, same head size in all cells. Row 1 left to right: (1) sitting happily facing viewer, eyes open (2) sitting same pose with adorable head tilt right and tiny tongue out (3) peacefully sleeping curled up horizontally, both eyes closed, head resting on front paws (4) jumping joyfully, all four paws tucked slightly, ears lifted. Row 2 left to right: (5) running towards right, front legs extended forward, rear legs back (6) running towards right, legs gathered under belly (7) rolling on back, belly exposed, all four tiny paws in the air (8) lying belly down with front paws forward, head raised facing viewer. Row 3 left to right: (9) squatting to poop, modest cute pose, NO actual poop in asset (10) standing turned right, one hind leg lifted to pee, NO liquid in asset (11) back three-quarter view looking over shoulder, tail clearly visible for spinning animation (12) sitting facing viewer raising one front paw for a high five, big happy expression. Text: none. No grid lines, no borders, no words, no labels, no scenery, no ground, no cast floor shadows, no checkerboard. Every sprite completely isolated on genuine transparent background. Preserve black puppy identity and highly tactile soft fur; use warm expressive face. This image is a sprite sheet to slice in a native macOS desktop pet app.
