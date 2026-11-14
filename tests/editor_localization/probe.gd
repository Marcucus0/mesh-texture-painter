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

func has_label(node: Node, text: String) -> bool:
	if node is Label and node.text == text:
		return true
	for child in node.get_children():
		if has_label(child, text):
			return true
	return false

func run() -> void:
	while get_editor_interface().get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	get_editor_interface().open_scene_from_path("res://tests/output/fixtures/island.tscn")
	for frame in 20:
		await get_tree().process_frame
	var painter = find_painter(get_tree().root)
	var french := TranslationServer.get_tool_locale().begins_with("fr")
	check(painter.enable_button.text == ("Activer Texture Paint" if french else "Enable Texture Paint"), "Paint toggle must follow editor locale")
	check(has_label(painter.dock, "Rayon monde" if french else "Radius (world units)"), "Brush label must be translated")
	check(painter.tool.get_item_text(3) == ("Lisser couche" if french else "Smooth layer"), "Tool choices must be translated")
	check("Image, matériau PBR" in painter.dialog.filters[0] if french else "Image, PBR material" in painter.dialog.filters[0], "File filters must be translated")
	# Deliberately set the game to the opposite language.
	TranslationServer.set_locale("en" if french else "fr")
	var scene := get_editor_interface().get_edited_scene_root()
	var target: MeshInstance3D = scene.get_node("Island")
	painter._edit(target)
	painter._toggle_paint(true)
	check(painter.painting, "Painting must still activate")
	painter._file_selected("res://tests/output/fixtures/grass.png")
	check(painter.status.text.begins_with("Texture ajoutée" if french else "Texture added"), "Dynamic import status must follow editor rather than game")
	check(painter.layer_count.text == ("Couches : 1" if french else "Layers: 1"), "Layer count must be translated")
	painter.stack.layers[0].title = "Herbe personnalisée"
	painter._refresh()
	check(painter.layer_list.get_item_text(0) == "Herbe personnalisée", "User-authored layer names must remain unchanged")
	var channel_hint := ""
	for property in painter.stack.layers[0].get_property_list():
		if property.name == "roughness_channel":
			channel_hint = property.hint_string
	check(channel_hint == ("Rouge,Vert,Bleu,Alpha,Gris" if french else "Red,Green,Blue,Alpha,Grayscale"), "Inspector channel names must be translated")
	# Missing UV detection must not depend on a translated error string.
	var missing := MeshInstance3D.new()
	var mesh := ArrayMesh.new()
	var arrays: Array = target.mesh.surface_get_arrays(0)
	arrays[Mesh.ARRAY_TEX_UV] = null
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	missing.mesh = mesh
	scene.add_child(missing)
	painter._edit(missing)
	check(painter._validate().is_empty() and painter.prepared_mesh != null, "Automatic UV generation must work in either language")
	missing.free()
	print("EDITOR LOCALIZATION RESULT: %s, %d checks, %d failures" % ["fr" if french else "en", checks, failures])
	get_tree().quit(1 if failures else 0)
