extends SceneTree
const PaintUV = preload("res://addons/mesh_texture_painter/paint_uv.gd")
const Geometry = preload("res://addons/mesh_texture_painter/geometry.gd")
const Stack = preload("res://addons/mesh_texture_painter/stack.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		quit(1)
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(args[0], state) != OK:
		quit(1)
		return
	var scene := document.generate_scene(state)
	root.add_child(scene)
	var target := find_island(scene)
	if target == null:
		quit(1)
		return
	var paint := Stack.new()
	paint.paint_mesh = PaintUV.new().generate(target.mesh)
	paint.resolution = 512
	target.add_child(paint)
	paint.layers.append(paint.make_layer(load("res://tests/output/fixtures/grass.png")))
	paint.layers[0].uv_scale = Vector2(20, 20)
	var bounds := target.mesh.get_aabb()
	var center := target.to_global(bounds.get_center())
	var extent := (target.global_basis * bounds.size).length()
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = center + Vector3(0.6, 0.8, 0.7) * extent
	camera.look_at(center, Vector3.UP)
	camera.current = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.12, 0.16, 0.23)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	root.add_child(light)
	var geometry := Geometry.new()
	if not geometry.build(paint.paint_mesh, Mesh.ARRAY_TEX_UV2):
		push_error(geometry.error)
		quit(1)
		return
	var hit: Dictionary = geometry.hit(target, camera.position, (center - camera.position).normalized())
	if hit.is_empty():
		push_error("No island hit")
		quit(1)
		return
	var images: Array = []
	for mask in paint.layers[0].masks:
		images.append(mask.duplicate())
	var dirty: PackedInt32Array = geometry.dab(target, images, hit.position, camera, extent * 0.18, 1, 0.5, 1, 0)
	if dirty.is_empty():
		push_error("No painted texels")
		quit(1)
		return
	for surface in dirty:
		paint.layers[0].upload(surface, images[surface])
	paint.rebuild()
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/output/cascade-painted.png")
	print("ASSET RENDER RESULT: painted ", dirty.size(), " surfaces")
	quit()
func find_island(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.mesh != null and node.mesh.get_surface_count() == 7:
		return node
	for child in node.get_children():
		var result := find_island(child)
		if result != null:
			return result
	return null
