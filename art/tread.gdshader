// Track links for the physics tank's treads: dark cross ridges that move
// along the tread loop. TankDetails sets `travel` (metres the tread has moved),
// so the top run moves forward and the bottom run backward, like a real track.
shader_type spatial;

uniform vec4 link_colour : source_color = vec4(0.16, 0.16, 0.15, 1.0);
uniform vec4 gap_colour : source_color = vec4(0.04, 0.04, 0.04, 1.0);
// Length of one track link, in metres.
uniform float link_length = 0.32;
// How far the tread has moved, in metres (set by TankDetails).
uniform float travel = 0.0;

varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	// Upper half of the loop moves forward (-z), lower half backward.
	float along = local_position.y > 0.0 ? local_position.z + travel : local_position.z - travel;
	float link = fract(along / link_length);
	float gap = smoothstep(0.72, 0.78, link) * (1.0 - smoothstep(0.94, 1.0, link));
	ALBEDO = mix(link_colour.rgb, gap_colour.rgb, gap);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
