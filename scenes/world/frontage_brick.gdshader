shader_type spatial;
// Local baked practical bounce on real exterior masonry, not a global ambient lift.
render_mode specular_disabled;
uniform sampler2D brick : source_color, filter_nearest_mipmap, repeat_enable;
varying vec3 metres;
void vertex() {
	metres = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float pool(vec2 a, vec2 b, vec2 r) {
	vec2 d = (a-b)/r;
	return exp(-dot(d,d));
}
void fragment() {
	vec3 texel = texture(brick, UV).rgb;
	vec2 xy = metres.xy;
	float at_left = pool(xy,vec2(-6.9,2.03),vec2(2.05,1.05));
	float at_centre = pool(xy,vec2(-2.3,1.74),vec2(1.92,1.55));
	float at_right = pool(xy,vec2(2.27,1.97),vec2(2.40,1.62));
	float right_edge = .58*pool(xy,vec2(6.4,1.22),vec2(3.1,1.21));
	float fascia = smoothstep(3.31,3.79,xy.y)*(.62+.38*sin(xy.x*.32+.2));
	float wear = pow(clamp(texel.r*1.21+.17,.14,1.0),.65);
	ALBEDO = texel * vec3(1.03,.89,.75);
	ROUGHNESS = .93;
	float bounce = .043 + .16*max(at_right, max(at_centre,at_left)) + .070*right_edge + .07*fascia;
	EMISSION = (vec3(.82,.44,.25)*bounce + vec3(.08,.095,.087)*fascia*.10)*wear;
}
