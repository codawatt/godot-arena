class_name ArenaPlayer
extends CharacterBody3D

@onready var controller: PlayerController = $PlayerController
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var name_label: Label3D = $NameLabel
@onready var weapon_view: MeshInstance3D = $Head/Camera3D/WeaponView

var peer_id: int = 0
var display_name: String = "Player"
var state: PlayerState = PlayerState.new()
var aim_yaw: float = 0.0
var aim_pitch: float = 0.0
var is_local_visual: bool = false
var is_server_copy: bool = false
var is_remote_interpolated: bool = false
var target_position: Vector3
var target_velocity: Vector3
var target_yaw: float = 0.0
var target_pitch: float = 0.0
var has_snapshot: bool = false
var correction: Vector3 = Vector3.ZERO
var next_fire_msec: Dictionary = {}
var attack_counter: int = 0


func is_arena_player() -> bool:
	return true


func configure(
	new_peer_id: int,
	new_display_name: String,
	local_visual: bool,
	server_copy: bool,
	spawn_position: Vector3
) -> void:
	peer_id = new_peer_id
	display_name = new_display_name
	is_local_visual = local_visual
	is_server_copy = server_copy
	is_remote_interpolated = not server_copy and not local_visual
	global_position = spawn_position
	target_position = spawn_position
	name = "Player_%d" % peer_id
	name_label.text = display_name
	name_label.visible = not local_visual
	camera.current = local_visual
	body_mesh.visible = not local_visual
	weapon_view.visible = local_visual
	if server_copy:
		collision_layer = 2
		collision_mask = 3
	elif local_visual:
		# Predicted clients collide only with the static world. Players remain server-owned.
		collision_layer = 0
		collision_mask = 1
	else:
		collision_layer = 0
		collision_mask = 0
	_update_visual_pose()
	_update_dead_visual()


func server_simulate(command: Dictionary, delta: float) -> void:
	if state.is_dead:
		velocity = Vector3.ZERO
		return
	aim_yaw = float(command.get("yaw", aim_yaw))
	aim_pitch = float(command.get("pitch", aim_pitch))
	controller.simulate(
		self,
		Vector2(command.get("move", Vector2.ZERO)),
		aim_yaw,
		bool(command.get("jump", false)),
		delta
	)
	_update_visual_pose()


func client_predict(command: Dictionary, delta: float) -> void:
	if is_server_copy or not is_local_visual or state.is_dead:
		return
	aim_yaw = float(command.get("yaw", aim_yaw))
	aim_pitch = float(command.get("pitch", aim_pitch))
	controller.simulate(
		self,
		Vector2(command.get("move", Vector2.ZERO)),
		aim_yaw,
		bool(command.get("jump", false)),
		delta
	)
	_update_visual_pose()


func make_snapshot(ack_sequence: int, now_msec: int) -> Dictionary:
	return {
		"position": global_position,
		"velocity": velocity,
		"yaw": aim_yaw,
		"pitch": aim_pitch,
		"ack": ack_sequence,
		"state": state.serialize(),
		"respawn_remaining": maxf(0.0, float(state.respawn_at_msec - now_msec) / 1000.0),
	}


func apply_snapshot(snapshot: Dictionary) -> void:
	state.apply_serialized(Dictionary(snapshot.get("state", {})))
	var server_position: Vector3 = snapshot.get("position", global_position)
	var server_velocity: Vector3 = snapshot.get("velocity", velocity)
	var server_yaw := float(snapshot.get("yaw", aim_yaw))
	var server_pitch := float(snapshot.get("pitch", aim_pitch))

	if is_local_visual:
		var error := server_position - global_position
		if error.length() > 1.75 or state.is_dead:
			global_position = server_position
			velocity = server_velocity
			correction = Vector3.ZERO
		else:
			correction += error * 0.35
	else:
		target_position = server_position
		target_velocity = server_velocity
		target_yaw = server_yaw
		target_pitch = server_pitch
		if not has_snapshot:
			global_position = server_position
			aim_yaw = server_yaw
			aim_pitch = server_pitch
			has_snapshot = true
	_update_dead_visual()
	_update_weapon_visual()


func respawn_at(spawn_position: Vector3) -> void:
	state.reset_for_spawn()
	global_position = spawn_position
	target_position = spawn_position
	velocity = Vector3.ZERO
	correction = Vector3.ZERO
	next_fire_msec.clear()
	_update_dead_visual()


func mark_dead(respawn_time_msec: int) -> void:
	state.is_dead = true
	state.respawn_at_msec = respawn_time_msec
	velocity = Vector3.ZERO
	_update_dead_visual()


func get_aim_origin() -> Vector3:
	return global_position + Vector3.UP * 0.65


func get_aim_direction() -> Vector3:
	return Vector3(
		-sin(aim_yaw) * cos(aim_pitch),
		sin(aim_pitch),
		-cos(aim_yaw) * cos(aim_pitch)
	).normalized()


func _process(delta: float) -> void:
	if is_remote_interpolated and has_snapshot:
		var blend := 1.0 - exp(-14.0 * delta)
		global_position = global_position.lerp(target_position, blend)
		aim_yaw = lerp_angle(aim_yaw, target_yaw, blend)
		aim_pitch = lerpf(aim_pitch, target_pitch, blend)
		velocity = target_velocity
	elif is_local_visual and not is_server_copy and correction.length_squared() > 0.000001:
		var applied := correction * minf(1.0, delta * 12.0)
		global_position += applied
		correction -= applied
	_update_visual_pose()


func _update_visual_pose() -> void:
	rotation.y = aim_yaw
	head.rotation.x = aim_pitch
	#head.rotation.x = -aim.pitch #inverse mouse look


func _update_dead_visual() -> void:
	var alive := not state.is_dead
	if is_server_copy:
		collision_layer = 2 if alive else 0
		collision_mask = 3 if alive else 0
	body_mesh.visible = alive and not is_local_visual
	name_label.visible = alive and not is_local_visual
	weapon_view.visible = alive and is_local_visual


func _update_weapon_visual() -> void:
	var colors := [
		Color(0.2, 0.9, 1.0),
		Color(0.45, 0.65, 1.0),
		Color(1.0, 0.68, 0.25),
		Color(1.0, 0.25, 0.2),
	]
	var material := StandardMaterial3D.new()
	material.albedo_color = colors[clampi(state.selected_weapon, 0, 3)]
	material.emission_enabled = true
	material.emission = material.albedo_color * 0.45
	weapon_view.material_override = material
