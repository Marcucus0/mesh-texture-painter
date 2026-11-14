@tool
extends EditorPlugin
func _enter_tree() -> void:
	call_deferred("run")
func run() -> void:
	print("STRESS: initializing")
	get_editor_interface().open_scene_from_path("res://tests/output/fixtures/island.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := get_editor_interface().get_edited_scene_root()
	var painter := find_painter(get_tree().root)
	if painter == null:
		push_error("Stress: painter plugin not found")
		get_tree().quit(1)
		return
	var target: MeshInstance3D = scene.get_node("Island")
	var asset := OS.get_environment("MTP_STRESS_ASSET")
	if not asset.is_empty():
		var imported: Node3D = load("res://stress-island.tscn").instantiate()
		scene.add_child(imported)
		target = find_island(imported)
		if target == null:
			push_error("Stress: island mesh not found")
			get_tree().quit(1)
			return
		scene.get_node("Island").hide()
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(target)
	get_editor_interface().edit_node(target)
	painter._edit(target)
	painter.resolution.value = 512
	painter._toggle_paint(true)
	if not painter.painting:
		if RenderingServer.get_current_rendering_driver_name() == "d3d12" and "Direct3D 12" in painter.status.text:
			print("STRESS GUARD RESULT: D3D12/Intel blocked before painting")
			get_tree().quit()
		else:
			push_error("Stress: paint activation failed: " + painter.status.text)
			get_tree().quit(1)
		return
	painter._file_selected("res://tests/output/fixtures/grass.png")
	painter._file_selected("res://tests/output/fixtures/dirt.png")
	painter.set_process(false)
	var camera: Camera3D = get_editor_interface().get_editor_viewport_3d(0).get_camera_3d()
	var center := target.to_global(target.mesh.get_aabb().get_center())
	var extent := maxf((target.global_basis * target.mesh.get_aabb().size).length(), 1)
	camera.global_position = center + Vector3(0.6, 0.8, 0.7) * extent
	camera.look_at(center, Vector3.UP)
	painter.radius.value = extent * 0.06
	for frame in 10:
		await get_tree().process_frame
	painter._edit(target)
	painter._toggle_paint(true)
	print("STRESS: start ", RenderingServer.get_video_adapter_name(), " triangles ", painter.geometry.triangles.size())
	for stroke in 8:
		painter.active = stroke % 2
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = camera.unproject_position(center)
		painter._forward_3d_gui_input(camera, press)
		if not painter.dragging:
			push_error("Stress test did not start a paint stroke")
			get_tree().quit(1)
			return
		for step in 30:
			var position := camera.unproject_position(center + Vector3(sin(step * 0.2) * extent * 0.05, 0, cos(step * 0.2) * extent * 0.05))
			var motion := InputEventMouseMotion.new()
			motion.button_mask = MOUSE_BUTTON_MASK_LEFT
			motion.position = position
			painter._forward_3d_gui_input(camera, motion)
			painter._advance_brush(0.05)
			painter.update_overlays()
			await get_tree().process_frame
		painter._finish_stroke()
		print("STRESS: stroke ", stroke + 1)
		for frame in 2:
			await get_tree().process_frame
	print("STRESS RESULT: 8 strokes, 240 moving stamps, success")
	get_tree().quit()
func find_painter(node: Node) -> Node:
	var script := node.get_script() as Script
	if script != null and str(script.resource_path).ends_with("mesh_texture_painter/plugin.gd"):
		return node
	for child in node.get_children(true):
		var result := find_painter(child)
		if result != null:
			return result
	return null
func find_island(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.mesh != null and node.mesh.get_surface_count() == 7:
		return node
	for child in node.get_children():
		var result := find_island(child)
		if result != null:
			return result
	return null
