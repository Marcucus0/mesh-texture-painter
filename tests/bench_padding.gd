extends SceneTree
const PaintUV = preload("res://addons/mesh_texture_painter/paint_uv.gd")
const Padding = preload("res://addons/mesh_texture_painter/mask_padding.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if args.is_empty() or doc.append_from_file(args[0], state) != OK:
		quit(1)
		return
	var scene := doc.generate_scene(state)
	var mesh_node := find_mesh(scene)
	var mesh := PaintUV.new().generate(mesh_node.mesh)
	var start := Time.get_ticks_msec()
	var pairs: Array = []
	for surface in mesh.get_surface_count():
		pairs.append(Padding.build(mesh, surface, 512, Mesh.ARRAY_TEX_UV2))
	print("PADDING BENCH: seven surfaces at 512, build ", Time.get_ticks_msec() - start, " ms")
	var image := Image.create(512, 512, false, Image.FORMAT_L8)
	image.fill(Color.WHITE)
	start = Time.get_ticks_usec()
	for repeat in 10:
		Padding.apply(image, pairs[0])
	print("PADDING BENCH: upload preparation average ", (Time.get_ticks_usec() - start) / 10000.0, " ms")
	scene.free()
	quit()
func find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.mesh.get_surface_count() == 7:
		return node
	for child in node.get_children():
		var result := find_mesh(child)
		if result != null:
			return result
	return null
