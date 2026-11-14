# Development and validation

Use Godot **4.7.2** to reproduce the current validation. The add-on has no external runtime dependencies. Test scenes and small PNG textures are generated under tests/output; private models and material libraries are not distributed.

## Main test suite

On Windows, from the repository root:

```powershell
./tests/run.ps1 -Godot 'C:/path/to/Godot_v4.7.2-stable_win64_console.exe'
```

The runner generates and imports its fixtures, then checks geometry, masks, scene persistence, resource independence, automatic UVs, seam padding, brush caches, translations and editor integration. Windows-specific isolated projects exercise `Addons` / `addons` path casing, reopening, brush preferences, layer order and English/French editor locales. Only the temporary editor-test plug-in configuration is enabled during those checks; the original `project.godot` is restored afterward.

All generated scenes, isolated projects and logs go under **`tests/output/`**, which is ignored by Git. The suite does not require personal GLB files or a downloaded material library.

To add GPU smoke tests:

```powershell
./tests/run.ps1 -Godot 'C:/path/to/Godot_v4.7.2-stable_win64_console.exe' -Render
```

GPU checks need a working graphics session. The seam regression explicitly uses Vulkan; rendering smoke tests cover Compatibility and Forward+. Hidden/headless editor windows do not reliably dispatch native menu keyboard shortcuts: the layer-order test checks the `ui_redo` shortcut binding and exercises the corresponding scene history separately.

Individual headless checks can also be run directly:

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/test_painter.gd
godot --headless --path . --script tests/test_brush_cache.gd
godot --headless --path . --script tests/test_localization.gd
```

The PowerShell integration runner uses Windows process options; the individual GDScript commands are portable. GPU behavior and large-scene performance must still be tested on the target hardware.

## Optional diagnostic fixtures

These are development tools, outside the default suite:

| Tool | Additional input |
| --- | --- |
| `test_missing_uv.gd`, `test_render_asset.gd`, `bench_padding.gd` | A local GLB path supplied after `--`. |
| `create_stress_scene.gd`, `editor_stress/` | A local model converted into `tests/output/stress-island.tscn`, then copied into an isolated project. Set `MTP_STRESS_ASSET=1` for the model test; without it the stress plug-in uses the generated fixture. |
| `extract_camera_repro.ps1 -Source <scene.tscn>` | A saved scene containing `Island_Terrain` and `TexturePaint`. Extracts their resource dependencies into the local camera fixture. |
| `test_camera_grazing.gd`, `bench_brush.gd` | `camera-island.tscn` and its textures in `tests/output/case_project/`. The camera test's optional `--baseline` additionally needs the previous shader saved as `paint-before-depth.gdshader`. |
| `editor_live/` | The generated `tests/output/material-pbr.tres` fixture, or a material path supplied through `MTP_TEST_MATERIAL`. Copy the fixture and its dependencies into the isolated project. |

`prepare_case_project.ps1` requires generated fixtures and creates a capitalized `Addons` test project under `tests/output/case_project`; `-MismatchedActivation` deliberately enables it through a lowercase path. `prepare_reopen_project.ps1` builds a separate reopening fixture. Keep these private diagnostic assets under ignored output directories.

## Packaging

```powershell
./scripts/package.ps1
./scripts/package.ps1 -Source
```

The first command creates the standalone add-on ZIP. `-Source` additionally creates a source archive for GitHub upload. The script reads the version from `plugin.cfg`, uses a controlled file list and excludes caches, output fixtures, logs and earlier release archives. Both archives are written to ignored `dist/`.

Publish release ZIPs as GitHub release assets. The source tree should contain `addons`, `docs`, `tests`, `scripts` and repository configuration files, not generated copies of those directories. Keep `.gd.uid`, `.gdshader.uid` and asset `.import` sidecars; Godot's generated `.godot/` cache must stay untracked.

## Maintenance

- Keep the storage order bottom-to-top; the UI maps it to top-to-bottom. Changing storage order would alter existing paint.
- Use relative preloads inside the add-on and avoid global `class_name` declarations for its resources. Windows projects may reference different path casing.
- CPU masks are the authored source of truth. GPU padding and textures are derived data.
- Keep the editor translation domain separate from the game's locale. Preserve formatting placeholders when extending `localization.gd`.
- Brush caches must be invalidated when geometry, transform, resolution, camera projection or visibility assumptions change.
- Run the relevant headless and editor checks before changing the package version. Use visual tests for shader/rendering changes.
