extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if args.is_empty() or document.append_from_file(args[0], state) != OK:
		quit(1)
		return
	var scene := document.generate_scene(state)
	var packed := PackedScene.new()
	var result := packed.pack(scene)
	if result == OK:
		result = ResourceSaver.save(packed, "res://tests/output/stress-island.tscn")
	scene.free()
	print("STRESS FIXTURE RESULT: ", result)
	quit(0 if result == OK else 1)
