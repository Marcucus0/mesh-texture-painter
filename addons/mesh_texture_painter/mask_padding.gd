@tool
extends RefCounted

const Geometry = preload("geometry.gd")

# GPU-only gutter extension. Interior paint values, including zero, stay intact.
# A map is shared by all layers of the same mesh surface and mask resolution.
static func build(mesh: Mesh, surface: int, size: int, uv_channel: int, margin: int = 3) -> PackedInt32Array:
	var arrays := mesh.surface_get_arrays(surface)
	var uv: PackedVector2Array = arrays[uv_channel]
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX]
	else:
		for i in uv.size():
			indices.append(i)
	var owner := PackedInt32Array()
	owner.resize(size * size)
	owner.fill(-1)
	var frontier := PackedInt32Array()
	for triangle in range(0, indices.size(), 3):
		var points: Array = [uv[indices[triangle]], uv[indices[triangle + 1]], uv[indices[triangle + 2]]]
		var bounds := Geometry.uv_bounds(points, size)
		for y in range(bounds.position.y, bounds.end.y):
			for x in range(bounds.position.x, bounds.end.x):
				var pixel := y * size + x
				if owner[pixel] >= 0:
					continue
				var bary := Geometry.barycentric((Vector2(x, y) + Vector2(0.5, 0.5)) / size, points)
				if minf(bary.x, minf(bary.y, bary.z)) >= -0.000001:
					owner[pixel] = pixel
					frontier.append(pixel)
	var pairs := PackedInt32Array()
	for distance in margin:
		var next := PackedInt32Array()
		for pixel in frontier:
			var x := pixel % size
			var y := pixel / size
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= size or ny >= size:
						continue
					var neighbor := ny * size + nx
					if owner[neighbor] >= 0:
						continue
					owner[neighbor] = owner[pixel]
					pairs.append(neighbor)
					pairs.append(owner[pixel])
					next.append(neighbor)
		frontier = next
		if frontier.is_empty():
			break
	return pairs

static func apply(image: Image, pairs: PackedInt32Array) -> Image:
	if pairs.is_empty():
		return image
	var source := image
	if source.get_format() != Image.FORMAT_L8:
		source = image.duplicate()
		source.convert(Image.FORMAT_L8)
	var bytes := source.get_data()
	for i in range(0, pairs.size(), 2):
		bytes[pairs[i]] = bytes[pairs[i + 1]]
	return Image.create_from_data(source.get_width(), source.get_height(), false, Image.FORMAT_L8, bytes)
