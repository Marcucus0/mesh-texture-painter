extends SceneTree
const Stack = preload("res://addons/mesh_texture_painter/stack.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene: Node3D = load("res://tests/output/fixtures/island.tscn").instantiate()
	root.add_child(scene)
	var target: MeshInstance3D = scene.get_node("Island")
	var paint := Stack.new()
	paint.resolution = 128
	target.add_child(paint)
	for path in ["res://tests/output/fixtures/grass.png", "res://tests/output/fixtures/dirt.png"]:
		paint.layers.append(paint.make_layer(load(path)))
	for y in 128:
		for x in 128:
			var distance := Vector2(x - 64, y - 64).length() / 50.0
			var v := clampf(1.0 - distance, 0.0, 1.0)
			paint.layers[0].masks[0].set_pixel(x, y, Color(v, v, v, 1))
			var path_weight := clampf(1.0 - absf(x - 64) / 12.0, 0.0, 1.0) * 0.9
			paint.layers[1].masks[0].set_pixel(x, y, Color(path_weight, path_weight, path_weight, 1))
	paint.rebuild()
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("GPU capture unavailable")
		quit(1)
		return
	image.save_png("res://tests/output/render.png")
	print("RENDER RESULT: image saved, ", RenderingServer.get_video_adapter_name())
	quit()
