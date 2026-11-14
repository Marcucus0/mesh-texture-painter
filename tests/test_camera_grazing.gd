extends SceneTree
const Geometry = preload("res://Addons/mesh_texture_painter/geometry.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene: Node3D = load("res://camera-island.tscn").instantiate()
	root.add_child(scene)
	var target: MeshInstance3D = scene.get_node("Island_Terrain")
	var paint = target.get_node("TexturePaint")
	var white := Image.create(1, 1, false, Image.FORMAT_RGB8)
	white.fill(Color.WHITE)
	var layer = paint.layers[0]
	layer.albedo = ImageTexture.create_from_image(white)
	layer.tint = Color.RED
	layer.normal_map = null
	layer.ao_map = null
	layer.roughness_map = null
	layer.metallic_map = null
	layer.specular = 0
	layer.metallic = 0
	paint.rebuild()
	if "--baseline" in OS.get_cmdline_user_args():
		var shader := Shader.new()
		shader.code = FileAccess.get_file_as_string("res://paint-before-depth.gdshader")
		for proxy in paint._proxies:
			var material: Material = proxy.material_override
			while material != null:
				material.shader = shader
				material = material.next_pass
		paint.rebuild()
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.03, 0.03, 0.03)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 1
	root.add_child(environment)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.near = 0.01
	camera.far = 4000
	var geometry := Geometry.new()
	if not geometry.build(paint.paint_mesh, Mesh.ARRAY_TEX_UV2):
		push_error(geometry.error)
		quit(1)
		return
	var masks: Array = []
	for surface in layer.masks.size():
		masks.append(layer._display_mask(surface))
		var maximum := 0
		for value in layer.masks[surface].get_data():
			maximum = maxi(maximum, value)
		print("GRAZING MASK: surface ", surface, " max=", maximum)
	var total := 0
	var misses := 0
	var views := 0
	var anchor := Vector3.ZERO
	var best_area := 0.0
	for triangle in geometry.triangles:
		var normal: Vector3 = (triangle.p[1] - triangle.p[0]).cross(triangle.p[2] - triangle.p[0])
		if absf(normal.normalized().y) < 0.95:
			continue
		var center_uv: Vector2 = (triangle.uv[0] + triangle.uv[1] + triangle.uv[2]) / 3.0
		if normal.length() > best_area and sample_mask(masks[triangle.surface], center_uv) > 0.9:
			best_area = normal.length()
			anchor = target.to_global((triangle.p[0] + triangle.p[1] + triangle.p[2]) / 3.0)
	print("GRAZING ANCHOR: ", anchor)
	var obstacle := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(8, 0.6, 1)
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color.BLUE
	blue.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = blue
	obstacle.mesh = box
	root.add_child(obstacle)
	obstacle.position = anchor + Vector3(0, 0.3, 0)
	var occlusion_failures := 0
	for x in [0.0, 10.0]:
		camera.position = anchor + Vector3(x, 1.8, 150)
		for pitch in [-10.0, -2.0, 0.0, 2.0, 8.0]:
			camera.rotation_degrees = Vector3(pitch, 0, 0)
			for frame in 3:
				await process_frame
			RenderingServer.force_draw()
			var image := root.get_texture().get_image()
			var obstacle_pixel := Vector2i(camera.unproject_position(obstacle.position)).clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE)
			if image.get_pixelv(obstacle_pixel).b < 0.8:
				occlusion_failures += 1
			if x == 0.0 and pitch == 0.0:
				image.save_png("res://tests/output/grazing-current.png")
			var sampled := 0
			var missing := 0
			var horizon := camera.unproject_position(camera.position + Vector3(0, 0, -1000)).y
			for py in range(maxi(0, floori(horizon) - 2), mini(580, floori(horizon) + 42)):
				for px in range(24, 780, 24):
					var pixel := Vector2(px + 0.5, py + 0.5)
					var hit: Dictionary = geometry.hit(target, camera.project_ray_origin(pixel), camera.project_ray_normal(pixel))
					if hit.is_empty():
						continue
					var triangle: Dictionary = geometry.triangles[hit.face_index]
					var local: Vector3 = target.to_local(hit.position)
					var weights := barycentric(local, triangle.p)
					var uv: Vector2 = triangle.uv[0] * weights.x + triangle.uv[1] * weights.y + triangle.uv[2] * weights.z
					if sample_mask(masks[triangle.surface], uv) < 0.9:
						continue
					sampled += 1
					if image.get_pixel(px, py).g > 0.4:
						missing += 1
			print("GRAZING VIEW: x=", x, " pitch=", pitch, " missing=", missing, "/", sampled)
			total += sampled
			misses += missing
			views += 1
			if sampled > 0 and float(missing) / sampled > 0.01:
				failures += 1
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 80
	camera.position = anchor + Vector3(0, 50, 0)
	camera.look_at(anchor, Vector3.FORWARD)
	box.size = Vector3(8, 0.005, 8)
	obstacle.position = anchor + Vector3(0, 0.01, 0)
	for frame in 3:
		await process_frame
	RenderingServer.force_draw()
	var ortho_image := root.get_texture().get_image()
	var obstacle_pixel := Vector2i(camera.unproject_position(obstacle.position))
	if ortho_image.get_pixelv(obstacle_pixel).b < 0.8:
		occlusion_failures += 1
	print("GRAZING RESULT: ", views, " views, ", misses, "/", total, " missing, ", failures, " failed views; occlusion failures ", occlusion_failures)
	quit(1 if failures or occlusion_failures or total < 100 else 0)
func barycentric(point: Vector3, p: Array) -> Vector3:
	var u: Vector3 = p[1] - p[0]
	var v: Vector3 = p[2] - p[0]
	var w: Vector3 = point - p[0]
	var uu := u.dot(u)
	var uv := u.dot(v)
	var vv := v.dot(v)
	var wu := w.dot(u)
	var wv := w.dot(v)
	var divisor := uu * vv - uv * uv
	if absf(divisor) < 0.000000000001:
		return Vector3(1, 0, 0)
	var y := (vv * wu - uv * wv) / divisor
	var z := (uu * wv - uv * wu) / divisor
	return Vector3(1 - y - z, y, z)
func sample_mask(image: Image, uv: Vector2) -> float:
	var p := uv * Vector2(image.get_size()) - Vector2(0.5, 0.5)
	var x := floori(p.x)
	var y := floori(p.y)
	var width := image.get_width()
	var height := image.get_height()
	var a := image.get_pixel(clampi(x, 0, width-1), clampi(y, 0, height-1)).r
	var b := image.get_pixel(clampi(x+1, 0, width-1), clampi(y, 0, height-1)).r
	var c := image.get_pixel(clampi(x, 0, width-1), clampi(y+1, 0, height-1)).r
	var d := image.get_pixel(clampi(x+1, 0, width-1), clampi(y+1, 0, height-1)).r
	return lerpf(lerpf(a,b,p.x-x),lerpf(c,d,p.x-x),p.y-y)
