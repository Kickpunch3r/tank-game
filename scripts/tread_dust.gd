class_name TreadDust
extends Node3D
## Dust thrown up behind each tread of the physics tank: coloured like the
## ground it's on (sand, mud, or dusty earth), more of it the faster the tread
## goes, and white spray in water. Looks only. Can be switched off from the
## Tab panel (Graphics > Dust).
##
## Put it inside the tank's Visual/Hull node. Water is found by the group
## "water_surface" (the level's water plane).

const WATER_GROUP: StringName = &"water_surface"
## Dust colour on ordinary firm ground.
const EARTH_DUST := Color(0.6, 0.55, 0.45)
const SPRAY := Color(0.85, 0.9, 0.95)
## Tread speed (m/s) at which the dust is at its thickest.
const FULL_DUST_SPEED: float = 6.0
## Slower than this, no dust.
const MIN_SPEED: float = 0.6

var _tank: Node3D
var _emitters: Array[GPUParticles3D] = []
var _materials: Array[ParticleProcessMaterial] = []


func _ready() -> void:
	add_to_group(GraphicsOptions.DUST_GROUP)
	_tank = _find_tank()
	for side: float in [-1.0, 1.0]:
		_build_emitter(side)
	visible = GraphicsOptions.dust


func _process(_delta: float) -> void:
	if _tank == null:
		return
	var water: Node3D = get_tree().get_first_node_in_group(WATER_GROUP) as Node3D
	var speeds: Array[float] = [_tank.get(&"left_tread_speed"), _tank.get(&"right_tread_speed")]
	var terrains: Array = [_tank.get(&"left_terrain"), _tank.get(&"right_terrain")]
	var grounded: Array = _tank.get(&"probe_grounded")
	for side: int in 2:
		var emitter: GPUParticles3D = _emitters[side]
		var on_ground: bool = grounded.slice(side * 4, side * 4 + 4).has(true)
		var speed: float = absf(speeds[side])
		emitter.emitting = visible and on_ground and speed > MIN_SPEED
		emitter.amount_ratio = clampf(speed / FULL_DUST_SPEED, 0.15, 1.0)
		var in_water: bool = water != null and emitter.global_position.y < water.global_position.y
		_materials[side].color = SPRAY if in_water else dust_colour(terrains[side])
		# Thrown up behind the tread: from its back end going forward, its front end in reverse.
		var backward: float = 1.0 if speeds[side] >= 0.0 else -1.0
		emitter.position.z = 2.6 * backward
		_materials[side].direction = Vector3(0.0, 1.0, 0.8 * backward)


## The colour of the dust thrown up from this ground (null = firm ground).
static func dust_colour(terrain: TerrainType) -> Color:
	if terrain == null:
		return EARTH_DUST
	return terrain.colour.lightened(0.15)


func is_throwing_dust(side: int) -> bool:
	return _emitters[side].emitting


func _find_tank() -> Node3D:
	var node: Node = get_parent()
	while node != null and not (&"left_tread_speed" in node):
		node = node.get_parent()
	return node as Node3D


func _build_emitter(side: float) -> void:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 1.0, 0.8)
	process.spread = 25.0
	process.initial_velocity_min = 1.0
	process.initial_velocity_max = 3.0
	process.gravity = Vector3(0.0, -3.0, 0.0)
	process.damping_min = 1.0
	process.damping_max = 2.0
	process.scale_min = 0.6
	process.scale_max = 1.3
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.25, 0.05, 0.1)
	# Grow and fade out.
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.6))
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	process.scale_curve = grow_texture
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.55))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	process.color_ramp = fade_texture
	_materials.append(process)

	var puff := QuadMesh.new()
	puff.size = Vector2(0.9, 0.9)
	puff.material = _puff_material()
	var emitter := GPUParticles3D.new()
	emitter.name = "DustLeft" if side < 0.0 else "DustRight"
	emitter.amount = 40
	emitter.lifetime = 1.4
	emitter.emitting = false
	emitter.process_material = process
	emitter.draw_pass_1 = puff
	emitter.position = Vector3(side * 1.5, 0.15, 2.6)
	emitter.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 10, 16))
	add_child(emitter)
	_emitters.append(emitter)


## A soft round puff, facing the camera, tinted by each particle's colour.
func _puff_material() -> StandardMaterial3D:
	var round := Gradient.new()
	round.set_color(0, Color(1, 1, 1, 1))
	round.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = round
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = texture
	return material
