shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Трипланарная поверхность (стены, баррикады): текстура проецируется по мировым осям, без растяжения на боксах.
// Рельеф из яркости через производные, постапокалиптическая цветокоррекция, ржавые потёки по высоте.

uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile = 2.2;
uniform float sat = 0.75;
uniform float dark = 0.85;
uniform vec3 tint = vec3(1.04, 0.97, 0.87);
uniform float bump = 1.4;
uniform float roughness = 0.85;
uniform float metallic = 0.0;
uniform float grime = 0.35;

varying vec3 wp;
varying vec3 wn;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 w = pow(abs(wn), vec3(6.0));
	w /= (w.x + w.y + w.z);
	vec3 cx = texture(tex, wp.zy / tile).rgb;
	vec3 cy = texture(tex, wp.xz / tile).rgb;
	vec3 cz = texture(tex, wp.xy / tile).rgb;
	vec3 c = cx * w.x + cy * w.y + cz * w.z;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));

	float h = lum * bump * 0.035;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad);

	// копоть у земли и потёки: сильнее внизу, разной интенсивности по поверхности
	float low = 1.0 - clamp(wp.y / 1.6, 0.0, 1.0);
	float streak = vnoise(vec2(wp.x * 3.0 + wp.z * 3.0, wp.y * 0.6));
	float dirt = clamp(low * 0.7 + streak * 0.3, 0.0, 1.0) * grime;
	vec3 g = mix(vec3(lum), c, sat) * tint * dark;
	g = mix(g, g * vec3(0.45, 0.4, 0.36), dirt);
	ALBEDO = g;
	ROUGHNESS = clamp(roughness + dirt * 0.1, 0.0, 1.0);
	METALLIC = metallic;
	SPECULAR = 0.35;
}

