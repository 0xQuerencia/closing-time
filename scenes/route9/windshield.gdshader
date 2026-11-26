shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform bool wipers_active = true;

float drops_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(71.43, 149.37))) * 25239.413);
}

void fragment() {
	// The glass uses cell 6 of the wagon's 4 by 4 atlas with a 3 px gutter.
	vec2 glass = (UV * 512.0 - vec2(259.5, 131.5)) / 121.0;
	vec2 grid = glass * vec2(65.0, 28.0);
	vec2 cell = floor(grid);
	vec2 drop = fract(grid);
	float seed = drops_hash(cell);
	float streak = 1.0 - smoothstep(.025, .068, abs(drop.x - .22 - seed * .57 + drop.y * .11));
	streak *= smoothstep(.22, .54, drop.y) * (1.0 - smoothstep(.57, .91, drop.y));
	float active_drop = step(.76, seed);
	float arc = length((glass - vec2(.63, 1.15)) * vec2(1.0, .84));
	float swept = smoothstep(.16, .24, arc) * (1.0 - smoothstep(.66, .74, arc));
	float remaining = wipers_active ? mix(1.0, .27, swept) : 1.0;
	ALBEDO = vec3(.43, .48, .48);
	ALPHA = .022 + streak * active_drop * remaining * .23;
}
