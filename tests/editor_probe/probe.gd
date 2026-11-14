@tool
extends EditorPlugin
var failures := 0
var checks := 0

func _enter_tree() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var filesystem := get_editor_interface().get_resource_filesystem()
	while filesystem.is_scanning():
		await get_tree().process_frame
	get_editor_interface().open_scene_from_path("res://tests/output/fixtures/island.tscn")
	# Exercise user actions after the editor has restored its dock layout.
	for frame in 20:
		await get_tree().process_frame
	var scene := get_editor_interface().get_edited_scene_root()
	var painter := find_painter(get_tree().root)
	check(painter != null, "Painter dock plugin must load")
	if painter == null:
		get_tree().quit(1)
		return
	var target: MeshInstance3D = scene.get_node("Island")
	var original := target.mesh
	painter._edit(target)
	painter._file_selected("res://tests/output/fixtures/grass.png")
	check(painter.status.text.begins_with("Ajout impossible"), "Missing paint stack must show an error rather than silently returning")
	check(painter._validate().is_empty(), "Demo must pass editor compatibility validation")
	painter.resolution.value = 128
	painter._toggle_paint(true)
	check(painter.painting and painter.stack != null, "Editor must attach paint stack")
	painter._file_selected("res://tests/output/fixtures/grass.png")
	painter._file_selected("res://tests/output/fixtures/dirt.png")
	check(painter.stack.layers.size() == 2, "Editor must add two textures")
	check(painter.layer_list.item_count == 2, "Added textures must appear in the layer list")
	check(painter.layer_list.get_item_icon(0) == painter.stack.layers[1].albedo, "Layer list must display the top texture thumbnail first")
	check(painter.layer_list.is_selected(0), "New texture must be selected at the top")
	check(painter.active_preview.texture == painter.stack.layers[1].albedo, "Active texture preview must show the added texture")
	check(painter.status.text.begins_with("Texture ajoutée"), "Successful import must show explicit feedback")
	check(not painter.empty_layers.visible and painter.layer_count.text == "Couches : 2", "Empty state and layer count must update")
	for frame in 3:
		await get_tree().process_frame
	check(painter.layer_list.is_visible_in_tree(), "Texture list must be brought to the front after import")
	check(painter.layer_list.size.x >= 260 and painter.layer_list.size.y >= 160, "Texture list must have usable visible dimensions")
	if OS.get_environment("MTP_CAPTURE_DOCK") == "1":
		for frame in 8:
			await get_tree().process_frame
		RenderingServer.force_draw()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output"))
		get_tree().root.get_texture().get_image().save_png("res://tests/output/editor-textures.png")
	painter._file_selected("res://tests/output/fixtures/island.tscn")
	check(painter.status.text.begins_with("Fichier refusé") and painter.stack.layers.size() == 2, "Wrong resource type must show an error without adding a layer")
	painter._file_selected("res://tests/output/fixtures/does-not-exist.png")
	check(painter.status.text.begins_with("Texture introuvable"), "Missing image must show an actionable error")
	check(painter._begin_texture_import(), "Texture chooser must capture its destination mesh")
	painter._edit(null)
	painter._file_selected("res://tests/output/fixtures/grass.png")
	check(painter.target == target and painter.stack.layers.size() == 3, "Import must survive editor selection clearing during file browsing")
	check(painter.painting and painter.active_preview.texture != null, "Import must restore painting and its preview")
	painter._remove_layer()
	painter._select_layer(1)
	check(not painter.scene_bvh.intersect_ray(Vector3(0, 3, 0), Vector3.DOWN).is_empty(), "Scene occluder BVH must contain target")
	var camera: Camera3D = scene.get_node("Camera3D")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = camera.unproject_position(Vector3.ZERO)
	painter._forward_3d_gui_input(camera, press)
	painter._refresh()
	check(painter.dragging, "UI refresh must not end a running stroke")
	var first_opacity: float = painter.stack.layers[1].masks[0].get_pixel(64, 64).r
	for tick in 8:
		painter._process(0.05)
	check(painter.dragging, "Held editor gesture must not depend on game Input mouse state")
	check(painter.stack.layers[1].masks[0].get_pixel(64, 64).r > first_opacity + 0.2, "Held stationary brush must continuously increase the mask before release")
	painter.previous_mouse = press.position
	painter.mouse = press.position + Vector2(10000, 0)
	painter._advance_brush(0.05)
	check(painter.previous_mouse.distance_to(painter.mouse) > 100, "Fast movement must be spread over frames instead of processed as one burst")
	painter._finish_stroke()
	check(FileAccess.file_exists("res://.godot/mesh_texture_painter.log"), "Stroke diagnostic journal must be available after painting")
	check(painter.stack.layers[1].masks[0].get_pixel(64, 64).r > 0, "Viewport click must paint target")
	painter._whole_layer(1)
	painter._whole_layer(0)
	check(painter.stack.layers[1].masks[0].get_pixel(64, 64).r > 0.99, "Editor fill must update mask")
	var manager: EditorUndoRedoManager = painter.get_undo_redo()
	var history_id: int = manager.get_object_history_id(painter.stack)
	var history: UndoRedo = manager.get_history_undo_redo(history_id)
	history.undo()
	check(painter.stack.layers[1].masks[0].get_pixel(64, 64).r == 0, "Editor undo must restore mask")
	history.redo()
	check(painter.stack.layers[1].masks[0].get_pixel(64, 64).r > 0.99, "Editor redo must restore mask")
	painter._layer_property(&"opacity", 0.4)
	check(is_equal_approx(painter.stack.layers[1].opacity, 0.4), "Opacity control must work")
	painter._visibility()
	check(not painter.stack.layers[1].enabled, "Layer visibility must work")
	painter._detach()
	check(target.mesh == original and target.get_node_or_null("TexturePaint") == null, "Editor removal must leave original mesh")
	history.undo()
	check(target.get_node_or_null("TexturePaint") != null, "Editor undo must restore removed stack")
	var no_uv := MeshInstance3D.new()
	no_uv.name = "MissingUVFixture"
	var arrays := target.mesh.surface_get_arrays(0)
	arrays[Mesh.ARRAY_TEX_UV] = null
	arrays[Mesh.ARRAY_TANGENT] = null
	var raw := ArrayMesh.new()
	raw.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	no_uv.mesh = raw
	scene.add_child(no_uv)
	no_uv.owner = scene
	painter._edit(no_uv)
	painter.resolution.value = 128
	painter._toggle_paint(true)
	check(painter.painting and painter.stack.paint_mesh != null, "Editor must automatically prepare missing UVs")
	check(raw.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV] == null, "Automatic unwrap must not add UVs to the source")
	painter._file_selected("res://tests/output/fixtures/grass.png")
	painter._whole_layer(0)
	check(painter.stack._proxies.size() == 1, "Automatic UV mesh must render painted overlay")
	check(painter.stack._proxies[0].material_override.get_shader_parameter("mask_uv2") == true, "Generated atlas must use UV2 in shader")
	painter._file_selected("res://tests/output/material-pbr.tres")
	check(painter.stack.layers.size() == 2, "StandardMaterial3D file must be accepted by the texture chooser")
	check(painter.stack.layers[1].normal_map != null and painter.stack.layers[1].ao_map != null, "Material file import must include its PBR maps")
	check(painter.stack.layers[1].roughness_channel == 4, "Material file import must retain channel selection")
	check("hauteur/parallaxe" in painter.status.text, "Unsupported material height must be reported without rejecting PBR maps")
	# Never save the modified demo fixture.
	print("EDITOR RESULT: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func find_painter(node: Node) -> Node:
	var script := node.get_script() as Script
	if script != null and script.resource_path == "res://addons/mesh_texture_painter/plugin.gd":
		return node
	for child in node.get_children(true):
		var result := find_painter(child)
		if result != null:
			return result
	return null
