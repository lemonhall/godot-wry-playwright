shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D web_tex;
uniform float reveal : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 c = texture(web_tex, UV);

	// Reveal from top to bottom (UV.y: 0 -> 1).
	// Godot 4 shaders don't allow `return` in `fragment()`, so we branch.
	if (UV.y > reveal) {
		c = vec4(0.0, 0.0, 0.0, 1.0);
	}

	ALBEDO = c.rgb;
	ALPHA = c.a;
}
