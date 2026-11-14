# Architecture

## Scope and choice of backend

The add-on targets Godot 4.7 static `MeshInstance3D` nodes, including imported GLB/GLTF models with multiple surfaces. Painting resolution is independent of vertex density. Original geometry, materials, overrides and imported files are retained.

| Approach | Benefits | Constraints | Decision |
| --- | --- | --- | --- |
| Vertex painting | Small storage and simple rendering | Precision depends on vertices | Excluded |
| Fixed RGBA splatmap | Few render passes | Fixed material/weight count | Not used as the user-facing model |
| Texture arrays and generated PBR shader | Fewer passes; scalable texture indexing | Common texture formats/sizes; sampler limits; original material conversion | Possible future backend |
| Independent UV masks and alpha passes | Reversible original material; independent layers; simple resources | Overdraw, transparent sorting and cost per layer | Current backend |
| Projection / triplanar sampling | Can reduce dependence on texture UV layout | Does not solve paint-mask storage; additional sampling cost | Not implemented |

## Modules

| File | Responsibility |
| --- | --- |
| `plugin.gd` | Editor dock, input, brush settings, layer ordering, history and stroke batching. |
| `stack.gd` | Saved `TexturePaint` child, layer ownership, source fingerprint and cached rendering proxies. |
| `layer.gd` | PBR parameters, authored CPU masks, serialization and transient GPU mask textures. |
| `geometry.gd` | Triangle/BVH construction, UV validation, world-space brush rasterization and visibility/footprint caches. |
| `paint_uv.gd` | Automatic private UV generation with `ArrayMesh.lightmap_unwrap`. |
| `mask_padding.gd` | Coverage-aware gutter mapping for filtered mask edges. |
| `paint.gdshader` | Alpha-composited PBR overlay and projected depth bias. |
| `localization.gd` | English catalogue and editor-specific translation domain. |

Paths in the add-on use relative preloads. Stack/layer scripts intentionally have no global `class_name`: Windows scenes can load the same file under `Addons` and `addons`, yielding different script identities. The editor discovers existing stacks by normalized script path and prefers a stack containing layers over an accidental empty duplicate. Keep consistent lowercase paths for exports to case-sensitive systems.

## Data and persistence

Each painted mesh has a `TexturePaint` child with independent layer resources. Each layer stores an L8 mask per surface, embedded as compressed PNG data in the scene. The authored CPU images are the source of truth; GPU textures are transient and are never read back to reconstruct saved paint.

Layers are local to the scene. A weak ownership reference detects ordinary node duplication and detaches shared layer/mask resources. Source textures remain shared in read-only use. A fingerprint of vertex positions, indices and UVs detects incompatible reimports; painting is suspended instead of silently reusing masks on changed geometry.

Scenes with valid UV1 retain them. Missing, out-of-range, degenerate or detected-overlapping UVs cause a private `ArrayMesh` copy to be unwrapped into UV2. Original UV1 remain available for PBR texture sampling; when missing, generated coordinates are also supplied for painted textures. The private mesh is saved, so an exported game does not unwrap at runtime.

Brush preferences use project-local editor metadata. Radius, strength, hardness, falloff and proposed resolution persist; the mode always starts in Add. Layer parameters and masks are saved with the scene. Undo snapshots are PNG arrays held by the editor's scene history; undo history itself does not survive closing Godot.

## Brush pipeline

1. Build triangle data, a `TriangleMesh` BVH and a scene-level central-ray occluder cache when paint mode is activated.
2. Cache world-space triangle positions and bounds in groups of 64. Reject groups and triangles outside the brush sphere before rasterization.
3. Project the world-space brush sphere into each candidate triangle's UV plane to bound visited texels.
4. Test texel visibility against the target mesh BVH, caching results for a fixed camera. Other scene objects only block the brush's central ray.
5. Cache the last footprint's texel coordinates and normalized distances. Repeated stationary dabs and multiple layers can share this geometric work; blend values are always evaluated against current mask contents.
6. Upload changed masks once per layer/surface per batch. The raster loop targets an 8 ms batch budget and at most three dabs, but a single dab, upload or render can exceed it.
7. On release, flush pending uploads and commit one scene undo action.

World geometry is invalidated for transform/resolution changes and rebuilt when geometry is rebuilt. Camera/projection/radius changes invalidate dependent visibility data. Changing brush position invalidates the footprint. Re-enable paint mode after moving scene occluders.

Smoothing copies only affected surfaces and uses a 3×3 neighborhood. The displayed gutter padding is derived from UV coverage and extends mask samples three texels outside triangles without overwriting another island's interior or filling authored erasure holes. This avoids a shader-side neighborhood sampling cost.

The mouse path is processed in bounded batches. Very fast movement can leave an incomplete final segment if the button is released before the brush catches up. Uploads use complete changed masks because the current `ImageTexture.update` path is not a partial-rectangle uploader.

## Rendering and layer order

The original mesh renders its original materials. Internal, unsaved proxy nodes hold cached surface meshes and a `ShaderMaterial.next_pass` chain for painted layers. They are reused across strokes. There is no permanent CPU processing for a static painted mesh at runtime.

Storage is **bottom-to-top**. The panel displays **top-to-bottom**, converting UI indices into storage indices. Higher storage indices have higher render priority. Existing saved layer arrays are not reversed or migrated; the visual appearance of saved paint is preserved.

Empty/hidden layers are culled at rest. During a stroke, enabled empty surfaces are prepared so new paint appears immediately. There is one pass per visible nonempty layer/surface, plus the original base. The implementation caps each object at 32 layers; 2–8 visible layers are recommended. Project-wide presets have no fixed count limit.

The shader discards unpainted mask samples. A projected depth bias prevents coplanar depth conflicts at grazing angles without moving vertices along their normals. It retains depth testing and has separate Compatibility and Forward+/Mobile branches, with reduced orthographic bias. Nearly coincident geometry remains limited by depth-buffer precision.

This is layered compositing of lit PBR results, not a unified blend of the base material's PBR inputs. Base shadows remain unchanged, and transparent sorting/SSR limitations apply. Custom shaders, skeletons, blend shapes, existing overlays/next passes and some base material deformations are rejected.

Standard/ORM layer import copies supported PBR textures, channels and scalar/UV properties into a new layer. It does not modify the imported material. Height/parallax, triplanar projection, emission, detail mapping and extra passes are omitted with a message.

## Performance and backend restrictions

An L8 mask uses resolution² bytes per CPU copy, plus GPU storage and overhead. A 512² mask is 256 KiB; 2048² is 4 MiB. Stroke copies, caches, padding and undo snapshots add memory cost.

A local seven-surface, 512-mask benchmark with world radius 40 measured roughly 18–20 ms per dab before brush caching, 6–9 ms while moving afterward, and about 0.2 ms for subsequent stationary dabs. These are CPU brush measurements, not scene FPS guarantees or general hardware benchmarks. First-use preparation, texture uploads, overdraw and large masks remain costly.

An Intel Iris Xe / Direct3D 12 device loss and native Godot crash were reproduced during painting. Painting is therefore conservatively blocked on Intel + D3D12, including rebuilding saved proxies. Vulkan + Forward+ passed the corresponding stress scenario. This is a guarded backend restriction, not a driver fix.

The editor has a private translation domain initialized from the editor locale. It is shared across path-casing variants and isolated from the game's locale. Source French messages and an English catalogue preserve format placeholders; custom layer names are never localized.

## Deferred work

A tiled GPU brush backend, unified material conversion, layer baking, connected-region fill, height blending, global preset browsing, automatic reprojection and broad hardware/large-scene benchmarking remain outside the current implementation.

## Godot API references

- [EditorPlugin](https://docs.godotengine.org/en/stable/classes/class_editorplugin.html)
- [EditorUndoRedoManager](https://docs.godotengine.org/en/stable/classes/class_editorundoredomanager.html)
- [TriangleMesh](https://docs.godotengine.org/en/stable/classes/class_trianglemesh.html)
- [ImageTexture](https://docs.godotengine.org/en/stable/classes/class_imagetexture.html)
- [Spatial shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)
- [TranslationDomain](https://docs.godotengine.org/en/stable/classes/class_translationdomain.html)
