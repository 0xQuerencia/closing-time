shader_type spatial;
// Reflection of authored fixtures at their real positions. Analytic plane hits
// keep highlights in the same world place as the player walks; no screen copy.
render_mode cull_back, shadows_disabled, depth_draw_never, specular_schlick_ggx;
uniform bool windows_lit = true;
uniform sampler2D asphalt : source_color, filter_nearest_mipmap, repeat_enable;
varying vec3 world_point;
void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
vec2 wall_hit(vec3 p, vec3 ray, float wall_z) {
	float along = min((wall_z - p.z) / min(ray.z, -.018), 100.0);
	return (p + along * ray).xy;
}
float rect_glow(vec2 p, vec2 centre, vec2 half_extent, vec2 softness) {
	vec2 ramp = (abs(p-centre) - half_extent) / softness;
	return (1.0-smoothstep(0.0,1.0,ramp.x)) * (1.0-smoothstep(0.0,1.0,ramp.y));
}
void fragment() {
	vec3 p = world_point;
	// Low-amplitude world-locked ripples preserve a predominantly planar normal.
	vec2 ripple = vec2(
		.009 * sin(p.x*15.0 + p.z*21.0) + .006*cos(p.z*32.0-p.x*6.0),
		.016 * cos(p.z*23.0+p.x*3.9) + .006*sin(p.z*37.0+p.x*9.0));
	vec3 water_normal = normalize(vec3(ripple.x,1.0,ripple.y));
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD-p);
	vec3 reflected = reflect(-view_dir,water_normal);
	vec2 lamp = wall_hit(p,reflected,7.79);
	vec2 glaze = wall_hit(p,reflected,6.18);
	vec2 tube_blur = vec2(.14,.125);
	float fixtures = rect_glow(lamp,vec2(-6.0,3.083),vec2(.51,.043),tube_blur)
		+ rect_glow(lamp,vec2(-2.0,3.083),vec2(.51,.043),tube_blur)
		+ rect_glow(lamp,vec2(1.7,3.083),vec2(.51,.043),tube_blur);
	float glass = rect_glow(glaze,vec2(-6.18,1.54),vec2(1.15,.67),vec2(.32,.26))
		+ rect_glow(glaze,vec2(-2.67,1.48),vec2(1.16,.61),vec2(.32,.26))
		+ rect_glow(glaze,vec2(1.7,1.42),vec2(.64,.94),vec2(.27,.19));
	float mullion = max(rect_glow(glaze,vec2(-1.7,1.53),vec2(.046,.81),vec2(.06,.16)),
		rect_glow(glaze,vec2(1.7,1.41),vec2(.053,1.04),vec2(.067,.155)));
	float fresnel = pow(1.0-clamp(dot(water_normal,view_dir),0.0,1.0),4.0);
	float reflect_valid = 1.0 - smoothstep(-.38,-.06,reflected.z);
	// Retain the exact diffuse substrate and its tiled UVs; the standing water
	// gently darkens it rather than replacing pavement with an opaque mask.
	vec3 chips = texture(asphalt,(p.xz+vec2(14.0,-6.0))*.3125).rgb;
	float border = smoothstep(0.04,.94,COLOR.a);
	float roof = rect_glow(lamp,vec2(-1.1,3.36),vec2(7.2,.22),vec2(.37,.24));
	float panels = rect_glow(lamp,vec2(-4.06,3.74),vec2(2.45,.30),vec2(.27,.15))
		+ rect_glow(lamp,vec2(2.27,3.74),vec2(1.92,.30),vec2(.27,.15));
	float seam = smoothstep(.10,.23,abs(fract((lamp.x+.02)/.72)-.5));
	float strength = (.40 + .60*fresnel) * reflect_valid;
	NORMAL = normalize((VIEW_MATRIX * vec4(water_normal,0.0)).xyz);
	ALBEDO = chips*vec3(.71,.74,.75);
	ROUGHNESS = mix(.17,.36,1.0-border) + (.035*chips.g);
	SPECULAR = .49;
	METALLIC = .08;
	vec3 skyline = mix(vec3(.040,.052,.069),vec3(.081,.059,.039),roof);
	vec3 front = (windows_lit ? glass : 0.0)*(1.0-.74*mullion)*vec3(.120,.089,.050)
		+ panels*(1.0-.48*seam)*vec3(.126,.043,.034);
	EMISSION = chips*vec3(.052,.045,.041) + skyline*(.32+.37*fresnel)
		+ strength * (fixtures*vec3(1.04,.77,.43) + front);
	ALPHA = border * clamp(.39 + .21*fresnel + .21*fixtures, 0.0, .78);
}
