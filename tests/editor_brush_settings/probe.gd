@tool
extends EditorPlugin

func _enter_tree() -> void:
	call_deferred("run")

func find_painter(node: Node) -> Node:
	var script := node.get_script() as Script
	if script != null and script.resource_path.to_lower().ends_with("/mesh_texture_painter/plugin.gd"):
		return node
	for child in node.get_children(true):
		var found := find_painter(child)
		if found != null:
			return found
	return null

func run() -> void:
	for frame in 20:
		await get_tree().process_frame
	var painter = find_painter(get_tree().root)
	# Range steps are measured from min_value (radius .001, strength .01).
	var values := {"radius": 12.341, "strength": 7.26, "hardness": 0.67, "falloff": 2.3, "resolution": 1024.0}
	if "--write" in OS.get_cmdline_user_args():
		for key in values:
			painter.get(key).value = values[key]
		painter.tool.select(3)
		painter.tool.item_selected.emit(3)
		painter._save_brush_settings()
		var settings := get_editor_interface().get_editor_settings()
		var data: Dictionary = settings.get_project_metadata("mesh_texture_painter", "brush", {})
		if data.has("tool"):
			push_error("Brush mode must not be persisted")
			get_tree().quit(1)
			return
		# Simulate metadata left by an older plugin version.
		data["tool"] = 4
		settings.set_project_metadata("mesh_texture_painter", "brush", data)
		print("BRUSH SETTINGS: written")
	else:
		var failures := 0
		for key in values:
			if not is_equal_approx(painter.get(key).value, values[key]):
				failures += 1
				push_error("Setting was not restored: " + key)
		if painter.tool.selected != 0:
			failures += 1
			push_error("Brush must start in Add mode even with legacy metadata")
		print("BRUSH SETTINGS: 6 checks, %d failures" % failures)
		get_tree().quit(1 if failures else 0)
		return
	get_tree().quit()
