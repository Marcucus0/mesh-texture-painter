extends SceneTree
const PaintUV = preload("res://addons/mesh_texture_painter/paint_uv.gd")
const Geometry = preload("res://addons/mesh_texture_painter/geometry.gd")
const Stack = preload("res://addons/mesh_texture_painter/stack.gd")
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(4, 4)
	var arrays := plane.surface_get_arrays(0)
	arrays[Mesh.ARRAY_TEX_UV] = null
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	verify_mesh(mesh, "UV-less fixture")
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var path: String = args[0]
		var original := FileAccess.get_sha256(path)
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		check(document.append_from_file(path, state) == OK, "Real GLB must import")
		var scene := document.generate_scene(state)
		root.add_child(scene)
		var selected := find_island(scene)
		check(selected != null, "Refined_Lake_Terrain must exist in real GLB")
		if selected != null:
			verify_mesh(selected.mesh, "Refined_Lake_Terrain")
		scene.free()
		check(FileAccess.get_sha256(path) == original, "Source GLB must remain unchanged")
	print("UV RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func verify_mesh(source: Mesh, label: String) -> void:
	var fingerprint := Stack.fingerprint(source)
	var generator := PaintUV.new()
	var start := Time.get_ticks_msec()
	var generated := generator.generate(source)
	check(generated != null, label + ": " + generator.error)
	if generated == null:
		return
	print(label, ": unwrap ", Time.get_ticks_msec() - start, " ms, ", generated.get_surface_count(), " surfaces")
	check(Stack.fingerprint(source) == fingerprint, label + ": source arrays unchanged")
	check(generated.get_surface_count() == source.get_surface_count(), label + ": surfaces preserved")
	var geometry := Geometry.new()
	var valid := geometry.build(generated, Mesh.ARRAY_TEX_UV2)
	check(valid, label + ": generated atlas must build: " + geometry.error)
	check(not geometry.overlapping_uvs(256), label + ": atlas must not overlap")
	for surface in generated.get_surface_count():
		var data := generated.surface_get_arrays(surface)
		check(data[Mesh.ARRAY_TEX_UV].size() == data[Mesh.ARRAY_VERTEX].size(), label + ": painted texture UVs present")
	var holder := Node3D.new()
	root.add_child(holder)
	var target := MeshInstance3D.new()
	target.name = "Island"
	target.mesh = source
	holder.add_child(target)
	target.owner = holder
	var paint := Stack.new()
	paint.name = "TexturePaint"
	paint.paint_mesh = generated
	paint.resolution = 128
	target.add_child(paint)
	paint.owner = holder
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.GREEN)
	paint.layers.append(paint.make_layer(ImageTexture.create_from_image(image)))
	var first_triangle: Dictionary = geometry.triangles[0]
	var aim: Vector3 = (first_triangle.p[0] + first_triangle.p[1] + first_triangle.p[2]) / 3.0
	var extent := maxf(source.get_aabb().size.length(), 1.0)
	var camera := Camera3D.new()
	holder.add_child(camera)
	camera.position = aim + Vector3.UP * extent
	camera.look_at(aim, Vector3.FORWARD)
	var hit: Dictionary = geometry.hit(target, camera.position, Vector3.DOWN)
	check(not hit.is_empty(), label + ": generated geometry must be raycastable")
	var images: Array = []
	for mask in paint.layers[0].masks:
		images.append(mask.duplicate())
	if not hit.is_empty():
		var dirty: PackedInt32Array = geometry.dab(target, images, hit.position, camera, extent / 6.0, 1.0, 0.5, 1.0, 0)
		check(not dirty.is_empty(), label + ": world brush must paint the generated atlas")
	paint.layers[0].masks[0].fill(Color.WHITE)
	paint.rebuild()
	check(paint._proxies.size() == 1, label + ": overlay must use generated geometry")
	var packed := PackedScene.new()
	check(packed.pack(holder) == OK, label + ": scene must pack")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output"))
	var path := "res://tests/output/automatic_uv.tscn"
	check(ResourceSaver.save(packed, path) == OK, label + ": scene must save")
	var loaded: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var instance := loaded.instantiate()
	root.add_child(instance)
	var restored: Stack = instance.get_node("Island/TexturePaint")
	check(restored.paint_mesh != null, label + ": generated atlas persists")
	check(restored._proxies.size() == 1, label + ": overlay restores after reload")
	check(restored.layers[0].masks[0].get_pixel(64, 64).r > 0.99, label + ": paint persists")
	holder.free()
	instance.free()
func find_island(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and ("Refined_Lake_Terrain" in str(node.name) or (node.mesh != null and node.mesh.get_surface_count() == 7)):
		return node
	for child in node.get_children():
		var result := find_island(child)
		if result != null:
			return result
	return null
