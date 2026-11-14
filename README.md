# Mesh Texture Painter for Godot

Paint PBR texture layers directly onto ordinary `MeshInstance3D` surfaces in the Godot 3D editor. The original mesh and materials are preserved, and paint remains editable after saving and reopening the scene.

**Version 1.0 · By Marcucus0 · Godot 4.7.x · Tested with Godot 4.7.2**

[Français — README en français](README.fr.md) · [Architecture](docs/ARCHITECTURE.md) · [Changelog](CHANGELOG.md) · [Development and tests](docs/DEVELOPMENT.md)

## Features

- Paint directly in the 3D viewport with precision determined by texture masks, independently of vertex count.
- Add images, Godot `StandardMaterial3D` / `ORMMaterial3D` resources, or reusable layer presets.
- PBR layers with albedo, normal, roughness, metallic, AO, tint and UV settings.
- Add, replace, erase, smooth and restore-original brush modes.
- Adjustable world radius, strength, hardness and falloff; editable layer opacity and transitions.
- Layer thumbnails, visibility, fill, reset, mask inversion and up/down ordering. The top layer in the list appears on top in the viewport.
- Non-destructive painting on imported GLB/GLTF meshes and meshes with multiple surfaces.
- Automatic private paint UV generation when existing UVs cannot be used.
- Scene-integrated undo/redo, embedded paint masks and persistent brush preferences.
- English and French interfaces, following the editor language.

This is an advanced prototype with CPU painting and GPU-rendered overlay passes. Large-scene performance and complex-material compatibility remain limited; see the restrictions below.

## Installation

1. Download the repository or an add-on release archive.
2. Copy `addons/mesh_texture_painter` into your Godot project, preserving the lowercase `addons` path.
3. Enable **Mesh Texture Painter** in **Project → Project Settings → Plugins**.
4. Select a supported `MeshInstance3D`; the **Texture Paint** dock contains the painting tools.

To update, close Godot, replace the add-on folder and reopen the project. Existing masks and brush settings remain compatible. Keep the add-on scripts and shader in game exports: saved paint is reconstructed at runtime.

## Quick start

1. Select a mesh and enable **Texture Paint**.
2. Choose the mask resolution before creating the first layer; start with **256 or 512**.
3. Click **Add image / material .tres** and choose a texture or an opaque Standard/ORM material.
4. Select a layer and hold the **left mouse button** over the mesh to paint. Hold **Alt** to navigate.
5. Adjust the layer's **UV scale** to control texture tiling, independently of mask resolution.
6. Save the scene with **Ctrl+S**. Select the same mesh and enable paint mode after reopening to continue editing.

## Brushes and layers

| Control | Behavior |
| --- | --- |
| Add | Accumulates paint on the active layer. |
| Replace layers | Adds the active layer while erasing other layers under the brush. |
| Erase layer | Removes paint from the active layer only. |
| Smooth layer | Smooths its mask, without blurring the source texture. |
| Restore original | Locally erases all layers, including hidden layers. |
| Move layer up / down | Reorders the active layer visually and in rendering. |
| Disable paint rendering | Shows the original material while retaining all paint data. |
| Remove paint system | Removes the `TexturePaint` child; this action is undoable. |

Use **Ctrl+Z** to undo and **Ctrl+Y** to redo. A held stroke is one undo action. Godot's undo history does not survive closing the editor, but the saved layers and masks remain editable.

Brush radius, strength, hardness, falloff and the proposed resolution are remembered locally per project. The brush always starts in **Add** mode. Layer properties are saved with the scene.

Use **PBR properties (Inspector)** for additional maps and channel settings. **Save layer preset .tres** saves reusable material settings without the mesh's paint masks. Layer names and source asset names are never translated.

For English, select **English** under **Editor → Editor Settings → Interface → Editor → Editor Language**, then restart if requested. French editor locales use French; other locales use English. The game's language does not affect the plug-in interface.

## Compatibility and limitations

- Supports static, opaque triangle meshes with opaque `StandardMaterial3D` / `ORMMaterial3D` base materials. Custom shaders, skeletons, blend shapes, existing material overlays / next passes and some material deformations are unsupported.
- Original geometry, materials and imported source files are not rewritten. Paint is rendered as separate alpha-composited PBR passes, rather than a unified single-pass blend of base material parameters. Godot's transparent rendering, sorting and SSR limitations apply; shadows remain those of the original mesh.
- Missing, invalid or detected-overlapping UVs trigger private automatic UV generation. UV overlap detection is conservative, not a guarantee for tiny islands. Automatic UVs may introduce seams; changing topology or UVs after painting requires restoring the original mesh or starting again. No automatic reprojection is provided.
- **32 layers per object**, with **2–8 recommended**. Project-wide presets have no fixed count limit. Each nonempty visible layer adds a render pass per surface.
- Mask resolutions range from **128 to 2048**. Larger masks and brushes cost more CPU time and memory. Modified layer/surface masks are uploaded in full, once per brush batch; painting is not a tiled GPU backend.
- Same-mesh back faces are protected by per-texel visibility tests. Other scene objects block the brush's central ray only. Re-enable paint mode after moving occluding scene geometry.
- Imported paint materials do not include height/parallax, triplanar projection, emission, detail mapping or additional passes; active omissions are reported when importing.
- **Intel + Direct3D 12 painting is blocked** after a reproduced GPU device loss and native crash. Use **Vulkan + Forward+**: set `rendering/rendering_device/driver.windows` to `vulkan` and restart Godot.
- The brush preview is a circle in the local tangent plane. Connected-region fill, baking, height blending and a global preset browser are not implemented.

## Repository layout

```text
addons/mesh_texture_painter/   Standalone editor add-on and runtime paint resources
docs/                        French guide, architecture and development notes
tests/                       Automated checks and optional diagnostic tools
scripts/                     Release packaging
```

Generated output, Godot caches and local test assets are ignored by Git. Releases are generated in `dist/`; they should be uploaded as release assets rather than committed to the source tree.
