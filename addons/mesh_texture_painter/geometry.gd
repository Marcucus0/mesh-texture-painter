@tool
extends RefCounted
const I18n = preload("localization.gd")

var triangles: Array[Dictionary] = []
var bvh := TriangleMesh.new()
var error: String = ""
var needs_uv_generation := false
var _world_transform := Transform3D.IDENTITY
var _world_groups: Array[Dictionary] = []
var _visibility: Array[PackedByteArray] = []
var _visibility_camera := Transform3D.IDENTITY
var _visibility_projection := Projection()
var _cache_size := 0
var _visibility_radius := -1.0
var _samples: Array[PackedVector3Array] = []
var _sample_center := Vector3.INF
var _sample_radius := -1.0

func build(mesh: Mesh, uv_channel: int = Mesh.ARRAY_TEX_UV) -> bool:
	triangles.clear()
	_world_groups.clear()
	_visibility.clear()
	_cache_size = 0
	_samples.clear()
	error = ""
	needs_uv_generation = false
	var faces := PackedVector3Array()
	for surface in mesh.get_surface_count():
		if mesh is ArrayMesh and mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			error = I18n.text("Seules les surfaces triangulées sont prises en charge.")
			return false
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs := PackedVector2Array()
		if arrays[uv_channel] != null:
			uvs = arrays[uv_channel]
		if uvs.size() != vertices.size():
			needs_uv_generation = true
			error = I18n.text("UV1 absents sur la surface %d.") % surface
			return false
		for uv in uvs:
			if uv.x < 0.0 or uv.y < 0.0 or uv.x > 1.0 or uv.y > 1.0:
				needs_uv_generation = true
				error = I18n.text("UV1 hors [0,1] sur la surface %d.") % surface
				return false
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in vertices.size():
				indices.append(i)
		for i in range(0, indices.size(), 3):
			var p: Array[Vector3] = []
			var uv: Array[Vector2] = []
			for j in 3:
				p.append(vertices[indices[i + j]])
				uv.append(uvs[indices[i + j]])
				faces.append(p[j])
			if absf((uv[1] - uv[0]).cross(uv[2] - uv[0])) < 0.00000000000001:
				needs_uv_generation = true
				error = I18n.text("Triangle UV dégénéré sur la surface %d.") % surface
				return false
			triangles.append({"p": p, "uv": uv, "surface": surface})
	if not bvh.create_from_faces(faces):
		error = I18n.text("Impossible de construire le BVH.")
		return false
	return true

static func barycentric(point: Vector2, uv: Array) -> Vector3:
	var a: Vector2 = uv[1] - uv[0]
	var b: Vector2 = uv[2] - uv[0]
	var c: Vector2 = point - uv[0]
	var denominator := a.cross(b)
	if absf(denominator) < 0.00000000000001:
		return Vector3(-1, -1, -1)
	var y := c.cross(b) / denominator
	var z := a.cross(c) / denominator
	return Vector3(1.0 - y - z, y, z)

func overlapping_uvs(size: int = 128) -> bool:
	var occupied: Dictionary = {}
	for triangle in triangles:
		var uv: Array = triangle.uv
		var bounds := uv_bounds(uv, size)
		for y in range(bounds.position.y, bounds.end.y):
			for x in range(bounds.position.x, bounds.end.x):
				var w := barycentric((Vector2(x, y) + Vector2(0.5, 0.5)) / size, uv)
				if minf(w.x, minf(w.y, w.z)) <= 0.00001:
					continue
				var key := Vector3i(x, y, triangle.surface)
				if occupied.has(key):
					return true
				occupied[key] = true
	return false

static func uv_bounds(uv: Array, size: int) -> Rect2i:
	var low: Vector2 = uv[0]
	var high := low
	for point: Vector2 in uv:
		low = low.min(point)
		high = high.max(point)
	var start := Vector2i((low * size).floor()).clamp(Vector2i.ZERO, Vector2i(size, size))
	var end := Vector2i((high * size).ceil()).clamp(Vector2i.ZERO, Vector2i(size, size))
	return Rect2i(start, end - start)

func hit(target: MeshInstance3D, origin: Vector3, direction: Vector3) -> Dictionary:
	var inverse := target.global_transform.affine_inverse()
	var result := bvh.intersect_ray(inverse * origin, (inverse.basis * direction).normalized())
	if not result.is_empty():
		result.position = target.global_transform * result.position
		result.normal = (target.global_basis.inverse().transposed() * result.normal).normalized()
	return result

func prepare_world(transform: Transform3D, size: int) -> bool:
	var geometry_changed := _world_groups.is_empty() or transform != _world_transform or size != _cache_size
	if geometry_changed:
		_world_groups.clear()
		_world_transform = transform
		_cache_size = size
		for offset in range(0, triangles.size(), 64):
			var entries: Array[Dictionary] = []
			var group_bounds := AABB()
			for index in range(offset, mini(offset + 64, triangles.size())):
				var triangle := triangles[index]
				var a: Vector3 = transform * triangle.p[0]
				var b: Vector3 = transform * triangle.p[1]
				var c: Vector3 = transform * triangle.p[2]
				var bounds := AABB(a, Vector3.ZERO).expand(b).expand(c)
				group_bounds = bounds if entries.is_empty() else group_bounds.merge(bounds)
				entries.append({"a": a, "b": b, "c": c, "bounds": bounds, "uv": triangle.uv, "surface": triangle.surface})
			_world_groups.append({"bounds": group_bounds, "entries": entries})
		_visibility.clear()
		_samples.clear()
	return geometry_changed

func _prepare_dab(transform: Transform3D, camera: Camera3D, images: Array, radius: float) -> void:
	var geometry_changed := prepare_world(transform, images[0].get_width())
	var camera_transform := camera.get_camera_transform()
	var projection := camera.get_camera_projection()
	if geometry_changed or _visibility.is_empty() or camera_transform != _visibility_camera or projection != _visibility_projection or radius != _visibility_radius:
		_samples.clear()
		_visibility_radius = radius
		_visibility_camera = camera_transform
		_visibility_projection = projection
		_visibility.clear()
		for image: Image in images:
			var pixels := PackedByteArray()
			pixels.resize(image.get_width() * image.get_height())
			_visibility.append(pixels)

# Cache only geometry and visibility, never authored paint or blend values.
# Visibility remains exact per texel and is invalidated on camera/mesh changes.
func dab(target: MeshInstance3D, images: Array, center: Vector3, camera: Camera3D,
		radius: float, strength: float, hardness: float, falloff: float, mode: int) -> PackedInt32Array:
	var transform := target.global_transform
	var inverse := transform.affine_inverse()
	var size: int = images[0].get_width()
	_prepare_dab(transform, camera, images, radius)
	if not _samples.is_empty() and center == _sample_center and radius == _sample_radius:
		return _apply_samples(images, strength, hardness, falloff, mode)
	_sample_center = center
	_sample_radius = radius
	_samples.clear()
	_samples.resize(images.size())
	var visited: Dictionary = {}
	var candidates: Array[Dictionary] = []
	for group in _world_groups:
		if not group.bounds.grow(radius).has_point(center):
			continue
		for entry in group.entries:
			if entry.bounds.grow(radius).has_point(center):
				candidates.append(entry)
	for triangle in candidates:
		var a: Vector3 = triangle.a
		var b: Vector3 = triangle.b
		var c: Vector3 = triangle.c
		var visibility: PackedByteArray = _visibility[triangle.surface]
		var samples: PackedVector3Array = _samples[triangle.surface]
		var uv: Array = triangle.uv
		var bounds := brush_bounds(uv, a, b, c, center, radius, size)
		for y in range(bounds.position.y, bounds.end.y):
			for x in range(bounds.position.x, bounds.end.x):
				var weights := barycentric((Vector2(x, y) + Vector2(0.5, 0.5)) / size, uv)
				if minf(weights.x, minf(weights.y, weights.z)) < -0.00001:
					continue
				var world := a * weights.x + b * weights.y + c * weights.z
				var distance := world.distance_to(center) / radius
				if distance > 1.0:
					continue
				var pixel_index := y * size + x
				if visibility[pixel_index] == 0:
					var ray_origin := camera.global_position
					if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
						ray_origin = world + camera.global_basis.z * camera.far
					var visible := bvh.intersect_ray(inverse * ray_origin, (inverse.basis * (world - ray_origin)).normalized())
					visibility[pixel_index] = 2 if not visible.is_empty() and (transform * visible.position).distance_to(world) <= maxf(0.0001, radius * 0.001) else 1
				if visibility[pixel_index] != 2:
					continue
				var key := Vector3i(x, y, triangle.surface)
				if visited.has(key):
					continue
				visited[key] = true
				samples.append(Vector3(x, y, distance))
		_visibility[triangle.surface] = visibility
		_samples[triangle.surface] = samples
	return _apply_samples(images, strength, hardness, falloff, mode)

func _apply_samples(images: Array, strength: float, hardness: float, falloff: float, mode: int) -> PackedInt32Array:
	var dirty := PackedInt32Array()
	for surface in _samples.size():
		if _samples[surface].is_empty():
			continue
		var image: Image = images[surface]
		var source: Image = image.duplicate() if mode == 3 else null
		var size := image.get_width()
		var changed := false
		for sample in _samples[surface]:
			var x := int(sample.x)
			var y := int(sample.y)
			var weight := strength
			if sample.z > hardness:
				weight *= pow(clampf((1.0 - sample.z) / maxf(0.001, 1.0 - hardness), 0.0, 1.0), falloff)
			var old := image.get_pixel(x, y).r
			var value := old
			match mode:
				0, 1: value = old + (1.0 - old) * weight
				2, 4: value = old * (1.0 - weight)
				3:
					var sum := 0.0
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							sum += source.get_pixel(clampi(x + dx, 0, size - 1), clampi(y + dy, 0, size - 1)).r
					value = lerpf(old, sum / 9.0, weight)
			if not is_equal_approx(old, value):
				image.set_pixel(x, y, Color(value, value, value, 1.0))
				changed = true
		if changed:
			dirty.append(surface)
	return dirty

# Project the brush sphere into the triangle's UV plane before visiting texels.
# This keeps a small dab on a large triangle from scanning the whole atlas.
static func brush_bounds(uv: Array, a: Vector3, b: Vector3, c: Vector3, center: Vector3, radius: float, size: int) -> Rect2i:
	var e1 := b - a
	var e2 := c - a
	var g11 := e1.dot(e1)
	var g12 := e1.dot(e2)
	var g22 := e2.dot(e2)
	var determinant := g11 * g22 - g12 * g12
	if determinant <= 0.000000000001:
		return Rect2i()
	var uv1: Vector2 = uv[1] - uv[0]
	var uv2: Vector2 = uv[2] - uv[0]
	var gradient_u := (e1 * (g22 * uv1.x - g12 * uv2.x) + e2 * (g11 * uv2.x - g12 * uv1.x)) / determinant
	var gradient_v := (e1 * (g22 * uv1.y - g12 * uv2.y) + e2 * (g11 * uv2.y - g12 * uv1.y)) / determinant
	var uv_center: Vector2 = uv[0] + Vector2(gradient_u.dot(center - a), gradient_v.dot(center - a))
	var extent := Vector2(gradient_u.length(), gradient_v.length()) * radius
	return uv_bounds(uv, size).intersection(uv_bounds([uv_center - extent, uv_center + extent], size))
