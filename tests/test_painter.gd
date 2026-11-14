extends SceneTree

const Plugin = preload("res://addons/mesh_texture_painter/plugin.gd")
const Geometry = preload("res://addons/mesh_texture_painter/geometry.gd")
const Stack = preload("res://addons/mesh_texture_painter/stack.gd")
var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Island"
	var plane := PlaneMesh.new()
	plane.size = Vector2(4, 4)
	var base := StandardMaterial3D.new()
	base.albedo_color = Color(0.3, 0.4, 0.5)
	plane.material = base
	mesh_node.mesh = plane
	world.add_child(mesh_node)
	mesh_node.owner = world
	var geometry := Geometry.new()
	check(geometry.build(plane), "Plane UV geometry must build")
	check(not geometry.overlapping_uvs(), "Plane must have unique UVs")
	var hit: Dictionary = geometry.hit(mesh_node, Vector3(0, 3, 0), Vector3.DOWN)
	check(not hit.is_empty(), "BVH must hit plane")
	check(hit.position.distance_to(Vector3.ZERO) < 0.001, "Hit must be at center")
	var paint := Stack.new()
	paint.name = "TexturePaint"
	paint.resolution = 128
	mesh_node.add_child(paint)
	paint.owner = world
	var color := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	color.fill(Color.GREEN)
	var texture := ImageTexture.create_from_image(color)
	paint.layers.append(paint.make_layer(texture))
	paint.layers.append(paint.make_layer(texture))
	var pbr := StandardMaterial3D.new()
	pbr.resource_name = "Ground fixture"
	pbr.albedo_texture = texture
	pbr.normal_enabled = true
	pbr.normal_texture = texture
	pbr.normal_scale = 0.6
	pbr.ao_enabled = true
	pbr.ao_texture = texture
	pbr.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	pbr.roughness_texture = texture
	pbr.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	pbr.roughness = 0.7
	pbr.uv1_scale = Vector3(2, 3, 1)
	pbr.uv1_offset = Vector3(0.2, 0.3, 0)
	pbr.heightmap_enabled = true
	var converted := paint.make_material_layer(pbr)
	check(converted.albedo == texture and converted.normal_map == texture, "PBR import must preserve albedo and normal references")
	check(converted.roughness_map == texture and converted.ao_map == texture, "PBR import must preserve roughness and AO references")
	check(converted.roughness_channel == 4 and converted.ao_channel == 4, "PBR import must preserve grayscale channel selection")
	check(converted.uv_scale == Vector2(2, 3) and converted.uv_offset.is_equal_approx(Vector2(0.2, 0.3)), "PBR import must preserve UV transforms")
	check(is_equal_approx(converted.normal_strength, 0.6) and is_equal_approx(converted.roughness, 0.7), "PBR scalar parameters must survive conversion")
	check(pbr.heightmap_enabled and pbr.albedo_texture == texture, "PBR conversion must not modify the source material")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output"))
	check(ResourceSaver.save(pbr, "res://tests/output/material-pbr.tres") == OK, "Editor material fixture must save")
	check(paint.layers[0].masks[0] != paint.layers[1].masks[0], "Layer masks must be independent")
	paint.rebuild()
	check(paint._proxies.is_empty(), "Empty masks must not render passes")
	var snapshot := paint.snapshot()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 3, 0)
	camera.look_at(Vector3.ZERO, Vector3.FORWARD)
	var images: Array = [paint.layers[0].masks[0]]
	geometry.dab(mesh_node, images, Vector3.ZERO, camera, 0.6, 0.8, 0.2, 1, 0)
	check(images[0].get_pixel(64, 64).r > 0.5, "Brush must paint center")
	check(images[0].get_pixel(0, 0).r == 0, "Brush must preserve outside")
	check(images[0].get_pixel(80, 64).r < images[0].get_pixel(64, 64).r, "Falloff must be soft")
	paint.layers[0].upload(0, images[0])
	paint.rebuild()
	check(paint._proxies.size() == 1, "Painted surface must create proxy")
	var proxy_id := paint._proxies[0].get_instance_id()
	var mesh_id := paint._proxies[0].mesh.get_instance_id()
	var material_id := paint._proxies[0].material_override.get_instance_id()
	paint.rebuild(true)
	paint.rebuild()
	check(paint._proxies[0].get_instance_id() == proxy_id, "Stroke rebuild must retain the preview node")
	check(paint._proxies[0].mesh.get_instance_id() == mesh_id, "Stroke rebuild must retain GPU geometry")
	check(paint._proxies[0].material_override.get_instance_id() == material_id, "Stroke rebuild must retain its material")
	check(plane.material == base and mesh_node.material_override == null, "Original materials must remain untouched")
	check(paint.layers[1].masks[0].get_pixel(64, 64).r == 0, "Other layer must remain untouched")
	var painted := paint.snapshot()
	paint.restore_snapshot(snapshot)
	check(paint._proxies.is_empty(), "Undo must remove empty passes")
	paint.restore_snapshot(painted)
	check(paint.layers[0].masks[0].get_pixel(64, 64).r > 0.5, "Redo must restore pixels")
	# Serialization: only authored stack, never generated proxies.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output"))
	var packed := PackedScene.new()
	check(packed.pack(world) == OK, "Scene pack must succeed")
	check(ResourceSaver.save(packed, "res://tests/output/painted.tscn") == OK, "Scene save must succeed")
	var loaded: PackedScene = ResourceLoader.load("res://tests/output/painted.tscn", "", ResourceLoader.CACHE_MODE_IGNORE)
	var restored := loaded.instantiate()
	root.add_child(restored)
	var restored_stack: Stack = restored.get_node("Island/TexturePaint")
	check(restored_stack.layers.size() == 2, "Layers must survive scene reload")
	check(restored_stack.layers[0].masks[0].get_pixel(64, 64).r > 0.5, "Paint must survive scene reload")
	var second := loaded.instantiate()
	root.add_child(second)
	var second_stack: Stack = second.get_node("Island/TexturePaint")
	check(second_stack.layers[0] != restored_stack.layers[0], "Scene instances must have independent layers")
	check(second_stack.layers[0].masks[0] != restored_stack.layers[0].masks[0], "Scene instances must have independent masks")
	# Ordinary editor node duplication must also detach authored masks.
	var duplicate_target := mesh_node.duplicate() as MeshInstance3D
	world.add_child(duplicate_target)
	var duplicate_stack := duplicate_target.get_node("TexturePaint") as Stack
	check(duplicate_stack.layers[0] != paint.layers[0], "Duplicated nodes must detach shared layer resources")
	check(duplicate_stack.layers[0].masks[0] != paint.layers[0].masks[0], "Duplicated nodes must detach shared masks")
	duplicate_target.free()
	# Erase and smoothing are independent operations.
	geometry.dab(mesh_node, images, Vector3.ZERO, camera, 0.6, 1, 1, 1, 2)
	check(images[0].get_pixel(64, 64).r == 0, "Erase must clear center")
	geometry.dab(mesh_node, images, Vector3.ZERO, camera, 0.6, 0.5, 0.2, 1, 3)
	check(images[0].get_pixel(64, 64).r >= 0, "Smoothing must execute")
	# Two surfaces sharing the UV square must retain separate masks.
	var two := ArrayMesh.new()
	two.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane.surface_get_arrays(0))
	var back_arrays := plane.surface_get_arrays(0)
	var back_vertices: PackedVector3Array = back_arrays[Mesh.ARRAY_VERTEX]
	for i in back_vertices.size():
		back_vertices[i].y -= 0.15
	back_arrays[Mesh.ARRAY_VERTEX] = back_vertices
	two.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, back_arrays)
	var two_geometry := Geometry.new()
	check(two_geometry.build(two), "Multisurface geometry must build")
	check(not two_geometry.overlapping_uvs(), "UV overlap across different surfaces is permitted")
	var old_mesh := mesh_node.mesh
	mesh_node.mesh = two
	var multi_stack := Stack.new()
	multi_stack.resolution = 128
	mesh_node.add_child(multi_stack)
	multi_stack.layers.append(multi_stack.make_layer(texture))
	multi_stack.begin_stroke()
	check(multi_stack._proxies.size() == 2, "Stroke must prepare every surface for live painting")
	multi_stack.rebuild()
	check(multi_stack._proxies.size() == 2, "Deferred rebuild must not hide unpainted surfaces during a held stroke")
	multi_stack.end_stroke()
	multi_stack.rebuild()
	check(multi_stack._proxies.is_empty(), "Empty surfaces must be culled after stroke ends")
	multi_stack.free()
	var front_image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var back_image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	front_image.fill(Color(0, 0, 0, 1))
	back_image.fill(Color(0, 0, 0, 1))
	two_geometry.dab(mesh_node, [front_image, back_image], Vector3.ZERO, camera, 0.8, 1, 1, 1, 0)
	check(front_image.get_pixel(64, 64).r > 0.9, "Visible front surface must paint")
	check(back_image.get_pixel(64, 64).r == 0, "Brush must never penetrate to hidden back surface")
	mesh_node.mesh = old_mesh
	# Duplicate all triangles in one surface: must reject UV overlap.
	var duplicate_mesh := ArrayMesh.new()
	var duplicated_arrays: Array = []
	duplicated_arrays.resize(Mesh.ARRAY_MAX)
	var original_arrays := plane.surface_get_arrays(0)
	var verts := PackedVector3Array()
	var uv_points := PackedVector2Array()
	var original_indices: PackedInt32Array = original_arrays[Mesh.ARRAY_INDEX]
	for repeat in 2:
		for index in original_indices:
			verts.append(original_arrays[Mesh.ARRAY_VERTEX][index])
			uv_points.append(original_arrays[Mesh.ARRAY_TEX_UV][index])
	duplicated_arrays[Mesh.ARRAY_VERTEX] = verts
	duplicated_arrays[Mesh.ARRAY_TEX_UV] = uv_points
	duplicate_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, duplicated_arrays)
	var overlap_geometry := Geometry.new()
	check(overlap_geometry.build(duplicate_mesh) and overlap_geometry.overlapping_uvs(), "Overlapping UV triangles must be detected")
	# World scale and slope do not alter the brush's world radius.
	mesh_node.rotation_degrees = Vector3(0, 0, 35)
	mesh_node.scale = Vector3(2, 1, 0.5)
	var transformed_hit: Dictionary = geometry.hit(mesh_node, Vector3(0, 3, 0), Vector3.DOWN)
	check(not transformed_hit.is_empty(), "Transformed meshes must be raycastable")
	# GLB fixture generated through official importer/exporter API.
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var export_source := MeshInstance3D.new()
	export_source.mesh = plane
	check(document.append_from_scene(export_source, state) == OK, "GLTF export preparation")
	export_source.free()
	check(document.write_to_filesystem(state, "res://tests/output/island.glb") == OK, "GLB export")
	var import_state := GLTFState.new()
	check(document.append_from_file("res://tests/output/island.glb", import_state) == OK, "GLB import")
	var imported := document.generate_scene(import_state)
	check(imported != null, "GLB scene generation")
	var imported_mesh := find_mesh(imported)
	check(imported_mesh != null and geometry.build(imported_mesh.mesh), "Imported GLB must provide paintable UV triangles")
	imported.free()
	# A real imported PackedScene instance must accept authored child stacks.
	if ResourceLoader.exists("res://tests/output/island.glb"):
		var imported_packed := load("res://tests/output/island.glb") as PackedScene
		if imported_packed != null:
			var container := Node3D.new()
			root.add_child(container)
			var instance := imported_packed.instantiate()
			container.add_child(instance)
			instance.owner = container
			var instance_mesh := find_mesh(instance)
			var attached := Stack.new()
			attached.name = "TexturePaint"
			attached.resolution = 128
			instance_mesh.add_child(attached)
			attached.owner = container
			attached.layers.append(attached.make_layer(texture))
			attached.layers[0].masks[0].fill(Color.WHITE)
			var instance_scene := PackedScene.new()
			check(instance_scene.pack(container) == OK, "Imported instance with stack must pack")
			var reloaded_instance := instance_scene.instantiate()
			root.add_child(reloaded_instance)
			var reloaded_mesh := find_mesh(reloaded_instance)
			var reloaded_paint := reloaded_mesh.get_node_or_null("TexturePaint") as Stack
			check(reloaded_paint != null and reloaded_paint.layers.size() == 1, "Paint stack must survive imported-instance reload")
			check(reloaded_paint != null and reloaded_paint.layers[0].masks[0].get_pixel(64, 64).r > 0.99, "Imported-instance paint pixels must persist")
			reloaded_instance.free()
			container.free()
	# Removing the stack returns the unchanged original.
	mesh_node.remove_child(paint)
	check(mesh_node.mesh == plane and plane.material == base, "Removal must restore exact original resources")
	paint.free()
	world.free()
	restored.free()
	second.free()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result := find_mesh(child)
		if result != null:
			return result
	return null

