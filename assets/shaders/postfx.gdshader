shader_type canvas_item;

// Постобработка кадра: виньетка, лёгкая хроматическая аберрация по краям, плёночное зерно,
// тёплая «тон-мап» подкраска теней (teal) и светов (orange). Интенсивность регулируется из кода.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float vignette = 0.42;
uniform float aberration = 0.0016;
uniform float grain = 0.045;
uniform float grade = 0.35;
uniform float flash = 0.0;              // красная вспышка (урон/взрыв рядом)
uniform vec3 flash_color = vec3(1.0, 0.35, 0.15);
uniform float time_s = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p + 19.19);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);
	// хроматическая аберрация растёт к краям
	vec2 off = c * aberration * (1.0 + r2 * 6.0);
	float rch = texture(screen_tex, uv + off).r;
	float gch = texture(screen_tex, uv).g;
	float bch = texture(screen_tex, uv - off).b;
	vec3 col = vec3(rch, gch, bch);

	// цветокоррекция: тени в холодную сторону, света в тёплую
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 shadow_tint = vec3(0.86, 1.0, 1.08);
	vec3 light_tint = vec3(1.1, 1.0, 0.86);
	vec3 graded = col * mix(shadow_tint, light_tint, smoothstep(0.15, 0.75, l));
	col = mix(col, graded, grade);

	// виньетка
	float v = smoothstep(0.18, 0.85, r2 * 2.2);
	col *= 1.0 - v * vignette;

	// зерно
	float n = hash(uv * vec2(1920.0, 1080.0) + fract(time_s) * 97.0) - 0.5;
	col += n * grain * (1.0 - l * 0.6);

	// вспышка урона по краям экрана
	col = mix(col, flash_color, flash * smoothstep(0.05, 0.6, r2 * 2.4));

	COLOR = vec4(col, 1.0);
}
