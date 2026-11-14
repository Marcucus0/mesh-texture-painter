# Changelog

## 1.0

- Release packaged as Mesh Texture Painter 1.0, authored by Rhacode.

- Remove the demo scene and assets; generate isolated fixtures only when running tests.

- Separate usage documentation, architecture, development instructions and release history.
- Exclude generated caches, private fixtures, logs and archives from source packaging.
- Add repository formatting rules and reproducible add-on/source packaging.

## 0.3.3

- Display layers topmost first while retaining the existing saved/render order.
- Add equally sized Move layer up / Move layer down buttons, with boundary states.
- Document and support Ctrl+Y through the editor's native redo shortcut.

## 0.3.2

- Always start the brush in Add mode; ignore previously persisted modes.
- Retain radius, strength, hardness, falloff and proposed resolution preferences.

## 0.3.1

- Add English and French editor-localized UI, status messages, history labels and channel names.
- Isolate editor translations from the game's locale.
- Separate automatic UV recovery logic from translated error strings.

## 0.3.0

- Cache world geometry, visibility and stationary brush footprints.
- Batch mask uploads by layer and surface; reduce the target raster batch budget.
- Avoid smoothing copies for unaffected surfaces.

## 0.2.9

- Persist project-local brush preferences. Brush-mode persistence was subsequently removed in 0.3.2.

## 0.2.8

- Reuse saved paint stacks after reopening, including Windows path-casing variants.
- Prefer a populated stack over an existing empty duplicate.

## 0.2.7

- Replace normal displacement with projected depth bias to fix grazing-angle disappearance.

## 0.2.6

- Add coverage-aware GPU mask gutters to reduce transparency seams at UV island boundaries.

## 0.2.5

- Fix held-button live painting and editor viewport refresh.
- Import supported PBR maps and settings from Standard/ORM materials.

## 0.2.4

- Reuse preview meshes and materials across strokes.
- Bound brush batches and add a defensive Intel / Direct3D 12 guard after a reproduced native crash.

## 0.2.3

- Add texture thumbnails, active previews, explicit import feedback and reliable dialog targeting.

## 0.2.0–0.2.2

- Generate private paint UVs for meshes with unusable UVs.
- Remove global script class registration and use relative preloads for path-casing compatibility.

## 0.1.0

- Initial non-destructive UV-mask painting, layered PBR overlays, editor dock, history and scene persistence.
