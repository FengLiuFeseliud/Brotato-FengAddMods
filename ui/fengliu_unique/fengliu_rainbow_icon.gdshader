shader_type canvas_item;
render_mode blend_add, unshaded;

uniform sampler2D icon_texture;
uniform vec2 overlay_size = vec2(1.0);
uniform float intensity = 0.45;
uniform float speed = 0.12;
uniform float hue_span = 0.85;
uniform float flow_direction = -1.0;

varying vec2 local_position;

vec3 hsv_to_rgb(vec3 c) {
	vec3 rgb = clamp(abs(mod(c.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	rgb = rgb * rgb * (3.0 - 2.0 * rgb);
	return c.z * mix(vec3(1.0), rgb, c.y);
}

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec2 uv = local_position / max(overlay_size, vec2(1.0));
	float mask = texture(icon_texture, uv).a;

	if (mask <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		// 与边框同一屏幕空间渐变：右上 → 左下
		float diag = (SCREEN_UV.x - SCREEN_UV.y + 1.0) * 0.5;
		float hue = fract(diag * hue_span + TIME * speed * flow_direction);
		vec3 rainbow = hsv_to_rgb(vec3(hue, 0.9, 1.0));

		COLOR = vec4(rainbow * intensity * mask, intensity * mask);
	}
}
