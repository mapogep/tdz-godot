shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Материал моделей Kenney (текстура-атлас): приглушённые цвета, тёплый пыльный оттенок, копоть снизу вверх.
// Заменяет исходные материалы GLB, чтобы весь мир выглядел в едином постапокалиптическом стиле.

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float sat = 0.55;
uniform float dark = 0.9;
uniform vec3 tint = vec3(1.04, 0.97, 0.87);
uniform float roughness = 0.88;
uniform float metallic = 0.0;
uniform float grime = 0.25;
uniform float emission_boost = 0.0;

varying float wy;

void vertex() {
	wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	vec3 c = t.rgb * albedo_color.rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(vec3(lum), c, sat) * tint * dark;
	// копоть снизу
	float low = 1.0 - clamp(wy / 3.5, 0.0, 1.0);
	g = mix(g, g * vec3(0.5, 0.46, 0.42), low * grime);
	ALBEDO = g;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = 0.3;
	EMISSION = g * emission_boost;
}
