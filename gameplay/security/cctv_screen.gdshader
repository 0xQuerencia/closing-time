shader_type spatial;
render_mode unshaded, cull_back;
// The office CRT: a low-res camera feed with restrained analog noise. Powered off it is dark glass.
uniform sampler2D feed : source_color, filter_nearest;
uniform float power : hint_range(0.0, 1.0) = 1.0;
uniform float static_amount : hint_range(0.0, 1.0) = 0.0;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
uniform float tracking_amount : hint_range(0.0, 1.0) = 0.0;
uniform float playback : hint_range(0.0, 1.0) = 0.0;
uniform float flip_y = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	if (flip_y > 0.5) {
		uv.y = 1.0 - uv.y;
	}
	float band = floor(uv.y * 60.0);
	float shear = (hash(vec2(band, floor(TIME * 12.0))) - 0.5) * 0.06 * glitch;
	uv.x += shear;
	vec3 c = texture(feed, uv).rgb;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, 0.22) * vec3(0.8, 1.0, 0.88);
	c = c * mix(1.0, 1.22, playback) + vec3(0.012 * playback);
	c *= 0.84 + 0.16 * sin(uv.y * 240.0 * 3.14159);
	float track_line = step(0.975, fract(uv.y * 38.0 + TIME * 2.8));
	c *= 1.0 - track_line * tracking_amount * 0.18;
	float blind_corner = 1.0 - smoothstep(0.0, 0.22, distance(uv, vec2(0.99, 0.02)));
	c = mix(c, c * 0.2, blind_corner * tracking_amount * 0.42);
	float n = hash(floor(uv * vec2(180.0, 130.0)) + floor(TIME * 25.0));
	c += (n - 0.5) * (0.002 + static_amount * 0.08);
	float roll = smoothstep(0.0, 0.03, abs(fract(uv.y - TIME * 0.05) - 0.5) - 0.47);
	c += roll * 0.03;
	vec2 d = uv - 0.5;
	c *= 1.0 - dot(d, d) * 1.25;
	vec3 dark = vec3(0.012, 0.016, 0.014);
	ALBEDO = mix(dark, clamp(c, 0.0, 1.0), power);
}
