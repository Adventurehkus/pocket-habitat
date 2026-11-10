# Pocket Habitat — Asset Pipeline

## Visual direction
Use a cohesive, colorful low-poly style with readable silhouettes, soft natural colors, clean materials, and lightweight geometry. Prioritize the starter habitat before creating large asset sets.

## Creation order
1. Prototype the environment with native Roblox Parts and simple MeshParts.
2. Build reusable vegetation, rocks, resource nodes, garden plots, and creature components.
3. Add restrained particles, lighting accents, and simple animations.
4. Optimize models, materials, collision, and draw calls before adding content volume.

## Source and licensing
- Prefer original Roblox geometry and procedural assets.
- Blender may be used for original mesh creation; keep editable source files alongside documented exports.
- Do not use copied game assets, unlicensed textures, or unreviewed Toolbox models.
- Record asset origin, license, import settings, scale, and intended use.

## Repository organization
- Keep runtime assets under `assets/runtime/` as mapped by `default.project.json`.
- Keep Blender source and export notes in a clearly named source-art folder if that pipeline is introduced.
- Use descriptive, stable names and avoid committing generated caches or temporary exports.

## Performance requirements
- Reuse meshes and materials where practical.
- Keep collision geometry simple.
- Avoid excessive particle emitters, transparent layers, and high-part-count models.
- Check performance on low-end mobile hardware as well as desktop.

## Current status
This document describes the planned pipeline. No custom production assets have been verified as implemented yet.
