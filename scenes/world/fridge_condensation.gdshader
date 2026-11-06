shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, unshaded;

uniform float fog_strength : hint_range(0.0, 0.35) = 0.06;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 centre = (uv - vec2(0.54, 0.52)) * vec2(1.25, 0.92);
	float patch = 1.0 - smoothstep(0.12, 0.62, length(centre));
	float grain = hash(floor(uv * vec2(44.0, 32.0)));
	float mist = smoothstep(0.16, 0.86, grain);
	float streaks = smoothstep(0.97, 1.0, hash(vec2(floor(uv.x * 28.0), floor(uv.y * 5.0))));
	float droplets = step(0.994, hash(floor(uv * vec2(58.0, 42.0))));
	ALBEDO = vec3(0.67, 0.75, 0.72);
	ROUGHNESS = 0.95;
	ALPHA = fog_strength * patch * (0.24 + mist * 0.42 + streaks * 0.28 + droplets * 0.45);
}
