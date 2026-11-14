extends SceneTree
const Fixture = preload("res://tests/uv_seam_fixture.gd")
const Stack = preload("res://addons/mesh_texture_painter/stack.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var target := MeshInstance3D.new()
	target.mesh = Fixture.mesh()
	var base := StandardMaterial3D.new()
	base.albedo_color = Color.GREEN
	base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	target.mesh.surface_set_material(0, base)
	scene.add_child(target)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.05, 0.05, 0.05)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 1
	scene.add_child(environment)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0, 6, 6)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var paint := Stack.new()
	paint.resolution = 32
	target.add_child(paint)
	var white := Image.create(1, 1, false, Image.FORMAT_RGB8)
	white.fill(Color.WHITE)
	var layer := paint.make_layer(ImageTexture.create_from_image(white))
	layer.tint = Color.RED
	layer.specular = 0
	layer.masks[0] = Fixture.mask(target.mesh, 32)
	paint.layers.append(layer)
	paint.rebuild()
	# Reproduce the previous backend using its unpadded GPU mask.
	layer.texture_for(0).update(layer.masks[0])
	for frame in 8:
		await process_frame
	RenderingServer.force_draw()
	var before := root.get_texture().get_image()
	var before_green := seam_green(before, camera)
	layer.upload(0, layer.masks[0])
	for frame in 8:
		await process_frame
	RenderingServer.force_draw()
	var after := root.get_texture().get_image()
	var after_green := seam_green(after, camera)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output"))
	before.save_png("res://tests/output/seam-before.png")
	after.save_png("res://tests/output/seam-after.png")
	print("SEAM GPU VALUES: green before ", before_green, ", after ", after_green)
	if before_green < 0.1 or after_green > 0.08 or after_green >= before_green - 0.1:
		push_error("GPU seam regression: base material must stop leaking through the painted UV seam")
		quit(1)
		return
	print("SEAM GPU RESULT: folded surface opaque across UV seam, success")
	quit()
func seam_green(image: Image, camera: Camera3D) -> float:
	var sum := 0.0
	for point in [Vector3(-0.025, 0, 0.025), Vector3(0.025, 0.0075, -0.025)]:
		var pixel := Vector2i(camera.unproject_position(point)).clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE)
		sum += image.get_pixelv(pixel).g
	return sum / 2.0
