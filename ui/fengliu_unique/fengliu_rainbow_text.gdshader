shader_type canvas_item;
render_mode unshaded;

uniform float speed = 0.12;
uniform float hue_span = 0.85;
uniform float flow_direction = -1.0;
uniform float saturation = 0.9;
uniform float value = 1.0;

vec3 hsv_to_rgb(vec3 c) {
	vec3 rgb = clamp(abs(mod(c.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	rgb = rgb * rgb * (3.0 - 2.0 * rgb);
	return c.z * mix(vec3(1.0), rgb, c.y);
}

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	float brightness = max(source.r, max(source.g, source.b));

	// 与边框同一屏幕空间渐变：右上 → 左下
	float diag = (SCREEN_UV.x - SCREEN_UV.y + 1.0) * 0.5;
	float hue = fract(diag * hue_span + TIME * speed * flow_direction);
	vec3 rainbow = hsv_to_rgb(vec3(hue, saturation, value));

	// 保留字形 alpha，只替换文字颜色
	COLOR = vec4(rainbow * brightness, source.a);
}
