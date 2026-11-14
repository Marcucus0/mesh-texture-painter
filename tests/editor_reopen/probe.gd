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
	if script != null and script.resource_path == "res://addons/mesh_texture_painter/plugin.gd":
		return node
	for child in node.get_children(true):
		var found := find_painter(child)
		if found != null:
			return found
	return null

func run() -> void:
	while get_editor_interface().get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	get_editor_interface().open_scene_from_path("res://reopen.tscn")
	for frame in 20:
		await get_tree().process_frame
	var scene := get_editor_interface().get_edited_scene_root()
	var target: MeshInstance3D = scene.get_node("Island")
	var saved = target.get_node("TexturePaint")
	var painter = find_painter(get_tree().root)
	check(saved.get_script() != painter.Stack, "Fixture must exercise distinct script identities")
	painter._edit(target)
	check(painter.stack == saved, "Selecting reopened mesh must discover original stack")
	check(painter.layer_list.item_count == 1, "Saved layer must appear immediately")
	var snapshot: Array = saved.snapshot()
	for attempt in 3:
		painter._toggle_paint(true)
		check(painter.painting and painter.stack == saved, "Reactivation must retain saved stack")
		painter._toggle_paint(false)
	check(target.get_child_count() == 1, "Reactivation must never add a duplicate")
	check(saved.snapshot() == snapshot, "Activation must not change saved paint")
	painter._toggle_paint(true)
	painter._select_layer(0)
	painter._whole_layer(1)
	check(saved.layers[0].masks[0].get_pixel(32, 32).r == 0, "Saved paint must remain erasable")
	var history := get_undo_redo().get_history_undo_redo(get_undo_redo().get_object_history_id(saved))
	history.undo()
	check(saved.snapshot() == snapshot, "Undo must restore erased saved paint")
	history.redo()
	check(saved.layers[0].masks[0].get_pixel(32, 32).r == 0, "Redo must erase again")
	history.undo()
	painter._file_selected("res://tests/output/fixtures/dirt.png")
	check(saved.layers.size() == 2, "Adding a layer must use saved script resource type")
	var duplicate = painter.Stack.new()
	target.add_child(duplicate)
	painter._edit(null)
	painter._edit(target)
	check(painter.stack == saved, "Painted stack must win over an existing empty duplicate")
	painter._toggle_paint(true)
	check(target.get_child_count() == 2, "Existing duplicates must not multiply")
	print("REOPEN RESULT: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
