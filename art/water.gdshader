// Water surface: darker where it is deep, clearer and lighter where it is
// shallow, a soft foam line where it meets the shore, and a gently moving
// surface (only its shading moves; the surface itself stays flat, so it is
// cheap). Colours and depths can be changed on the material.
shader_type spatial;
render_mode blend_mix, cull_disabled;

uniform vec4 shallow_colour : source_color = vec4(0.30, 0.52, 0.52, 1.0);
uniform vec4 deep_colour : source_color = vec4(0.06, 0.20, 0.30, 1.0);
uniform vec4 foam_colour : source_color = vec4(0.92, 0.95, 0.96, 1.0);
// Water this deep (metres) or more shows the full deep colour.
uniform float deep_from_metres = 1.8;
// Foam where the water is shallower than this (metres).
uniform float foam_metres = 0.25;
// How much the surface ripples (0 = mirror flat).
uniform float ripple_strength = 0.35;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Two layers of slow ripples drifting in different directions.
float ripples(vec2 p, float time) {
	return noise(p * 0.45 + time * vec2(0.06, 0.035)) + 0.5 * noise(p * 1.2 - time * vec2(0.04, 0.07));
}

void fragment() {
	// How deep the water is here: the ground behind this pixel, from the depth buffer.
	float depth = texture(depth_texture, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 view_floor = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_floor.xyz /= view_floor.w;
	vec3 floor_world = (INV_VIEW_MATRIX * vec4(view_floor.xyz, 1.0)).xyz;
	float water_depth = max(world_position.y - floor_world.y, 0.0);

	float deepness = clamp(water_depth / deep_from_metres, 0.0, 1.0);
	vec3 colour = mix(shallow_colour.rgb, deep_colour.rgb, deepness);
	float alpha = mix(0.45, 0.9, deepness);

	// Foam along the shore, broken up and drifting a little.
	float foam = 1.0 - smoothstep(0.0, foam_metres, water_depth);
	foam *= 0.55 + 0.45 * noise(world_position.xz * 0.9 + TIME * 0.25);
	colour = mix(colour, foam_colour.rgb, foam * 0.75);
	alpha = max(alpha, foam * 0.85);

	// Ripples: tilt the surface's shading normal with the moving noise.
	vec2 p = world_position.xz;
	float e = 0.4;
	float h = ripples(p, TIME);
	float dx = ripples(p + vec2(e, 0.0), TIME) - h;
	float dz = ripples(p + vec2(0.0, e), TIME) - h;
	vec3 world_normal = normalize(vec3(-dx * ripple_strength / e, 1.0, -dz * ripple_strength / e));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

	ALBEDO = colour;
	ALPHA = alpha;
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
}
