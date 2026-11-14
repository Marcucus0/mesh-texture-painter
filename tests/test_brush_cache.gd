extends SceneTree
const Geometry = preload("res://addons/mesh_texture_painter/geometry.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var target := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(4, 4)
	target.mesh = mesh
	root.add_child(target)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 5, 2)
	camera.look_at(Vector3.ZERO)
	var warm := Geometry.new()
	assert(warm.build(mesh))
	for step in 12:
		var size := 64 if step < 9 else 128
		var radius := 1.0 if step < 5 else 1.5
		var center := Vector3.ZERO if step < 3 else Vector3(0.2, 0, 0.1)
		if step == 6:
			camera.position = Vector3(0, -5, 2)
			camera.look_at(Vector3.ZERO)
		if step == 7:
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = 8
		if step == 8:
			target.scale = Vector3(2, 0.5, 1)
		if step == 10:
			target.position = Vector3(0, 1, 0)
		var fresh := Geometry.new()
		assert(fresh.build(mesh))
		var a := Image.create(size, size, false, Image.FORMAT_L8)
		a.fill(Color(0.4, 0.4, 0.4))
		a.set_pixel(size / 2, size / 2, Color.WHITE)
		var b: Image = a.duplicate()
		var dirty_a := warm.dab(target, [a], center, camera, radius, 0.4, 0.3, 1.2, step % 5)
		var dirty_b := fresh.dab(target, [b], center, camera, radius, 0.4, 0.3, 1.2, step % 5)
		check(a.get_data() == b.get_data() and dirty_a == dirty_b, "Cached brush differs from cold evaluation at step %d" % step)
	# Same footprint, different mask contents: cached data must not include paint.
	var empty := Image.create(128, 128, false, Image.FORMAT_L8)
	var full: Image = empty.duplicate()
	full.fill(Color.WHITE)
	warm.dab(target, [empty], Vector3(0, 1, 0), camera, 1.5, 0.5, 0.3, 1, 0)
	warm.dab(target, [full], Vector3(0, 1, 0), camera, 1.5, 0.5, 0.3, 1, 2)
	check(empty.get_pixel(64, 64).r > 0.4 and full.get_pixel(64, 64).r < 0.6, "Shared geometry cache must respect independent layers and modes")
	target.free()
	camera.free()
	print("BRUSH CACHE RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
