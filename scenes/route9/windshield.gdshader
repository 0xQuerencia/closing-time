shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform bool wipers_active = true;

float drops_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(71.43, 149.37))) * 25239.413);
}

void fragment() {
	// The glass uses cell 6 of the wagon's 4 by 4 atlas with a 3 px gutter.
	vec2 glass = (UV * 512.0 - vec2(259.5, 131.5)) / 121.0;
	vec2 grid = glass * vec2(43.0, 20.0);
	vec2 cell = floor(grid);
	vec2 drop = fract(grid);
	float seed = drops_hash(cell);
	float dx = drop.x - .28 - fract(seed * 8.45) * .44 + drop.y * .09;
	float bead = 1.0 - smoothstep(.045, .101, length(vec2(dx, (drop.y - .73) * .68)));
	float trail = (1.0 - smoothstep(.009, .036, abs(dx))) * smoothstep(.21,.72,drop.y);
	trail *= 1.0 - smoothstep(.73,.82,drop.y);
	vec2 from_pivot = (glass - vec2(.316,.978)) * vec2(1.37,-.79);
	float radius = length(from_pivot);
	float turn = atan(from_pivot.y,from_pivot.x);
	float swept = smoothstep(.252,.318,radius) * (1.0 - smoothstep(.586,.63,radius));
	swept *= smoothstep(.02,.13,turn) * (1.0 - smoothstep(1.13,1.24,turn));
	float edge = 1.0 - smoothstep(.006,.074,min(glass.x,1.0-glass.x));
	float remaining = wipers_active ? mix(1.0,.11,swept) : 1.0;
	float droplets = (bead*.18 + trail*.13) * step(.84 - edge*.23,seed) * remaining;
	ALBEDO = vec3(.52,.59,.61);
	ALPHA = .006 + edge*.033 + droplets;
}
