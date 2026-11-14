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
	while get_editor_interface().get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	get_editor_interface().open_scene_from_path("res://tests/output/fixtures/island.tscn")
	for frame in 20:
		await get_tree().process_frame
	var painter = find_painter(get_tree().root)
	var target := get_editor_interface().get_edited_scene_root().get_node("Island")
	painter._edit(target)
	painter._toggle_paint(true)
	painter._file_selected("res://tests/output/fixtures/grass.png")
	painter._file_selected("res://tests/output/fixtures/dirt.png")
	var bottom = painter.stack.layers[0]
	var top = painter.stack.layers[1]
	check(painter.layer_list.get_item_icon(0) == top.albedo, "Top composited layer must appear first")
	check(painter.layer_list.is_selected(0), "New layer must be selected at the top")
	check(painter.move_up.get_parent() == painter.move_down.get_parent(), "Move buttons must share a row")
	check(painter.move_up.size_flags_horizontal == Control.SIZE_EXPAND_FILL and painter.move_down.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "Move buttons must split available space equally")
	check(painter.move_up.disabled and not painter.move_down.disabled, "Top layer can only move down")
	painter.layer_list.item_selected.emit(1)
	check(painter.active == 0 and painter.active_preview.texture == bottom.albedo, "UI selection must map to correct stored layer")
	check(not painter.move_up.disabled and painter.move_down.disabled, "Bottom layer can only move up")
	painter.move_up.pressed.emit()
	check(painter.stack.layers[1] == bottom and painter.layer_list.get_item_icon(0) == bottom.albedo, "Move up must move layer upwards in UI and compositing order")
	check(painter.layer_list.is_selected(0), "Moved layer must remain selected")
	var history := get_undo_redo().get_history_undo_redo(get_undo_redo().get_object_history_id(target))
	history.undo()
	# Direct UndoRedo access bypasses the manager's notification in this fixture.
	painter._history_changed()
	for frame in 3:
		await get_tree().process_frame
	check(painter.stack.layers[1] == top and painter.layer_list.get_item_icon(0) == top.albedo, "Undo must restore original layer order")
	var redo := InputEventKey.new()
	redo.keycode = KEY_Y
	redo.ctrl_pressed = true
	redo.pressed = true
	check(get_editor_interface().get_editor_settings().is_shortcut("ui_redo", redo), "Ctrl+Y must match editor redo")
	# Hidden/headless windows do not dispatch the native menu shortcuts. Verify
	# the actual shortcut above, then exercise the scene history it targets.
	history.redo()
	painter._history_changed()
	for frame in 5:
		await get_tree().process_frame
	check(painter.stack.layers[1] == bottom and painter.layer_list.get_item_icon(0) == bottom.albedo, "Redo must restore layer reorder and update UI")
	painter._select_layer_item(0)
	painter.move_down.pressed.emit()
	check(painter.stack.layers[0] == bottom and painter.layer_list.get_item_icon(1) == bottom.albedo, "Move down must lower layer in UI and compositing order")
	check(painter.layer_list.is_selected(1), "Lowered layer must remain selected")
	# Opaque masks activate both passes: the layer shown first must render last.
	for layer in painter.stack.layers:
		var mask: Image = layer.masks[0].duplicate()
		mask.fill(Color.WHITE)
		layer.upload(0, mask)
	painter.stack.rebuild()
	var first: ShaderMaterial = painter.stack._proxies[0].material_override
	check(first.get_shader_parameter("albedo_tex") == bottom.albedo and first.next_pass.get_shader_parameter("albedo_tex") == top.albedo, "Existing bottom-to-top render chain must remain unchanged")
	check(first.render_priority < first.next_pass.render_priority, "UI top must have highest render priority")
	print("LAYER ORDER RESULT: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
