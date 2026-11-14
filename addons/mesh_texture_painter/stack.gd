@tool
extends Node3D
const I18n = preload("localization.gd")

const Layer = preload("layer.gd")
const PAINT_SHADER = preload("paint.gdshader")
const MaskPadding = preload("mask_padding.gd")
const MAX_LAYERS := 32
@export_range(128, 2048, 128) var resolution: int = 512
@export var layers: Array[Layer] = []
@export var painting_enabled: bool = true
@export_storage var mesh_signature: String = ""
@export_storage var paint_mesh: ArrayMesh
var _proxies: Array[MeshInstance3D] = []
var _proxy_cache: Dictionary = {}
var _material_cache: Dictionary = {}
var _compatible := true
var _stroke_active := false
var _padding_cache: Dictionary = {}

func _ready() -> void:
	if target() == null or target().mesh == null:
		return
	var signature := fingerprint(target().mesh)
	if mesh_signature.is_empty():
		mesh_signature = signature
	elif mesh_signature != signature:
		_compatible = false
		push_warning(I18n.text("Texture Paint : géométrie/UV modifiés. Peinture suspendue pour préserver les masques."))
		return
	rebuild()

func target() -> MeshInstance3D:
	return get_parent() as MeshInstance3D

func painting_mesh() -> Mesh:
	return paint_mesh if paint_mesh != null else target().mesh

static func backend_issue() -> String:
	if RenderingServer.get_current_rendering_driver_name() == "d3d12" and "intel" in RenderingServer.get_video_adapter_vendor().to_lower():
		return I18n.text("Peinture indisponible sous Direct3D 12 sur Intel : perte GPU reproduite. Dans les paramètres du projet, choisissez rendering/rendering_device/driver.windows = vulkan, puis redémarrez Godot. Forward+ reste utilisable.")
	return ""

func rebuild(include_empty: bool = false) -> void:
	include_empty = include_empty or _stroke_active
	ensure_unique_layers()
	for proxy in _proxy_cache.values():
		if is_instance_valid(proxy):
			proxy.hide()
			proxy.material_override = null
	_proxies.clear()
	var mesh_node := target()
	if not _compatible or not painting_enabled or mesh_node == null or mesh_node.mesh == null or not backend_issue().is_empty():
		return
	var live_materials: Dictionary = {}
	for surface in mesh_node.mesh.get_surface_count():
		if layers.is_empty():
			continue
		var proxy: MeshInstance3D = _proxy_cache.get(surface)
		if not is_instance_valid(proxy):
			var surface_mesh := ArrayMesh.new()
			surface_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, painting_mesh().surface_get_arrays(surface))
			proxy = MeshInstance3D.new()
			proxy.name = "PaintPreview%d" % surface
			proxy.mesh = surface_mesh
			proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			proxy.hide()
			add_child(proxy, false, Node.INTERNAL_MODE_BACK)
			_proxy_cache[surface] = proxy
		var first: ShaderMaterial
		var previous: ShaderMaterial
		for i in mini(layers.size(), MAX_LAYERS):
			var layer := layers[i]
			if surface >= layer.masks.size():
				continue
			var key := "%s:%d" % [layer.get_instance_id(), surface]
			live_materials[key] = true
			var material: ShaderMaterial = _material_cache.get(key)
			if material == null:
				material = ShaderMaterial.new()
				material.shader = PAINT_SHADER
				_material_cache[key] = material
			material.next_pass = null
			material.render_priority = i + 1
			var padding_key := Vector2i(surface, layer.masks[surface].get_width())
			if not _padding_cache.has(padding_key):
				_padding_cache[padding_key] = MaskPadding.build(painting_mesh(), surface, padding_key.y, Mesh.ARRAY_TEX_UV2 if paint_mesh != null else Mesh.ARRAY_TEX_UV)
			layer.set_mask_padding(surface, _padding_cache[padding_key])
			material.set_shader_parameter("paint_mask", layer.texture_for(surface))
			material.set_shader_parameter("mask_uv2", paint_mesh != null)
			material.set_shader_parameter("albedo_tex", layer.albedo)
			material.set_shader_parameter("normal_tex", layer.normal_map)
			material.set_shader_parameter("has_normal", layer.normal_map != null)
			material.set_shader_parameter("roughness_tex", layer.roughness_map)
			material.set_shader_parameter("metallic_tex", layer.metallic_map)
			material.set_shader_parameter("ao_tex", layer.ao_map)
			material.set_shader_parameter("tint", layer.tint)
			material.set_shader_parameter("uv_scale", layer.uv_scale)
			material.set_shader_parameter("uv_offset", layer.uv_offset)
			material.set_shader_parameter("roughness_channel", Layer.channel_vector(layer.roughness_channel))
			material.set_shader_parameter("metallic_channel", Layer.channel_vector(layer.metallic_channel))
			material.set_shader_parameter("ao_channel", Layer.channel_vector(layer.ao_channel))
			material.set_shader_parameter("normal_strength", layer.normal_strength)
			material.set_shader_parameter("specular_value", layer.specular)
			material.set_shader_parameter("ao_light_affect", layer.ao_light_affect)
			material.set_shader_parameter("opacity", layer.opacity)
			material.set_shader_parameter("transition", layer.transition)
			material.set_shader_parameter("roughness_value", layer.roughness)
			material.set_shader_parameter("metallic_value", layer.metallic)
			if not layer.enabled or (not include_empty and not mask_used(layer.masks[surface])):
				continue
			if first == null:
				first = material
			else:
				previous.next_pass = material
			previous = material
		if first == null:
			continue
		proxy.material_override = first
		proxy.show()
		_proxies.append(proxy)
	for key in _material_cache.keys():
		if not live_materials.has(key):
			_material_cache.erase(key)

func begin_stroke() -> void:
	_stroke_active = true
	rebuild(true)

func end_stroke() -> void:
	_stroke_active = false

static func mask_used(mask: Image) -> bool:
	var data := mask.get_data()
	for i in data.size():
		if data[i] > 0:
			return true
	return false

func make_layer(texture: Texture2D) -> Layer:
	var layer := Layer.new()
	layer.title = texture.resource_path.get_file().get_basename()
	layer.albedo = texture
	for surface in target().mesh.get_surface_count():
		var image := Image.create(resolution, resolution, false, Image.FORMAT_L8)
		image.fill(Color(0, 0, 0, 1))
		image.resource_local_to_scene = true
		layer.masks.append(image)
	return layer

func snapshot() -> Array:
	var result: Array = []
	for layer in layers:
		result.append(layer.snapshot())
	return result

func make_material_layer(material: BaseMaterial3D) -> Layer:
	var texture := material.albedo_texture
	if texture == null:
		var white := Image.create(1, 1, false, Image.FORMAT_RGB8)
		white.fill(Color.WHITE)
		texture = ImageTexture.create_from_image(white)
	var layer := make_layer(texture)
	layer.title = material.resource_name if not material.resource_name.is_empty() else material.resource_path.get_file().get_basename()
	layer.tint = material.albedo_color
	layer.normal_map = material.normal_texture if material.normal_enabled else null
	layer.normal_strength = material.normal_scale
	layer.roughness = material.roughness
	layer.metallic = material.metallic
	layer.specular = material.metallic_specular
	layer.ao_light_affect = material.ao_light_affect
	layer.uv_scale = Vector2(material.uv1_scale.x, material.uv1_scale.y)
	layer.uv_offset = Vector2(material.uv1_offset.x, material.uv1_offset.y)
	if material is ORMMaterial3D:
		layer.ao_map = material.orm_texture if material.ao_enabled else null
		layer.roughness_map = material.orm_texture
		layer.metallic_map = material.orm_texture
		if material.orm_texture != null:
			layer.roughness = 1.0
			layer.metallic = 1.0
		layer.roughness_channel = 1
		layer.metallic_channel = 2
	else:
		layer.roughness_map = material.roughness_texture
		layer.metallic_map = material.metallic_texture
		layer.ao_map = material.ao_texture if material.ao_enabled else null
		layer.roughness_channel = material.roughness_texture_channel
		layer.metallic_channel = material.metallic_texture_channel
		layer.ao_channel = material.ao_texture_channel
	return layer

func restore_snapshot(data: Array) -> void:
	for i in mini(data.size(), layers.size()):
		layers[i].restore(data[i])
	rebuild()

func set_layers(value: Array) -> void:
	layers.assign(value)
	rebuild()

func set_layer_value(index: int, property: StringName, value: Variant) -> void:
	if index < 0 or index >= layers.size():
		return
	layers[index].set(property, value)
	rebuild()


# Editor node duplication can share Resources even when scene instances do not.
func ensure_unique_layers() -> void:
	for i in layers.size():
		var layer := layers[i]
		if layer._paint_owner != null and layer._paint_owner.get_ref() != null and layer._paint_owner.get_ref() != self:
			var copy := Layer.new()
			for property in Layer.SETTINGS:
				copy.set(property, layer.get(property))
			for image in layer.masks:
				var mask: Image = image.duplicate()
				mask.resource_local_to_scene = true
				copy.masks.append(mask)
			layers[i] = copy
		layers[i]._paint_owner = weakref(self)
static func fingerprint(mesh: Mesh) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		context.update(var_to_bytes([arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_TEX_UV], arrays[Mesh.ARRAY_INDEX]]))
	return context.finish().hex_encode()
