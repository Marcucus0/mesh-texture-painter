@tool
extends EditorPlugin
var failures := 0
func _enter_tree() -> void:
	call_deferred("run")
func check(value: bool, text: String) -> void:
	if not value:
		failures += 1
		push_error(text)
func run() -> void:
	get_editor_interface().open_scene_from_path("res://tests/output/fixtures/island.tscn")
	for frame in 20:
		await get_tree().process_frame
	var painter := find_painter(get_tree().root)
	if painter == null:
		get_tree().quit(1)
		return
	var scene := get_editor_interface().get_edited_scene_root()
	var target: MeshInstance3D = scene.get_node("Island")
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(target)
	get_editor_interface().edit_node(target)
	painter._edit(target)
	painter.resolution.value = 128
	painter._toggle_paint(true)
	var material_path := OS.get_environment("MTP_TEST_MATERIAL")
	if material_path.is_empty():
		material_path = "res://tests/output/material-pbr.tres"
	painter._file_selected(material_path)
	check(painter.stack.layers.size() == 1, "PBR material fixture must import")
	if painter.stack.layers.is_empty():
		get_tree().quit(1)
		return
	var layer = painter.stack.layers[0]
	check(layer.normal_map != null and layer.roughness_map != null and layer.ao_map != null, "PBR fixture PBR maps must be present")
	check(layer.ao_channel == 4 and layer.roughness_channel == 4, "PBR fixture grayscale channels must be preserved")
	check(painter.I18n.text("hauteur/parallaxe") in painter.status.text, "PBR fixture unsupported height must be reported")
	var viewport := get_editor_interface().get_editor_viewport_3d(0)
	var camera := viewport.get_camera_3d()
	for frame in 8:
		await get_tree().process_frame
	RenderingServer.force_draw()
	var before := viewport.get_texture().get_image()
	var point := camera.unproject_position(Vector3(0.8, 0, 0.8))
	var pixel := Vector2i(point).clamp(Vector2i.ZERO, before.get_size() - Vector2i.ONE)
	var old_color := before.get_pixelv(pixel)
	var old_mode := viewport.render_target_update_mode
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.position = point
	painter._forward_3d_gui_input(camera, press)
	check(painter.dragging, "Press must start a stroke")
	check(viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Editor viewport must render continuously during stroke")
	for tick in 20:
		painter._process(0.05)
		RenderingServer.force_draw()
		await get_tree().process_frame
	check(painter.dragging, "Stroke must still be active before release")
	var during := viewport.get_texture().get_image()
	var new_color := during.get_pixelv(pixel)
	check(Vector3(old_color.r, old_color.g, old_color.b).distance_to(Vector3(new_color.r, new_color.g, new_color.b)) > 0.03, "GPU image must visibly change while button is held")
	var second_point := camera.unproject_position(Vector3(1.5, 0, 0.8))
	var second_pixel := Vector2i(second_point).clamp(Vector2i.ZERO, before.get_size() - Vector2i.ONE)
	var motion := InputEventMouseMotion.new()
	motion.position = second_point
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	painter._forward_3d_gui_input(camera, motion)
	for tick in 20:
		painter._process(0.05)
		RenderingServer.force_draw()
		await get_tree().process_frame
	check(painter.dragging, "Moving with the left button held must keep the stroke active")
	during = viewport.get_texture().get_image()
	var old_second := before.get_pixelv(second_pixel)
	var new_second := during.get_pixelv(second_pixel)
	check(Vector3(old_second.r, old_second.g, old_second.b).distance_to(Vector3(new_second.r, new_second.g, new_second.b)) > 0.03, "GPU must paint the new zone before releasing the moved brush")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output"))
	during.save_png("res://tests/output/live-before-release.png")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	painter._input(release)
	check(not painter.dragging, "Release outside viewport must commit the stroke")
	check(viewport.render_target_update_mode == old_mode, "Viewport update mode must restore after release")
	print("LIVE RESULT: PBR fixture imported, GPU changed before release, ", failures, " failures")
	get_tree().quit(1 if failures else 0)
func find_painter(node: Node) -> Node:
	var script := node.get_script() as Script
	if script != null and str(script.resource_path).ends_with("mesh_texture_painter/plugin.gd"):
		return node
	for child in node.get_children(true):
		var result := find_painter(child)
		if result != null:
			return result
	return null
