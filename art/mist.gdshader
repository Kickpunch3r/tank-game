// Soft mist sheets for HazeZone: big quads that always turn to face the camera
// (around the up axis), with soft edges and slowly drifting wisps. They fade
// out close to the camera and where they meet the ground, so no hard edges show.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 mist_colour : source_color = vec4(0.86, 0.87, 0.85, 1.0);
// How thick one sheet is at its middle (0 to 1).
uniform float strength = 0.22;
// Sheets fade out when the camera is closer than this (metres).
uniform float fade_near = 14.0;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

varying vec3 world_position;

void vertex() {
	// Face the camera, keeping the sheet upright and its size.
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec2 size = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	world_position = centre + right * VERTEX.x * size.x + vec3(0.0, 1.0, 0.0) * VERTEX.y * size.y;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world_position, 1.0);
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

void fragment() {
	// Soft oval, thinning towards its top.
	vec2 from_middle = (UV - 0.5) * vec2(2.0, 2.0);
	float shape = 1.0 - smoothstep(0.4, 1.0, length(from_middle));
	shape *= mix(1.0, 0.5, UV.y < 0.5 ? (0.5 - UV.y) * 2.0 : 0.0);
	// Drifting wisps.
	float wisps = 0.55 + 0.45 * noise(world_position.xz * 0.06 + vec2(world_position.y * 0.1, TIME * 0.05));
	// Fade near the camera, and where the sheet meets the ground behind it.
	float near = smoothstep(fade_near * 0.4, fade_near, distance(world_position, CAMERA_POSITION_WORLD));
	float depth = texture(depth_texture, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 behind = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	behind.xyz /= behind.w;
	float gap = -behind.z - (-VERTEX.z);
	float soft = smoothstep(0.0, 6.0, gap);
	ALBEDO = mist_colour.rgb;
	ALPHA = clamp(strength * shape * wisps * near * soft, 0.0, 1.0);
}
