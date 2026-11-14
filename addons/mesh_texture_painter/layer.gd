@tool
extends Resource
const I18n = preload("localization.gd")

const MaskPadding = preload("mask_padding.gd")

const SETTINGS = [&"title", &"albedo", &"normal_map", &"roughness_map", &"metallic_map", &"ao_map", &"tint", &"roughness", &"metallic", &"uv_scale", &"uv_offset", &"opacity", &"transition", &"enabled", &"roughness_channel", &"metallic_channel", &"ao_channel", &"normal_strength", &"specular", &"ao_light_affect"]

@export var title: String = "Texture"
@export var albedo: Texture2D
@export var normal_map: Texture2D
@export var roughness_map: Texture2D
@export var metallic_map: Texture2D
@export var ao_map: Texture2D
@export var tint: Color = Color.WHITE
@export_range(0.0, 1.0) var roughness: float = 0.8
@export_range(0.0, 1.0) var metallic: float = 0.0
@export var uv_scale: Vector2 = Vector2.ONE
@export var uv_offset: Vector2 = Vector2.ZERO
@export_enum("Rouge", "Vert", "Bleu", "Alpha", "Gris") var roughness_channel: int = 0
@export_enum("Rouge", "Vert", "Bleu", "Alpha", "Gris") var metallic_channel: int = 0
@export_enum("Rouge", "Vert", "Bleu", "Alpha", "Gris") var ao_channel: int = 0
@export_range(0.0, 16.0) var normal_strength: float = 1.0
@export_range(0.0, 1.0) var specular: float = 0.5
@export_range(0.0, 1.0) var ao_light_affect: float = 0.0
@export_range(0.0, 1.0) var opacity: float = 1.0
@export_range(0.1, 4.0) var transition: float = 1.0
@export var enabled: bool = true
var masks: Array[Image] = []
# Compressed authored data is embedded in the scene; GPU textures are transient.
@export_storage var mask_data: Array[PackedByteArray]:
	get:
		return snapshot()
	set(value):
		masks.clear()
		_textures.clear()
		for bytes in value:
			var image := Image.new()
			if image.load_png_from_buffer(bytes) == OK:
				image.convert(Image.FORMAT_L8)
				image.resource_local_to_scene = true
				masks.append(image)
var _textures: Array[ImageTexture] = []
var _paint_owner: WeakRef
var _mask_padding: Dictionary = {}

func _init() -> void:
	resource_local_to_scene = true

func _validate_property(property: Dictionary) -> void:
	if property.name in [&"roughness_channel", &"metallic_channel", &"ao_channel"]:
		property.hint_string = I18n.text("Rouge,Vert,Bleu,Alpha,Gris")

static func channel_vector(channel: int) -> Vector4:
	match channel:
		1: return Vector4(0, 1, 0, 0)
		2: return Vector4(0, 0, 1, 0)
		3: return Vector4(0, 0, 0, 1)
		4: return Vector4(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0, 0)
	return Vector4(1, 0, 0, 0)

func snapshot() -> Array[PackedByteArray]:
	var result: Array[PackedByteArray] = []
	for mask in masks:
		result.append(mask.save_png_to_buffer())
	return result

func restore(data: Array) -> void:
	for i in mini(data.size(), masks.size()):
		var image := Image.new()
		var result := image.load_png_from_buffer(data[i])
		if result == OK:
			image.convert(Image.FORMAT_L8)
			upload(i, image)
	emit_changed()

func texture_for(index: int) -> ImageTexture:
	while _textures.size() <= index:
		_textures.append(null)
	if _textures[index] == null:
		_textures[index] = ImageTexture.create_from_image(_display_mask(index))
	return _textures[index]

func set_mask_padding(index: int, pairs: PackedInt32Array) -> void:
	if _mask_padding.has(index):
		return
	_mask_padding[index] = pairs
	if index < _textures.size() and _textures[index] != null:
		_textures[index].update(_display_mask(index))

func _display_mask(index: int) -> Image:
	return MaskPadding.apply(masks[index], _mask_padding.get(index, PackedInt32Array()))

func upload(index: int, image: Image) -> void:
	image.resource_local_to_scene = true
	masks[index] = image
	if index < _textures.size() and _textures[index] != null:
		_textures[index].update(_display_mask(index))
