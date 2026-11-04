shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform bool pixelation_enabled = false;
uniform bool palette_enabled = true;
uniform bool analog_enabled = true;
uniform float pixel_size : hint_range(1.0, 3.0, 0.25) = 1.5;
uniform float palette_steps : hint_range(16.0, 48.0, 1.0) = 32.0;
uniform float dither_strength : hint_range(0.0, 0.4, 0.01) = 0.12;
uniform float grain_strength : hint_range(0.0, 0.025, 0.001) = 0.004;
uniform float scanline_strength : hint_range(0.0, 0.025, 0.001) = 0.004;

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
	vec3 color = textureLod(screen_texture, uv, 0.0).rgb;
	if (palette_enabled) {
		float threshold = hash12(floor(pixel / 2.0)) - 0.5;
		color = floor(color * palette_steps + threshold * dither_strength) / palette_steps;
	}
	if (analog_enabled) {
		float grain = hash12(pixel + floor(TIME * 18.0)) - 0.5;
		float scanline = sin(pixel.y * 3.14159265);
		color += grain * grain_strength;
		color *= 1.0 - scanline * scanline_strength;
	}
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
