extends SceneTree
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output"))
	var mesh_node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4, 4)
	plane.material = StandardMaterial3D.new()
	mesh_node.mesh = plane
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_scene(mesh_node, state)
	if error == OK:
		error = document.write_to_filesystem(state, "res://tests/output/island.glb")
	mesh_node.free()
	if error == OK:
		error = generate_editor_fixture()
	print("FIXTURE RESULT: ", error)
	quit(0 if error == OK else 1)

func generate_editor_fixture() -> Error:
	var directory := "res://tests/output/fixtures"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for entry in [["grass", Color(0.2, 0.55, 0.12)], ["dirt", Color(0.48, 0.25, 0.1)]]:
		var image := Image.create(32, 32, false, Image.FORMAT_RGB8)
		image.fill(entry[1])
		var result := image.save_png(directory.path_join(entry[0] + ".png"))
		if result != OK:
			return result
	var scene := Node3D.new()
	scene.name = "PaintTestFixture"
	var mesh := MeshInstance3D.new()
	mesh.name = "Island"
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	plane.subdivide_width = 12
	plane.subdivide_depth = 12
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.36, 0.4, 0.46)
	material.roughness = 0.85
	plane.material = material
	mesh.mesh = plane
	scene.add_child(mesh)
	mesh.owner = scene
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = true
	scene.add_child(sun)
	sun.owner = scene
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.65, 0.7, 0.8)
	environment.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = environment
	scene.add_child(world)
	world.owner = scene
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(7, 8, 9)
	camera.rotation_degrees = Vector3(-35, 38, 0)
	camera.current = true
	scene.add_child(camera)
	camera.owner = scene
	var packed := PackedScene.new()
	var result := packed.pack(scene)
	if result == OK:
		result = ResourceSaver.save(packed, directory.path_join("island.tscn"))
	scene.free()
	return result
