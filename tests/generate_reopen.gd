extends SceneTree

func _initialize() -> void:
	var root := Node3D.new()
	root.name = "ReopenFixture"
	get_root().add_child(root)
	var target := MeshInstance3D.new()
	target.name = "Island"
	target.mesh = PlaneMesh.new()
	root.add_child(target)
	target.owner = root
	# Deliberately differ from the editor plugin activation path on Windows.
	var script = load("res://Addons/mesh_texture_painter/stack.gd")
	var stack = script.new()
	stack.name = "TexturePaint"
	stack.resolution = 128
	target.add_child(stack)
	stack.owner = root
	var layer = stack.make_layer(load("res://tests/output/fixtures/grass.png"))
	var image: Image = layer.masks[0].duplicate()
	image.fill(Color(0.6, 0.6, 0.6))
	layer.upload(0, image)
	stack.set_layers([layer])
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, "res://reopen.tscn") == OK)
	print("REOPEN FIXTURE: saved")
	quit()
