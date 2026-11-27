shader_type spatial;
// Local hand-authored standing water, with no screen read or reflection camera.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
varying vec2 world_xz;
void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
float lamp(float x, float at, float width) {
	return exp(-pow((x-at)/width,2.0));
}
void fragment() {
	vec2 uv = UV - .5;
	vec2 p = world_xz;
	float view_compression = clamp(abs(dot(normalize(VIEW), normalize(NORMAL))), 0.0, 1.0);
	float fringe = .035*sin(p.y*11.0 + p.x*7.0) + .024*sin(p.y*27.0-p.x*3.1);
	float y = p.y + fringe;
	float strips = lamp(p.x,-6.0,.34) + lamp(p.x,-2.0,.34) + lamp(p.x,1.7,.40);
	float soft = lamp(p.x,-6.0,.91) + lamp(p.x,-2.0,.91) + lamp(p.x,1.7,1.01);
	float warm = soft * exp(-pow((y-12.8)/3.6,2.0))*.15 + strips * exp(-pow((y-12.9)/1.9,2.0))*.36;
	float surface = .84 + .16*sin(y*14.0);
	float dull = .085 + .065*(1.0-view_compression);
	ALBEDO = vec3(.035,.051,.076) + vec3(1.0,.66,.33)*warm*surface;
	ALPHA = COLOR.a * clamp(dull + .37*(1.0-smoothstep(.11,.48,length(uv))) + warm*.82,0.0,.79);
}
