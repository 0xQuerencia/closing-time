shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform bool pixelation_enabled = false;
uniform bool palette_enabled = false;
uniform bool analog_enabled = true;
uniform float pixel_size : hint_range(1.0, 3.0, 0.25) = 1.5;
uniform float palette_steps : hint_range(16.0, 48.0, 1.0) = 32.0;
uniform float dither_strength : hint_range(0.0, 0.4, 0.01) = 0.12;
uniform float grain_strength : hint_range(0.0, 0.025, 0.001) = 0.005;
uniform float scanline_strength : hint_range(0.0, 0.025, 0.001) = 0.002;
uniform float vignette_strength : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float saturation : hint_range(0.0, 1.0, 0.01) = 0.94;
uniform float chroma_strength : hint_range(0.0, 1.0, 0.01) = 0.12;
uniform float tape_wobble : hint_range(0.0, 0.001, 0.00005) = 0.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	if (pixelation_enabled) {
		vec2 snapped = (floor(pixel / pixel_size) + 0.5) * pixel_size;
		uv = clamp(snapped * SCREEN_PIXEL_SIZE, SCREEN_PIXEL_SIZE * 0.5, vec2(1.0) - SCREEN_PIXEL_SIZE * 0.5);
	}
	vec2 sample_uv = uv;
	if (analog_enabled) {
		// A barely visible line drift and sub-pixel color split suggest a worn
		// consumer tape without obscuring the product labels or interaction UI.
		float band = floor(SCREEN_UV.y * 192.0);
		sample_uv.x += sin(TIME * 1.7 + band * 0.37) * tape_wobble;
	}
	vec3 color = textureLod(screen_texture, sample_uv, 0.0).rgb;
	if (analog_enabled && chroma_strength > 0.0) {
		float fringe = SCREEN_PIXEL_SIZE.x * chroma_strength;
		vec2 red_uv = clamp(sample_uv + vec2(fringe, 0.0), SCREEN_PIXEL_SIZE * 0.5, vec2(1.0) - SCREEN_PIXEL_SIZE * 0.5);
		vec2 blue_uv = clamp(sample_uv - vec2(fringe, 0.0), SCREEN_PIXEL_SIZE * 0.5, vec2(1.0) - SCREEN_PIXEL_SIZE * 0.5);
		color.r = textureLod(screen_texture, red_uv, 0.0).r;
		color.b = textureLod(screen_texture, blue_uv, 0.0).b;
	}
	if (palette_enabled) {
		float threshold = hash12(floor(pixel / 2.0)) - 0.5;
		color = floor(color * palette_steps + threshold * dither_strength) / palette_steps;
	}
	if (analog_enabled) {
		float grain = hash12(pixel + floor(TIME * 18.0)) - 0.5;
		// The former sin(integer * PI) was always zero, so scanlines never rendered.
		float scanline = mod(floor(pixel.y), 2.0);
		float luma = dot(color, vec3(0.299, 0.587, 0.114));
		color = mix(vec3(luma), color, saturation);
		vec2 centered = SCREEN_UV - 0.5;
		color *= 1.0 - vignette_strength * smoothstep(0.25, 0.85, length(centered * vec2(1.0, 0.85)));
		color += grain * grain_strength;
		color *= 1.0 - scanline * scanline_strength;
	}
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
