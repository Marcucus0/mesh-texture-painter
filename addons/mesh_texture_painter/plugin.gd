@tool
extends EditorPlugin
const I18n = preload("localization.gd")

const Stack = preload("stack.gd")
const Geometry = preload("geometry.gd")
const Layer = preload("layer.gd")
const PaintUV = preload("paint_uv.gd")
var prepared_mesh: ArrayMesh
var dock: VBoxContainer
var editor_dock: EditorDock
var status: Label
var layer_list: ItemList
var layer_count: Label
var empty_layers: Label
var active_preview: TextureRect
var active_caption: Label
var _import_target: WeakRef
var _import_stack: WeakRef
var _import_was_painting := false
var enable_button: CheckButton
var radius: SpinBox
var strength: SpinBox
var hardness: SpinBox
var falloff: SpinBox
var resolution: SpinBox
var opacity: SpinBox
var transition: SpinBox
var scale_uv: SpinBox
var tool: OptionButton
var dialog: EditorFileDialog
var save_dialog: EditorFileDialog
var target: MeshInstance3D
# A saved scene can reference res://Addons while the plugin was enabled under
# res://addons on Windows. These are distinct GDScript identities in Godot.
var stack: Variant
var geometry: RefCounted
var scene_bvh: TriangleMesh
var active := -1
var painting := false
var dragging := false
var before: Array = []
var images: Array = []
var last_camera: Camera3D
var mouse := Vector2.ZERO
var previous_mouse := Vector2.ZERO
var hit_point := Vector3.ZERO
var hit_normal := Vector3.UP
var has_hit := false
var elapsed := 0.0
var updating := false
var _stamp_count := 0
var _ending_stroke := false
var _brush_pressed := false
var _stroke_viewport: WeakRef
var _previous_viewport_mode: int = SubViewport.UPDATE_WHEN_VISIBLE
var _pending_uploads: Dictionary = {}
var move_up: Button
var move_down: Button
var _redo_shortcut: Shortcut
var _redo_event: InputEventKey

func _enter_tree() -> void:
	I18n.set_editor_locale(TranslationServer.get_tool_locale())
	_install_redo_shortcut()
	dock = VBoxContainer.new()
	# Explicit private-domain translations must not use the game's locale.
	dock.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	dock.name = "Texture Paint"
	dock.custom_minimum_size.x = 280
	var heading := Label.new()
	heading.text = "Mesh Texture Paint · 1.0"
	dock.add_child(heading)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(status)
	enable_button = CheckButton.new()
	enable_button.text = I18n.text("Activer Texture Paint")
	enable_button.toggled.connect(_toggle_paint)
	dock.add_child(enable_button)
	resolution = _spin(I18n.text("Résolution (avant ajout)"), 128, 2048, 128, 512)
	layer_count = Label.new()
	layer_count.text = I18n.text("Couches : 0")
	dock.add_child(layer_count)
	empty_layers = Label.new()
	empty_layers.text = I18n.text("Aucune texture ajoutée. Cliquez sur Ajouter texture.")
	empty_layers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(empty_layers)
	layer_list = ItemList.new()
	layer_list.custom_minimum_size = Vector2(260, 160)
	layer_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layer_list.icon_mode = ItemList.ICON_MODE_LEFT
	layer_list.fixed_icon_size = Vector2i(48, 48)
	layer_list.item_selected.connect(_select_layer_item)
	dock.add_child(layer_list)
	var preview_row := HBoxContainer.new()
	active_preview = TextureRect.new()
	active_preview.custom_minimum_size = Vector2(64, 64)
	active_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	active_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_row.add_child(active_preview)
	active_caption = Label.new()
	active_caption.text = I18n.text("Aucune couche sélectionnée")
	active_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_row.add_child(active_caption)
	dock.add_child(preview_row)
	_button(I18n.text("Ajouter image / matériau .tres"), _choose_texture)
	_button(I18n.text("Supprimer la couche"), _remove_layer)
	_button(I18n.text("Afficher / masquer la couche"), _visibility)
	var reorder_row := HBoxContainer.new()
	dock.add_child(reorder_row)
	move_up = Button.new()
	move_down = Button.new()
	for button: Button in [move_up, move_down]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		reorder_row.add_child(button)
	move_up.text = I18n.text("Monter la couche")
	move_down.text = I18n.text("Descendre la couche")
	move_up.pressed.connect(_move_layer.bind(1))
	move_down.pressed.connect(_move_layer.bind(-1))
	_button(I18n.text("Propriétés PBR (inspecteur)"), _inspect_layer)
	_button(I18n.text("Enregistrer en bibliothèque .tres"), _save_preset)
	opacity = _spin(I18n.text("Opacité couche"), 0, 1, 0.01, 1)
	transition = _spin(I18n.text("Transition (exposant)"), 0.1, 4, 0.05, 1)
	scale_uv = _spin(I18n.text("Échelle UV couche"), 0.01, 100, 0.1, 1)
	opacity.value_changed.connect(func(value: float): _layer_property(&"opacity", value))
	transition.value_changed.connect(func(value: float): _layer_property(&"transition", value))
	scale_uv.value_changed.connect(func(value: float): _layer_property(&"uv_scale", Vector2.ONE * value))
	tool = OptionButton.new()
	for text in [I18n.text("Ajouter"), I18n.text("Remplacer les couches"), I18n.text("Effacer couche"), I18n.text("Lisser couche"), I18n.text("Restaurer original")]:
		tool.add_item(text)
	dock.add_child(tool)
	radius = _spin(I18n.text("Rayon monde"), 0.001, 100, 0.01, 0.5)
	strength = _spin(I18n.text("Intensité par seconde"), 0.01, 20, 0.05, 4)
	hardness = _spin(I18n.text("Dureté"), 0, 1, 0.01, 0.3)
	falloff = _spin(I18n.text("Falloff (exposant)"), 0.1, 8, 0.1, 1)
	_restore_brush_settings()
	for control: SpinBox in [radius, strength, hardness, falloff, resolution]:
		control.value_changed.connect(_save_brush_settings)
	_button(I18n.text("Remplir couche"), func(): _whole_layer(0))
	_button(I18n.text("Réinitialiser couche"), func(): _whole_layer(1))
	_button(I18n.text("Inverser masque"), func(): _whole_layer(2))
	_button(I18n.text("Désactiver / réactiver le rendu"), _toggle_render)
	_button(I18n.text("Retirer le système (réversible)"), _detach)
	var tip := Label.new()
	tip.text = I18n.text("Clic gauche maintenu : peindre · Alt : navigation\nCtrl+Z / Ctrl+Y : historique éditeur\nUV automatiques si nécessaire · mesh statique opaque\n32 couches/objet ; 2–8 recommandées.")
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(tip)
	var scroll := ScrollContainer.new()
	scroll.name = "Texture Paint"
	scroll.add_child(dock)
	dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_dock = EditorDock.new()
	editor_dock.title = "Texture Paint"
	editor_dock.layout_key = "MeshTexturePainter"
	editor_dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_UL
	editor_dock.add_child(scroll)
	add_dock(editor_dock)
	dialog = EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.filters = PackedStringArray([I18n.text("*.png,*.jpg,*.jpeg,*.webp,*.svg,*.tres,*.res ; Image, matériau PBR ou couche")])
	dialog.file_selected.connect(_file_selected)
	dialog.canceled.connect(_cancel_texture_import)
	dock.add_child(dialog)
	save_dialog = EditorFileDialog.new()
	save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	save_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	save_dialog.filters = PackedStringArray([I18n.text("*.tres ; Bibliothèque TexturePaintLayer")])
	save_dialog.file_selected.connect(_write_preset)
	dock.add_child(save_dialog)
	get_editor_interface().get_inspector().property_edited.connect(_inspector_edited)
	get_undo_redo().version_changed.connect(_history_changed)
	set_input_event_forwarding_always_enabled()
	set_process(true)
	set_process_input(true)
	get_editor_interface().get_base_control().get_window().focus_exited.connect(_finish_stroke)
	_status(I18n.text("Sélectionnez un MeshInstance3D statique. Les UV manquants sont générés automatiquement."))

func _exit_tree() -> void:
	_finish_stroke()
	if _redo_shortcut != null and _redo_event != null:
		var events := _redo_shortcut.events
		events.erase(_redo_event)
		_redo_shortcut.events = events
	if is_instance_valid(editor_dock):
		remove_dock(editor_dock)
		editor_dock.queue_free()

func _install_redo_shortcut() -> void:
	# Use Godot's own redo command so scene/global history routing is preserved.
	_redo_shortcut = get_editor_interface().get_editor_settings().get_shortcut("ui_redo")
	var event := InputEventKey.new()
	event.keycode = KEY_Y
	event.ctrl_pressed = true
	if _redo_shortcut != null and not _redo_shortcut.matches_event(event):
		_redo_event = event
		var events := _redo_shortcut.events
		events.append(event)
		_redo_shortcut.events = events

func _restore_brush_settings() -> void:
	# Never restore an erasing/replacing tool from an earlier editor session.
	tool.select(0)
	var settings = get_editor_interface().get_editor_settings().get_project_metadata("mesh_texture_painter", "brush", {})
	if not settings is Dictionary:
		return
	for key in ["radius", "strength", "hardness", "falloff", "resolution"]:
		var value = settings.get(key)
		if (value is float or value is int) and is_finite(float(value)):
			var control: SpinBox = get(key)
			control.set_value_no_signal(float(value))

func _save_brush_settings(_value: Variant = null) -> void:
	# Project-local editor metadata, independent of scene and addon replacement.
	get_editor_interface().get_editor_settings().set_project_metadata("mesh_texture_painter", "brush", {
		"radius": radius.value, "strength": strength.value,
		"hardness": hardness.value, "falloff": falloff.value,
		"resolution": resolution.value,
	})

func _handles(object: Object) -> bool:
	return object is MeshInstance3D

static func _uses_script(object: Object, expected: Script) -> bool:
	if not is_instance_valid(object):
		return false
	var script: Script = object.get_script()
	return script != null and (script == expected or script.resource_path.simplify_path().to_lower() == expected.resource_path.simplify_path().to_lower())

func _find_stack() -> Variant:
	if not is_instance_valid(target):
		return null
	var found: Variant = null
	for child in target.get_children():
		if _uses_script(child, Stack):
			# Prefer the saved stack containing paint over an accidental empty one.
			if found == null or (found.layers.is_empty() and not child.layers.is_empty()):
				found = child
	return found

func _edit(object: Object) -> void:
	if is_instance_valid(target) and object == target:
		return
	if object == null and is_instance_valid(target) and get_editor_interface().get_selection().get_selected_nodes().has(target):
		return
	_finish_stroke()
	prepared_mesh = null
	painting = false
	enable_button.set_pressed_no_signal(false)
	target = object as MeshInstance3D
	stack = null
	if is_instance_valid(target):
		stack = _find_stack()
		if stack != null:
			active = stack.layers.size() - 1
			_status(I18n.text("%s : peinture sauvegardée retrouvée (%d couches). Activez le mode pour continuer.") % [target.name, stack.layers.size()])
		else:
			_status(I18n.text("%s : activez le mode pour vérifier les UV.") % target.name)
	_refresh()

func _spin(text: String, low: float, high: float, step: float, value: float) -> SpinBox:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.value = value
	row.add_child(spin)
	dock.add_child(row)
	return spin

func _button(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	dock.add_child(button)

func _status(text: String, is_error: bool = false) -> void:
	status.text = text
	if is_error:
		status.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	else:
		status.remove_theme_color_override("font_color")

func _validate() -> String:
	var backend_error := Stack.backend_issue()
	if not backend_error.is_empty():
		return backend_error
	for dependency: Script in [Stack, Geometry, Layer, PaintUV]:
		if not dependency.can_instantiate():
			return I18n.text("Script non compilé : %s. Consultez la première erreur dans Sortie et relancez Godot après mise à jour du plugin.") % dependency.resource_path
	if not is_instance_valid(target) or target.mesh == null:
		return I18n.text("Sélectionnez un MeshInstance3D avec mesh.")
	if target.skin != null or not target.skeleton.is_empty() and target.get_node_or_null(target.skeleton) is Skeleton3D:
		return I18n.text("Squelettes non pris en charge : utilisez un mesh statique.")
	if target.mesh is ArrayMesh and target.mesh.get_blend_shape_count() > 0:
		return I18n.text("Blend shapes non pris en charge.")
	if target.material_overlay != null:
		return I18n.text("Material Overlay existant : combinaison non prise en charge.")
	for s in target.mesh.get_surface_count():
		var material := target.get_active_material(s)
		if material == null:
			continue
		if not material is StandardMaterial3D and not material is ORMMaterial3D:
			return I18n.text("Surface %d : matériau personnalisé non pris en charge.") % s
		if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or material.next_pass != null:
			return I18n.text("Surface %d : transparence ou next_pass non pris en charge.") % s
		if material.grow or material.proximity_fade_enabled or material.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED:
			return I18n.text("Surface %d : déplacement/fondu du matériau incompatible.") % s
	if is_instance_valid(stack) and not stack.mesh_signature.is_empty() and stack.mesh_signature != Stack.fingerprint(target.mesh):
		return I18n.text("Géométrie/UV modifiés après peinture. Restaurez le mesh ou retirez le système pour recommencer.")
	geometry = Geometry.new()
	prepared_mesh = stack.paint_mesh if is_instance_valid(stack) and stack.is_inside_tree() else null
	if prepared_mesh != null:
		if not geometry.build(prepared_mesh, Mesh.ARRAY_TEX_UV2):
			return geometry.error
		return ""
	var valid: bool = geometry.build(target.mesh)
	if not valid and not geometry.needs_uv_generation:
		return geometry.error
	if not valid or geometry.overlapping_uvs():
		_status(I18n.text("Création automatique des UV de peinture…"))
		var unwrapper := PaintUV.new()
		prepared_mesh = unwrapper.generate(target.mesh)
		if prepared_mesh == null:
			return unwrapper.error
		if not geometry.build(prepared_mesh, Mesh.ARRAY_TEX_UV2):
			return geometry.error
	return ""

func _toggle_paint(value: bool) -> void:
	_finish_stroke()
	painting = false
	if not value:
		return
	stack = _find_stack()
	var issue := _validate()
	if not issue.is_empty():
		_status(issue, true)
		enable_button.set_pressed_no_signal(false)
		return
	# Prepare immutable world geometry when activating, rather than on first dab.
	geometry.prepare_world(target.global_transform, stack.resolution if is_instance_valid(stack) else int(resolution.value))
	if not is_instance_valid(stack) or not stack.is_inside_tree():
		stack = Stack.new()
		stack.name = "TexturePaint"
		stack.resolution = int(resolution.value)
		stack.paint_mesh = prepared_mesh
		var history := get_undo_redo()
		history.create_action(I18n.text("Ajouter Texture Paint"), UndoRedo.MERGE_DISABLE, target)
		history.add_do_method(target, "add_child", stack)
		history.add_do_property(stack, "owner", get_editor_interface().get_edited_scene_root())
		history.add_do_reference(stack)
		history.add_undo_method(target, "remove_child", stack)
		history.commit_action()
	_build_scene_bvh()
	painting = true
	_status(I18n.text("Prêt · %d triangles · %s · base conservée. Ajoutez une texture.") % [geometry.triangles.size(), I18n.text("UV automatiques") if prepared_mesh != null else "UV1"])
	_refresh()

func _build_scene_bvh() -> void:
	var faces := PackedVector3Array()
	_collect_faces(get_editor_interface().get_edited_scene_root(), faces)
	scene_bvh = TriangleMesh.new()
	if not faces.is_empty():
		scene_bvh.create_from_faces(faces)

func _collect_faces(node: Node, faces: PackedVector3Array) -> void:
	if _uses_script(node, Stack):
		return
	if node is MeshInstance3D and node.mesh != null and node.is_visible_in_tree():
		var local_faces: PackedVector3Array = node.mesh.get_faces()
		for vertex in local_faces:
			faces.append(node.global_transform * vertex)
	for child in node.get_children():
		_collect_faces(child, faces)

func _history_changed() -> void:
	if not dragging and is_instance_valid(stack) and stack.is_inside_tree():
		stack.call_deferred("rebuild")
	if is_instance_valid(dock):
		call_deferred("_refresh")

func _refresh() -> void:
	if is_instance_valid(target):
		stack = _find_stack()
	layer_list.clear()
	active_preview.texture = null
	active_caption.text = I18n.text("Aucune couche sélectionnée")
	layer_count.text = I18n.text("Couches : 0")
	empty_layers.visible = true
	move_up.disabled = true
	move_down.disabled = true
	if not is_instance_valid(stack) or not stack.is_inside_tree():
		active = -1
		return
	resolution.set_value_no_signal(stack.resolution)
	layer_count.text = I18n.text("Couches : %d") % stack.layers.size()
	empty_layers.visible = stack.layers.is_empty()
	# Storage/render order stays unchanged to preserve existing saved paintings.
	# The UI presents the last composited (topmost) layer first.
	for layer_index in range(stack.layers.size() - 1, -1, -1):
		var layer = stack.layers[layer_index]
		var index := layer_list.add_item(("" if layer.enabled else I18n.text("[masquée] ")) + layer.title, layer.albedo)
		layer_list.set_item_tooltip(index, layer.albedo.resource_path if layer.albedo != null else I18n.text("Texture albedo absente"))
	active = clampi(active, -1, stack.layers.size() - 1)
	if active >= 0:
		layer_list.select(stack.layers.size() - 1 - active)
		layer_list.ensure_current_is_visible()
		_update_layer_controls()
	_update_move_buttons()

func _select_layer_item(index: int) -> void:
	if is_instance_valid(stack):
		_select_layer(stack.layers.size() - 1 - index)

func _update_move_buttons() -> void:
	move_up.disabled = not _has_layer() or active >= stack.layers.size() - 1
	move_down.disabled = not _has_layer() or active <= 0

func _select_layer(index: int) -> void:
	_finish_stroke()
	active = index
	_update_layer_controls()
	_update_move_buttons()

func _update_layer_controls() -> void:
	if not _has_layer():
		return
	active_preview.texture = stack.layers[active].albedo
	active_caption.text = I18n.text("Couche active : %s") % stack.layers[active].title
	updating = true
	opacity.value = stack.layers[active].opacity
	transition.value = stack.layers[active].transition
	scale_uv.value = stack.layers[active].uv_scale.x
	updating = false

func _has_layer() -> bool:
	return is_instance_valid(stack) and stack.is_inside_tree() and active >= 0 and active < stack.layers.size()

func _choose_texture() -> void:
	if not _begin_texture_import():
		return
	_status(I18n.text("Choisissez une image, un matériau Standard/ORM .tres ou un préréglage de couche."))
	dialog.popup_centered_ratio(0.65)

func _begin_texture_import() -> bool:
	if not is_instance_valid(stack) or not stack.is_inside_tree():
		_status(I18n.text("Ajout impossible : activez Texture Paint sur un mesh avant d'ajouter une texture."), true)
		return false
	_import_target = weakref(target)
	_import_stack = weakref(stack)
	_import_was_painting = painting
	return true

func _cancel_texture_import() -> void:
	_import_target = null
	_import_stack = null
	_status(I18n.text("Ajout de texture annulé."))

func _file_selected(path: String) -> void:
	editor_dock.call_deferred("make_visible")
	# Browsing resources may clear EditorPlugin._edit's current object. Keep the
	# mesh chosen when opening this dialog, rather than silently dropping its file.
	if _import_target != null:
		var destination = _import_target.get_ref()
		var destination_stack = _import_stack.get_ref() if _import_stack != null else null
		var resume := _import_was_painting
		_import_target = null
		_import_stack = null
		var scene := get_editor_interface().get_edited_scene_root()
		if not is_instance_valid(destination) or not is_instance_valid(destination_stack) or scene == null or not scene.is_ancestor_of(destination_stack):
			_status(I18n.text("Ajout impossible : le mesh ou sa scène a été fermé. Sélectionnez le mesh puis recommencez."), true)
			return
		if target != destination or stack != destination_stack:
			_edit(destination)
			if resume:
				_toggle_paint(true)
	if not is_instance_valid(stack) or not stack.is_inside_tree():
		_status(I18n.text("Ajout impossible : aucun système Texture Paint actif sur le mesh sélectionné."), true)
		return
	if stack.layers.size() >= Stack.MAX_LAYERS:
		_status(I18n.text("Ajout impossible : limite de 32 couches atteinte sur cet objet."), true)
		return
	_status(I18n.text("Chargement de %s…") % path.get_file())
	if not ResourceLoader.exists(path):
		_status(I18n.text("Texture introuvable ou non importée : %s") % path, true)
		return
	var resource := ResourceLoader.load(path)
	if resource == null:
		_status(I18n.text("Échec du chargement : %s. Consultez les erreurs d'import Godot.") % path.get_file(), true)
		return
	var layer: Variant
	var notice := ""
	if resource is Texture2D:
		layer = stack.make_layer(resource)
	elif _uses_script(resource, Layer) and resource.albedo != null:
		layer = stack.make_layer(resource.albedo)
		for property in Layer.SETTINGS:
			layer.set(property, resource.get(property))
	elif resource is StandardMaterial3D or resource is ORMMaterial3D:
		layer = stack.make_material_layer(resource)
		var omitted := PackedStringArray()
		if resource.heightmap_enabled:
			omitted.append(I18n.text("hauteur/parallaxe"))
		if resource.uv1_triplanar:
			omitted.append(I18n.text("projection triplanaire"))
		if resource.emission_enabled:
			omitted.append(I18n.text("émission"))
		if resource.detail_enabled:
			omitted.append(I18n.text("détail secondaire"))
		if resource.next_pass != null:
			omitted.append(I18n.text("passes supplémentaires"))
		notice = I18n.text(" Cartes PBR importées.")
		if not omitted.is_empty():
			notice += I18n.text(" Non repris : %s.") % ", ".join(omitted)
	else:
		_status(I18n.text("Fichier refusé : %s (%s). Choisissez une image, un matériau Standard/ORM ou une couche avec albedo.") % [path.get_file(), resource.get_class()], true)
		return
	if layer.title.strip_edges().is_empty():
		layer.title = path.get_file().get_basename()
	var next: Array = stack.layers.duplicate()
	next.append(layer)
	_change_layers(I18n.text("Ajouter une couche"), next)
	active = stack.layers.size() - 1
	_refresh()
	_status(I18n.text("Texture ajoutée : %s · %d couche(s). Couche sélectionnée, prête à peindre.%s") % [layer.title, stack.layers.size(), notice])

func _change_layers(title: String, next: Array) -> void:
	_finish_stroke()
	var history := get_undo_redo()
	history.create_action(title, UndoRedo.MERGE_DISABLE, stack)
	history.add_do_method(stack, "set_layers", next)
	history.add_undo_method(stack, "set_layers", stack.layers.duplicate())
	history.commit_action()
	_refresh()

func _remove_layer() -> void:
	if _has_layer():
		var next: Array = stack.layers.duplicate()
		next.remove_at(active)
		_change_layers(I18n.text("Supprimer couche"), next)

func _move_layer(direction: int = 1) -> void:
	if _has_layer() and active + direction >= 0 and active + direction < stack.layers.size():
		var next: Array = stack.layers.duplicate()
		var layer = next.pop_at(active)
		next.insert(active + direction, layer)
		_change_layers(I18n.text("Déplacer couche"), next)
		active += direction
		_refresh()

func _visibility() -> void:
	if _has_layer():
		_layer_property(&"enabled", not stack.layers[active].enabled)
		_refresh()

func _layer_property(property: StringName, value: Variant) -> void:
	if updating or not _has_layer():
		return
	_finish_stroke()
	var history := get_undo_redo()
	history.create_action(I18n.text("Modifier couche %d : %s") % [active + 1, property], UndoRedo.MERGE_ENDS, stack)
	history.add_do_method(stack, "set_layer_value", active, property, value)
	history.add_undo_method(stack, "set_layer_value", active, property, stack.layers[active].get(property))
	history.commit_action()

func _inspect_layer() -> void:
	if _has_layer():
		get_editor_interface().inspect_object(stack.layers[active])

func _inspector_edited(_property: StringName) -> void:
	if is_instance_valid(stack) and stack.is_inside_tree():
		stack.call_deferred("rebuild")

func _save_preset() -> void:
	if _has_layer():
		save_dialog.popup_centered_ratio(0.65)

func _write_preset(path: String) -> void:
	if not _has_layer():
		return
	var preset: Resource = stack.layers[active].duplicate()
	preset.masks = []
	var error := ResourceSaver.save(preset, path)
	_status(I18n.text("Bibliothèque enregistrée : ") + path if error == OK else I18n.text("Échec sauvegarde : %d") % error)
	get_editor_interface().get_resource_filesystem().scan()

func _whole_layer(mode: int) -> void:
	if not _has_layer():
		return
	_finish_stroke()
	before = stack.snapshot()
	for surface in stack.layers[active].masks.size():
		var mask: Image = stack.layers[active].masks[surface]
		var image: Image = mask.duplicate()
		if mode < 2:
			image.fill(Color.WHITE if mode == 0 else Color(0, 0, 0, 1))
		else:
			for y in image.get_height():
				for x in image.get_width():
					var value := 1.0 - image.get_pixel(x, y).r
					image.set_pixel(x, y, Color(value, value, value, 1))
		stack.layers[active].upload(surface, image)
	_commit_snapshot(I18n.text("Modifier masque entier"))

func _toggle_render() -> void:
	if is_instance_valid(stack):
		_finish_stroke()
		var history := get_undo_redo()
		history.create_action(I18n.text("Activer rendu peinture"), UndoRedo.MERGE_DISABLE, stack)
		history.add_do_property(stack, "painting_enabled", not stack.painting_enabled)
		history.add_do_method(stack, "rebuild")
		history.add_undo_property(stack, "painting_enabled", stack.painting_enabled)
		history.add_undo_method(stack, "rebuild")
		history.commit_action()

func _detach() -> void:
	if not is_instance_valid(stack) or not stack.is_inside_tree():
		return
	_toggle_paint(false)
	enable_button.set_pressed_no_signal(false)
	var history := get_undo_redo()
	history.create_action(I18n.text("Retirer Texture Paint"), UndoRedo.MERGE_DISABLE, target)
	history.add_do_method(target, "remove_child", stack)
	history.add_undo_method(target, "add_child", stack)
	history.add_undo_property(stack, "owner", get_editor_interface().get_edited_scene_root())
	history.add_undo_reference(stack)
	history.commit_action()
	_refresh()

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if not painting or not is_instance_valid(target) or not is_instance_valid(stack) or not stack.is_inside_tree():
		return AFTER_GUI_INPUT_PASS
	last_camera = camera
	if event is InputEventMouse:
		mouse = event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.alt_pressed:
			return AFTER_GUI_INPUT_PASS
		if event.pressed and _has_layer() and stack.painting_enabled and stack.layers[active].enabled:
			if dragging:
				return AFTER_GUI_INPUT_STOP
			_stamp_count = 0
			_trace_stroke("begin")
			before = stack.snapshot()
			images.clear()
			for layer in stack.layers:
				var surface_images: Array = []
				for mask in layer.masks:
					surface_images.append(mask.duplicate())
				images.append(surface_images)
			dragging = true
			_brush_pressed = true
			_start_live_preview(camera)
			stack.begin_stroke()
			_trace_stroke("preview_ready")
			previous_mouse = mouse
			_stamp(mouse, 0.05)
		elif not event.pressed:
			_brush_pressed = false
			_finish_stroke()
		return AFTER_GUI_INPUT_STOP
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or (event.ctrl_pressed and event.keycode in [KEY_Z, KEY_Y])):
		_finish_stroke()
		return AFTER_GUI_INPUT_STOP if event.keycode == KEY_ESCAPE else AFTER_GUI_INPUT_PASS
	if dragging and event is InputEventMouseMotion:
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_brush_pressed = false
			_finish_stroke()
		return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS

func _input(event: InputEvent) -> void:
	# Capture release even if the pointer has left the 3D viewport.
	if dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_brush_pressed = false
		_finish_stroke()

func _start_live_preview(camera: Camera3D) -> void:
	var viewport := camera.get_viewport() as SubViewport
	if viewport != null:
		_stroke_viewport = weakref(viewport)
		_previous_viewport_mode = viewport.render_target_update_mode
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _restore_live_preview() -> void:
	if _stroke_viewport != null:
		var viewport = _stroke_viewport.get_ref()
		if is_instance_valid(viewport):
			viewport.render_target_update_mode = _previous_viewport_mode
	_stroke_viewport = null

func _process(delta: float) -> void:
	if not painting or not is_instance_valid(last_camera) or not is_instance_valid(stack) or not stack.is_inside_tree():
		return
	elapsed += delta
	if elapsed < 0.05:
		return
	var dt := minf(elapsed, 0.1)
	elapsed = 0.0
	_update_hit(mouse)
	update_overlays()
	if dragging:
		# Editor-forwarded mouse state is authoritative; game Input state can
		# report the button as released while the editor has captured it.
		if not _brush_pressed:
			_finish_stroke()
			return
		if not last_camera.get_viewport().get_visible_rect().has_point(mouse):
			return
		_advance_brush(dt)

func _advance_brush(dt: float) -> void:
	if not dragging:
		return
	var count := clampi(int(previous_mouse.distance_to(mouse) / 5.0) + 1, 1, 24)
	var start := previous_mouse
	var started := Time.get_ticks_usec()
	for step in mini(count, 3):
		previous_mouse = start.lerp(mouse, float(step + 1) / count)
		_stamp(previous_mouse, dt / count, true)
		if Time.get_ticks_usec() - started >= 8000:
			break
	_flush_paint_uploads()

func _update_hit(position: Vector2) -> void:
	has_hit = false
	if not is_instance_valid(last_camera) or not is_instance_valid(target) or geometry == null:
		return
	if absf(target.global_basis.determinant()) < 0.000000000001:
		return
	var origin := last_camera.project_ray_origin(position)
	var direction := last_camera.project_ray_normal(position)
	var result: Dictionary = geometry.hit(target, origin, direction)
	has_hit = not result.is_empty()
	if has_hit:
		if scene_bvh != null:
			var nearest := scene_bvh.intersect_ray(origin, direction)
			if not nearest.is_empty() and origin.distance_to(nearest.position) + 0.001 < origin.distance_to(result.position):
				has_hit = false
		hit_point = result.position
		hit_normal = result.normal

func _stamp(position: Vector2, delta: float, defer_uploads: bool = false) -> void:
	_update_hit(position)
	if not has_hit or not _has_layer():
		return
	if images.size() != stack.layers.size() or images[active].size() != stack.layers[active].masks.size():
		return
	_stamp_count += 1
	if _stamp_count == 1 or _stamp_count % 20 == 0:
		_trace_stroke("raster")
	var mode := tool.selected
	var amount := 1.0 - exp(-strength.value * delta)
	var dirty: Dictionary = {}
	if mode == 4:
		for i in images.size():
			dirty[i] = geometry.dab(target, images[i], hit_point, last_camera, radius.value, amount, hardness.value, falloff.value, 4)
	else:
		dirty[active] = geometry.dab(target, images[active], hit_point, last_camera, radius.value, amount, hardness.value, falloff.value, mode)
		if mode == 1:
			for i in images.size():
				if i != active:
					dirty[i] = geometry.dab(target, images[i], hit_point, last_camera, radius.value, amount, hardness.value, falloff.value, 2)
	if _stamp_count == 1 or _stamp_count % 20 == 0:
		_trace_stroke("upload")
	for i in dirty:
		for surface in dirty[i]:
			_pending_uploads[Vector2i(i, surface)] = true
	if not defer_uploads:
		_flush_paint_uploads()
	if _stamp_count == 1 or _stamp_count % 20 == 0:
		_trace_stroke("uploaded")

func _flush_paint_uploads() -> void:
	if _pending_uploads.is_empty():
		return
	for key: Vector2i in _pending_uploads:
		stack.layers[key.x].upload(key.y, images[key.x][key.y])
	_pending_uploads.clear()
	update_overlays()
	get_editor_interface().get_base_control().queue_redraw()

func _finish_stroke() -> void:
	if not dragging or _ending_stroke:
		return
	_ending_stroke = true
	_flush_paint_uploads()
	dragging = false
	_brush_pressed = false
	_restore_live_preview()
	_trace_stroke("commit")
	if is_instance_valid(stack) and stack.is_inside_tree():
		stack.end_stroke()
		_commit_snapshot(I18n.text("Peindre texture"))
	images.clear()
	_ending_stroke = false
	_trace_stroke("end")

func _trace_stroke(stage: String) -> void:
	# Local bounded journal survives a native editor crash. No scene data is sent.
	var path := "res://.godot/mesh_texture_painter.log"
	var log_file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if log_file == null:
		return
	if log_file.get_length() > 262144:
		log_file.close()
		log_file = FileAccess.open(path, FileAccess.WRITE)
		if log_file == null:
			return
	log_file.seek_end()
	log_file.store_line(JSON.stringify({"time": Time.get_datetime_string_from_system(), "stage": stage, "stamp": _stamp_count, "radius": radius.value, "layers": stack.layers.size() if is_instance_valid(stack) else 0, "resolution": stack.resolution if is_instance_valid(stack) else 0}))
	log_file.flush()

func _commit_snapshot(title: String) -> void:
	var after: Array = stack.snapshot()
	if after != before:
		var history := get_undo_redo()
		history.create_action(title, UndoRedo.MERGE_DISABLE, stack)
		history.add_do_method(stack, "restore_snapshot", after)
		history.add_undo_method(stack, "restore_snapshot", before)
		history.commit_action(false)
	stack.rebuild()
	before = []

func _forward_3d_draw_over_viewport(control: Control) -> void:
	if not painting or not has_hit or not is_instance_valid(last_camera):
		return
	var tangent := hit_normal.cross(Vector3.UP)
	if tangent.length_squared() < 0.01:
		tangent = hit_normal.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent := hit_normal.cross(tangent).normalized()
	var points := PackedVector2Array()
	for i in 65:
		var angle := TAU * i / 64.0
		var point := hit_point + (tangent * cos(angle) + bitangent * sin(angle)) * radius.value
		if last_camera.is_position_behind(point):
			return
		points.append(last_camera.unproject_position(point))
	control.draw_polyline(points, Color(1.0, 0.8, 0.15), 2.0, true)

