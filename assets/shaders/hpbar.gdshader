shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// Полоска HP: билборд с заливкой по доле frac. Один узел на объект, без спрайтов и текстур.

uniform float frac = 1.0;
uniform vec4 fill_color : source_color = vec4(0.35, 0.84, 0.29, 1.0);
uniform vec4 back_color : source_color = vec4(0.09, 0.02, 0.0, 0.8);
uniform vec4 border_color : source_color = vec4(0.0, 0.0, 0.0, 0.9);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, 1, 0), vec4(0, 0, 0, 1));
}

void fragment() {
	vec2 uv = UV;
	float bx = 0.03;
	float by = 0.16;
	bool border = uv.x < bx || uv.x > 1.0 - bx || uv.y < by || uv.y > 1.0 - by;
	vec4 c;
	if (border) {
		c = border_color;
	} else {
		float x = (uv.x - bx) / (1.0 - 2.0 * bx);
		c = x <= frac ? fill_color : back_color;
		// лёгкий градиент по высоте — «объём»
		c.rgb *= 0.85 + 0.3 * (1.0 - abs(uv.y - 0.5) * 2.0);
	}
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
