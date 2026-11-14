extends SceneTree
const Fixture = preload("res://tests/uv_seam_fixture.gd")
const Padding = preload("res://addons/mesh_texture_painter/mask_padding.gd")
const Layer = preload("res://addons/mesh_texture_painter/layer.gd")
var checks := 0
var failures := 0
func check(value: bool, text: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(text)
func _initialize() -> void:
	var mesh := Fixture.mesh()
	var mask := Fixture.mask(mesh, 32)
	var original := mask.get_data()
	var pairs := Padding.build(mesh, 0, 32, Mesh.ARRAY_TEX_UV)
	check(not pairs.is_empty(), "UV atlas must produce a gutter map")
	check(Fixture.sample(mask, Vector2(0.25, 0.5)) < 0.9, "Fixture must reproduce the unpadded translucent seam")
	var padded := Padding.apply(mask, pairs)
	check(Fixture.sample(padded, Vector2(0.25, 0.5)) > 0.99, "Padding must close the first chart seam")
	check(Fixture.sample(padded, Vector2(0.75, 0.5)) > 0.99, "Padding must close the second chart seam")
	check(mask.get_data() == original, "Display padding must not change authored masks")
	var one := Fixture.mask(mesh, 32, true)
	var partial := Padding.apply(one, pairs)
	check(Fixture.sample(partial, Vector2(0.25, 0.5)) > 0.99, "Painted chart must be padded")
	check(Fixture.sample(partial, Vector2(0.75, 0.5)) == 0, "Unpainted chart must remain unpainted")
	var coverage := Fixture.mask(mesh, 32)
	var interior_preserved := true
	for i in range(0, pairs.size(), 2):
		var pixel := pairs[i]
		if coverage.get_data()[pixel] != 0:
			interior_preserved = false
	check(interior_preserved, "Padding destinations must stay outside every UV triangle")
	one.set_pixel(4, 22, Color.BLACK)
	partial = Padding.apply(one, pairs)
	check(partial.get_pixel(4, 22).r == 0, "Local erasing inside geometry must not be dilated away")
	var layer := Layer.new()
	layer.masks.append(one)
	var snapshot := layer.snapshot()
	layer.set_mask_padding(0, pairs)
	check(Fixture.sample(layer._display_mask(0), Vector2(0.25, 0.5)) > 0.99, "Layer display must apply the shared gutter map")
	check(layer.snapshot() == snapshot, "Snapshots must contain only authored data")
	var erased := Image.create(32, 32, false, Image.FORMAT_L8)
	erased.fill(Color.BLACK)
	layer.upload(0, erased)
	check(Fixture.sample(layer._display_mask(0), Vector2(0.25, 0.5)) == 0, "Erasing must also clear derived padding")
	layer.restore(snapshot)
	check(Fixture.sample(layer._display_mask(0), Vector2(0.25, 0.5)) > 0.99, "Undo must rebuild display padding")
	print("SEAM RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
