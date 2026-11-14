# Mesh Texture Painter 1.0

By **Marcucus0**.

[Français — README en français](README.fr.md)

Godot 4.7 editor add-on for painting PBR texture layers onto static `MeshInstance3D` surfaces. Tested with Godot 4.7.2. The original mesh and materials are preserved; masks are saved in the scene and remain editable after reopening.

## Install and update

Copy this folder to `addons/mesh_texture_painter` and enable **Mesh Texture Painter** in **Project → Project Settings → Plugins**. Keep path casing consistent. To update, close Godot, replace this folder and reopen the project. Keep its scripts and shader in exported games.

## Paint

1. Select a supported mesh and enable **Texture Paint** in the dock.
2. Choose a mask resolution before the first layer; start at 256 or 512.
3. Use **Add image / material .tres** to add an image, a Standard/ORM material or a layer preset.
4. Select a layer and hold the left mouse button to paint. Alt navigates.
5. Save the scene. Select the same mesh and enable paint mode to resume later.

Add, replace, erase, smooth and restore-original brushes are available. Adjust radius, strength, hardness and falloff; layer opacity, transition, UV scale and PBR maps remain editable. The layer at the top of the list renders on top. Move up / Move down reorder it. Presets save layer settings without paint masks.

**Ctrl+Z** undoes; **Ctrl+Y** redoes through the native editor history. Undo history does not persist after closing Godot, but saved paint remains editable. Brush preferences persist locally per project, except the mode: each session starts in **Add**.

The UI follows the editor language at startup: French for French locales, English otherwise. Change **Editor Settings → Interface → Editor → Editor Language** and restart if requested. The game's language and custom layer names are unaffected.

## Compatibility

- Static opaque triangle meshes, including imported GLB/GLTF meshes and multiple surfaces.
- Original opaque Standard/ORM materials are preserved. Custom shaders, skeletons, blend shapes, existing overlays/next passes and some material deformations are unsupported.
- Missing/unusable UVs trigger a saved private unwrap. Tiny overlapping UV islands may escape detection. Changing topology or UVs later requires restoring the original model or starting again.
- Independent UV masks, resolutions 128–2048; 32 layers/object, with 2–8 recommended. Each visible nonempty layer adds a pass per surface. Painting runs on the CPU and uploads full changed masks; large brushes, masks and many layers remain costly.
- Alpha-composited PBR passes retain Godot's transparent sorting/SSR limitations. Shadows remain those of the original mesh. This is not a unified single-pass material blend.
- Imported paint materials omit height/parallax, triplanar projection, emission, detail and extra passes; omissions are reported.
- Same-mesh back faces are protected per texel; other objects block only the brush's central ray. Re-enable paint mode after moving occluders.
- Intel + Direct3D 12 painting is blocked after a reproduced GPU device loss and native crash. Use Vulkan + Forward+: set `rendering/rendering_device/driver.windows = vulkan`, then restart.

This is an advanced prototype. Tiled GPU painting, connected-region fill, baking, height blending, automatic reprojection and a global preset browser are not implemented. Full English/French guides, architecture and development instructions are in the source repository's README and `docs/` directory.
