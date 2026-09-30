shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Р—РµРјР»СЏ РїСѓСЃС‚РѕС€Рё: РјРёСЂРѕРІР°СЏ РїСЂРѕРµРєС†РёСЏ СЃРІРµСЂС…Сѓ, В«Р°РЅС‚Рё-С‚Р°Р№Р»РёРЅРіВ» (РґРІРµ РІС‹Р±РѕСЂРєРё СЃ СЂР°Р·РЅС‹Рј РјР°СЃС€С‚Р°Р±РѕРј Рё РїРѕРІРѕСЂРѕС‚РѕРј,
// СЃРјРµС€Р°РЅРЅС‹Рµ С€СѓРјРѕРј), СЂРµР»СЊРµС„ РёР· СЏСЂРєРѕСЃС‚Рё С‚РµРєСЃС‚СѓСЂС‹ (bump С‡РµСЂРµР· РїСЂРѕРёР·РІРѕРґРЅС‹Рµ), РїРѕСЃС‚Р°РїРѕРєР°Р»РёРїС‚РёС‡РµСЃРєР°СЏ С†РІРµС‚РѕРєРѕСЂСЂРµРєС†РёСЏ.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_size = 4.5;
uniform float sat = 0.55;
uniform float dark = 0.82;
uniform vec3 tint = vec3(1.04, 0.97, 0.87);
uniform float bump = 1.6;
uniform float roughness = 0.95;
uniform float field_size = 20.0;
uniform float vignette_start = 60.0;

varying vec3 wpos;

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

vec3 sample_tile(vec2 uv, float m) {
	vec3 a = texture(albedo_tex, uv).rgb;
	vec3 b = texture(albedo_tex, mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * 0.73 + vec2(0.37, 0.11)).rgb;
	return mix(a, b, m);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz / tile_size;
	float m = smoothstep(0.35, 0.65, vnoise(uv * 0.31));
	vec3 c = sample_tile(uv, m);
	float lum = dot(c, vec3(0.299, 0.587, 0.114));

	// СЂРµР»СЊРµС„: РїСЂРѕРёР·РІРѕРґРЅС‹Рµ СЏСЂРєРѕСЃС‚Рё в†’ РІРѕР·РјСѓС‰РµРЅРёРµ РЅРѕСЂРјР°Р»Рё (Mikkelsen)
	float h = lum * bump * 0.035;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dhdx = dFdx(h);
	float dhdy = dFdy(h);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad);

	// РєСЂСѓРїРЅС‹Рµ РїСЏС‚РЅР°: Р·Р°С‚РµРјРЅРµРЅРёРµ Рё СЃР»Р°Р±Р°СЏ СЃРјРµРЅР° РѕС‚С‚РµРЅРєР°, С‡С‚РѕР±С‹ Р·РµРјР»СЏ РЅРµ РІС‹РіР»СЏРґРµР»Р° В«РєРѕРІСЂРѕРјВ»
	float macro = 0.82 + 0.36 * vnoise(wpos.xz * 0.09) + 0.1 * vnoise(wpos.xz * 0.6);
	vec3 g = mix(vec3(lum), c, sat) * tint * dark * macro;
	// Сѓ СЃС‚РµРЅ Рё РІРґР°Р»Рё Р·РµРјР»СЏ С‚РµРјРЅРµРµ (РіСЂСЏР·СЊ, РєРѕРїРѕС‚СЊ)
	vec2 d = abs(wpos.xz - vec2(field_size * 0.5)) - vec2(field_size * 0.5);
	float outside = clamp(max(d.x, d.y) / 8.0, 0.0, 1.0);
	g *= mix(1.0, 0.72, outside);
	ALBEDO = g;
	ROUGHNESS = roughness;
	SPECULAR = 0.18;
}

