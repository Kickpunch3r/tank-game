// Ground for painted levels (LevelTerrain): grass on flat ground, rock on
// steep slopes and high up, painted terrain (mud, sand) from the vertex
// colours, and gentle noise so nothing looks uniform. A faint 4 m grid is kept
// so speed can still be judged. All colours can be changed on the material.
shader_type spatial;

uniform vec4 grass_colour : source_color = vec4(0.45, 0.50, 0.24, 1.0);
uniform vec4 grass_dry_colour : source_color = vec4(0.62, 0.57, 0.34, 1.0);
uniform vec4 rock_colour : source_color = vec4(0.50, 0.44, 0.37, 1.0);
uniform vec4 high_rock_colour : source_color = vec4(0.60, 0.57, 0.52, 1.0);
// Slopes steeper than this (degrees) turn to rock; the change happens over a few degrees.
uniform float rock_from_degrees = 32.0;
// Ground higher than this (metres) slowly turns to pale rock.
uniform float high_from_metres = 24.0;
// How strong the faint grid is (0 = none). It helps to judge speed.
uniform float grid_strength = 0.05;
uniform float grid_size = 4.0;
// Painted terrain (vertex colours: rgb = colour, alpha = how much).
uniform bool use_vertex_tint = true;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Smooth value noise, 0 to 1.
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
	vec2 ground = world_position.xz;
	// Large patches of greener and drier grass, plus fine speckle.
	float patches = noise(ground * 0.03) * 0.65 + noise(ground * 0.11) * 0.35;
	float speckle = noise(ground * 1.7);
	vec3 colour = mix(grass_colour.rgb, grass_dry_colour.rgb, smoothstep(0.35, 0.75, patches));
	colour *= 0.9 + 0.2 * speckle;

	// Steep ground is rock, with horizontal bands like layered stone.
	float slope = degrees(acos(clamp(world_normal.y, -1.0, 1.0)));
	float rockiness = smoothstep(rock_from_degrees - 4.0, rock_from_degrees + 4.0, slope);
	float bands = 0.88 + 0.12 * noise(vec2(world_position.y * 1.3, ground.x * 0.05 + ground.y * 0.05));
	vec3 rock = rock_colour.rgb * bands * (0.92 + 0.16 * speckle);
	colour = mix(colour, rock, rockiness);

	// High ground fades to pale rock.
	float high = smoothstep(high_from_metres, high_from_metres + 12.0, world_position.y);
	colour = mix(colour, high_rock_colour.rgb * (0.9 + 0.1 * speckle), high * 0.6);

	// Painted terrain (mud, sand) on top, keeping a little of the noise.
	if (use_vertex_tint) {
		// (Godot has already turned the vertex colours into linear colours.)
		colour = mix(colour, COLOR.rgb * (0.85 + 0.3 * speckle), COLOR.a);
	}

	// Faint grid, so speed is easy to judge.
	vec2 cell = floor(ground / grid_size);
	colour *= 1.0 - grid_strength * mod(cell.x + cell.y, 2.0);

	ALBEDO = colour;
	ROUGHNESS = 0.95;
}
