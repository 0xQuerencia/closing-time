shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(cell),hash(cell+vec2(1,0)),f.x),mix(hash(cell+vec2(0,1)),hash(cell+vec2(1,1)),f.x),f.y);
}
void fragment() {
	vec2 p = UV;
	float distortion = noise(p*vec2(5.0,24.0));
	float edge = pow(max(0.0,1.0-abs(p.x-.5+(distortion-.5)*.18)*2.0),2.0);
	float ripples = noise(p*vec2(12.0,95.0));
	float fade = pow(1.0-p.y,1.6);
	ALBEDO = vec3(1.0,.72,.37);
	ALPHA = edge*fade*(.045+smoothstep(.25,.8,ripples)*.28);
}
