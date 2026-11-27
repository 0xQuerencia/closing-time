shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
	vec2 p = UV;
	float edge = pow(max(0.0, 1.0-abs(p.x-.5)*2.0), 1.4);
	float strips = hash(floor(p*vec2(31.0,190.0)));
	float wave = sin(p.y*160.0 + sin(p.x*41.0)*3.0)*.5+.5;
	float fade = pow(1.0-p.y, 1.45);
	ALBEDO = vec3(1.0,.74,.42);
	float cobbles = smoothstep(.21,.72,strips);
	ALPHA = strength*edge*fade*(.025 + cobbles*(.09 + wave*.35));
}
