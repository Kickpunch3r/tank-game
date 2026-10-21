// Two-colour checker pattern in world space, so you can judge speed and distance.
// The tiles stay fixed in the world however the ground mesh is sized or placed.
shader_type spatial;

uniform vec4 color_a : source_color = vec4(0.76, 0.66, 0.48, 1.0);
uniform vec4 color_b : source_color = vec4(0.68, 0.58, 0.41, 1.0);
// Width of one tile, in metres.
uniform float tile_size = 2.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = floor(world_position.xz / tile_size);
	float pick = mod(cell.x + cell.y, 2.0);
	ALBEDO = mix(color_a.rgb, color_b.rgb, pick);
	ROUGHNESS = 0.95;
}
