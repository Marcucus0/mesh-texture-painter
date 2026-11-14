extends SceneTree
const Geometry = preload("res://Addons/mesh_texture_painter/geometry.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://camera-island.tscn").instantiate()
	root.add_child(scene)
	var target: MeshInstance3D = scene.get_node("Island_Terrain")
	var paint = target.get_node("TexturePaint")
	var geometry = Geometry.new()
	assert(geometry.build(paint.paint_mesh, Mesh.ARRAY_TEX_UV2))
	var camera := Camera3D.new()
	root.add_child(camera)
	var center := Vector3(176.3278, 2.493588, -117.8997)
	camera.position = center + Vector3(0, 60, 80)
	camera.look_at(center)
	var masks: Array = []
	for image in paint.layers[0].masks:
		masks.append(image.duplicate())
	if geometry.has_method("prepare_world"):
		var prepare_start := Time.get_ticks_usec()
		geometry.prepare_world(target.global_transform, masks[0].get_width())
		print("BRUSH BENCH activation preparation ms=", (Time.get_ticks_usec() - prepare_start) / 1000.0)
	for moving in [false, true]:
		var timings: Array[float] = []
		for i in 12:
			var start := Time.get_ticks_usec()
			geometry.dab(target, masks, center + Vector3(i * 0.5 if moving else 0, 0, 0), camera, 40, 0.15, 0.3, 1, 0)
			timings.append((Time.get_ticks_usec() - start) / 1000.0)
		print("BRUSH BENCH moving=", moving, " ms=", timings)
	scene.free()
	camera.free()
	quit()
