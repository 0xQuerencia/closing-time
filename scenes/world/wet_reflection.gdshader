shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
	vec2 p = UV;
	float edge = pow(max(0.0, 1.0-abs(p.x-.5)*2.0), 2.0);
	float strips = hash(floor(p*vec2(23.0,180.0)));
	float wave = sin(p.y*160.0 + sin(p.x*41.0)*3.0)*.5+.5;
	float fade = pow(1.0-p.y, 1.8);
	ALBEDO = vec3(1.0,.64,.27);
	ALPHA = edge*fade*(.025 + step(.57,strips)*wave*.55);
}
