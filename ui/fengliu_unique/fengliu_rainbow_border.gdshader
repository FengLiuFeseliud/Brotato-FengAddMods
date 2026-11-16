shader_type canvas_item;
render_mode unshaded;

uniform vec2 overlay_size = vec2(1.0);
uniform float border_width = 3.0;
uniform float corner_radius = 8.0;
uniform float fill_alpha = 0.0;
uniform float border_alpha = 0.95;
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
	vec2 half_size = overlay_size * 0.5;
	float radius = min(corner_radius, min(half_size.x, half_size.y));
	vec2 p = abs(local_position - half_size) - (half_size - vec2(radius));
	float dist = length(max(p, vec2(0.0))) + min(max(p.x, p.y), 0.0) - radius;

	// 只画边框 + 可选淡填充，中心透明
	float outer = smoothstep(1.0, 0.0, dist);
	float inner = smoothstep(-border_width - 1.0, -border_width, dist);
	float border = outer * inner;
	float fill = fill_alpha * smoothstep(-border_width, -border_width - 1.0, dist);

	// 屏幕空间渐变：右上 → 左下
	float diag = (SCREEN_UV.x - SCREEN_UV.y + 1.0) * 0.5;
	float hue = fract(diag * hue_span + TIME * speed * flow_direction);
	vec3 rainbow = hsv_to_rgb(vec3(hue, 0.9, 1.0));
	float alpha = max(border * border_alpha, fill);

	COLOR = vec4(rainbow, alpha);
}
