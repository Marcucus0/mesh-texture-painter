@tool
extends RefCounted
const Geometry = preload("res://addons/mesh_texture_painter/geometry.gd")
static func mesh() -> ArrayMesh:
	var vertices := PackedVector3Array([
		Vector3(-2, 0, -2), Vector3(2, 0, 2), Vector3(-2, 0, 2),
		Vector3(-2, 0, -2), Vector3(2, 0.6, -2), Vector3(2, 0, 2)])
	var uv := PackedVector2Array([
		Vector2(0.05, 0.1), Vector2(0.45, 0.9), Vector2(0.05, 0.9),
		Vector2(0.55, 0.1), Vector2(0.95, 0.1), Vector2(0.95, 0.9)])
	var normals := PackedVector3Array()
	for triangle in 2:
		var index := triangle * 3
		var normal := -(vertices[index + 1] - vertices[index]).cross(vertices[index + 2] - vertices[index]).normalized()
		for i in 3:
			normals.append(normal)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
static func mask(source: Mesh, size: int, first_only: bool = false) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_L8)
	image.fill(Color.BLACK)
	var geometry := Geometry.new()
	geometry.build(source)
	for i in geometry.triangles.size():
		if first_only and i > 0:
			continue
		var uv: Array = geometry.triangles[i].uv
		var bounds := Geometry.uv_bounds(uv, size)
		for y in range(bounds.position.y, bounds.end.y):
			for x in range(bounds.position.x, bounds.end.x):
				var bary := Geometry.barycentric((Vector2(x, y) + Vector2(0.5, 0.5)) / size, uv)
				if minf(bary.x, minf(bary.y, bary.z)) >= -0.000001:
					image.set_pixel(x, y, Color.WHITE)
	return image
static func sample(image: Image, uv: Vector2) -> float:
	var point := uv * Vector2(image.get_size()) - Vector2(0.5, 0.5)
	var x := floori(point.x)
	var y := floori(point.y)
	var a := image.get_pixel(clampi(x, 0, image.get_width()-1), clampi(y, 0, image.get_height()-1)).r
	var b := image.get_pixel(clampi(x+1, 0, image.get_width()-1), clampi(y, 0, image.get_height()-1)).r
	var c := image.get_pixel(clampi(x, 0, image.get_width()-1), clampi(y+1, 0, image.get_height()-1)).r
	var d := image.get_pixel(clampi(x+1, 0, image.get_width()-1), clampi(y+1, 0, image.get_height()-1)).r
	return lerpf(lerpf(a, b, point.x - x), lerpf(c, d, point.x - x), point.y - y)
