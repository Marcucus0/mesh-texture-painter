shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
uniform sampler2D paint_mask : filter_linear, repeat_disable;
uniform bool mask_uv2 = false;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D metallic_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_normal = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform vec4 roughness_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 metallic_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 ao_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform float normal_strength = 1.0;
uniform float specular_value = 0.5;
uniform float ao_light_affect = 0.0;
uniform float opacity = 1.0;
uniform float transition = 1.0;
uniform float roughness_value = 0.8;
uniform float metallic_value = 0.0;
uniform float paint_depth_bias = 0.00001;
void vertex() {
	// Keep the surface silhouette and world-space lighting identical to the base.
	// Bias only projected depth: normal displacement loses precision at grazing
	// angles and can open cracks where adjacent faces have different normals.
	vec4 view_position = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 clip_position = PROJECTION_MATRIX * view_position;
	float bias = paint_depth_bias;
	if (PROJECTION_MATRIX[3][3] > 0.5) { bias *= 0.1; }
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// Godot uses a reversed projection here too, before its OpenGL remapping.
	clip_position.z += clip_position.w * bias * 0.1;
#else
	// Forward+/Mobile use reversed Z, with greater values closer to the camera.
	clip_position.z += max(abs(clip_position.z), abs(clip_position.w) * 1e-12) * bias;
#endif
	POSITION = clip_position;
}
void fragment() {
	float mask = texture(paint_mask, mask_uv2 ? UV2 : UV).r;
	if (mask < 0.0001) { discard; }
	vec2 uv = UV * uv_scale + uv_offset;
	vec4 color = texture(albedo_tex, uv) * tint;
	ALBEDO = color.rgb;
	ALPHA = pow(mask, transition) * opacity * color.a;
	ROUGHNESS = dot(texture(roughness_tex, uv), roughness_channel) * roughness_value;
	METALLIC = dot(texture(metallic_tex, uv), metallic_channel) * metallic_value;
	SPECULAR = specular_value;
	AO = dot(texture(ao_tex, uv), ao_channel);
	AO_LIGHT_AFFECT = ao_light_affect;
	if (has_normal) { NORMAL_MAP = texture(normal_tex, uv).rgb; NORMAL_MAP_DEPTH = normal_strength; }
}
