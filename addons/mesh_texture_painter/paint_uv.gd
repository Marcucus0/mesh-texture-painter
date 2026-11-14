@tool
extends RefCounted
const I18n = preload("localization.gd")

var error: String = ""

# Unwrap a private proxy, never the imported/shared mesh. UV2 stores the atlas.
func generate(source: Mesh) -> ArrayMesh:
	var copy := ArrayMesh.new()
	for surface in source.get_surface_count():
		if source is ArrayMesh and source.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			error = I18n.text("Le dépliage automatique nécessite des triangles.")
			return null
		var arrays := source.surface_get_arrays(surface).duplicate(true)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if arrays[Mesh.ARRAY_NORMAL] == null:
			var builder := SurfaceTool.new()
			builder.create_from(source, surface)
			builder.generate_normals()
			arrays = builder.commit_to_arrays()
		if arrays[Mesh.ARRAY_INDEX] == null:
			var indices := PackedInt32Array()
			for i in vertices.size():
				indices.append(i)
			arrays[Mesh.ARRAY_INDEX] = indices
		copy.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var longest := source.get_aabb().size.length()
	var result := copy.lightmap_unwrap(Transform3D.IDENTITY, maxf(longest / 128.0, 0.0001))
	if result != OK:
		error = I18n.text("Échec du dépliage automatique Godot (code %d).") % result
		return null
	if copy.get_surface_count() != source.get_surface_count():
		error = I18n.text("Le dépliage a supprimé une surface dégénérée ; peinture interrompue.")
		return null
	var output := ArrayMesh.new()
	for surface in copy.get_surface_count():
		var arrays := copy.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var atlas: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		if atlas.size() != vertices.size():
			error = I18n.text("Le dépliage Godot ne fournit pas de coordonnées valides.")
			return null
		# Missing UV1 needs coordinates for the painted PBR textures too.
		if arrays[Mesh.ARRAY_TEX_UV] == null or arrays[Mesh.ARRAY_TEX_UV].size() != vertices.size():
			arrays[Mesh.ARRAY_TEX_UV] = atlas.duplicate()
		output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	output.regen_normal_maps()
	return output
