shader_type spatial;
// Three physical shallow basins; stretched practical/window luminaires, not grain or a screen read.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
varying vec2 world_xz;
void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
float belt(float n, float at, float width) {
	float d = (n-at)/width;
	return exp(-d*d);
}
void fragment() {
	vec2 uv = UV - .5;
	vec2 p = world_xz;
	float wave = .11*sin(p.y*8.0 + p.x*4.0) + .028*sin(p.y*24.0-p.x*2.6);
	float x = p.x + wave * (.35+max(0.0,p.y-10.0)*.11);
	float y = p.y + .12*sin(p.x*3.0+p.y*10.0);
	float long_pool = belt(x,-6.0,1.41) + belt(x,-2.0,1.56) + belt(x,1.7,1.55);
	float fixtures = belt(x,-6.0,.79) + belt(x,-2.0,.76) + belt(x,1.7,.81);
	float strip = belt(x,-5.7,1.82) + belt(x,-2.65,1.48) + belt(x,.32,1.56);
	float rear = belt(y,12.50,2.08);
	float reach = belt(y,14.57,4.32);
	float glazed = belt(y,15.08,3.09) * (.5+.5*sin(y*23.0));
	float warm = long_pool*reach*.24 + fixtures*rear*.49;
	float tinted = strip*glazed*.134;
	float smooth_water = (1.0-smoothstep(.08,.53,length(uv)));
	vec3 shallow = vec3(.103,.091,.079)+vec3(.89,.64,.34)*warm+vec3(.32,.40,.28)*tinted;
	ALBEDO = shallow;
	ALPHA = COLOR.a * clamp(.18+smooth_water*.47+warm*.39,0.0,.87);
}
