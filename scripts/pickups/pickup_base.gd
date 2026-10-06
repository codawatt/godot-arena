class_name PickupBase
extends Area3D

enum Kind { HEALTH, ARMOR, AMMO, WEAPON }

@export_enum("Health", "Armor", "Ammo", "Weapon") var pickup_kind: int = Kind.HEALTH
@export var amount: int = 25
@export var respawn_delay: float = 12.0
@export var allow_over_max: bool = false
@export var weapon_id: int = 0
@export var visual_color: Color = Color.WHITE

@onready var visual: MeshInstance3D = $Visual
@onready var collision: CollisionShape3D = $CollisionShape3D

var available: bool = true
var respawn_at_msec: int = 0
var base_height: float = 0.0
var phase: float = 0.0


func _ready() -> void:
	add_to_group("pickups")
	base_height = position.y
	phase = float(abs(name.hash()) % 628) / 100.0
	body_entered.connect(_on_body_entered)
	_apply_material()
	_apply_available_visual()


func _process(_delta: float) -> void:
	if not available:
		return
	rotation.y = fmod(Time.get_ticks_msec() * 0.0015 + phase, TAU)
	position.y = base_height + sin(Time.get_ticks_msec() * 0.003 + phase) * 0.16


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server() or available or respawn_at_msec <= 0:
		return
	if Time.get_ticks_msec() >= respawn_at_msec:
		replicate_available.rpc(true, 0)


func configure_ammo(ammo_weapon_id: int, pickup_amount: int) -> void:
	weapon_id = ammo_weapon_id
	amount = pickup_amount


func configure_weapon(picked_weapon_id: int, pickup_ammo: int, color: Color) -> void:
	weapon_id = picked_weapon_id
	amount = pickup_ammo
	visual_color = color
	if is_node_ready():
		_apply_material()


func server_try_collect(player) -> bool:
	if not multiplayer.is_server() or not available or player == null or player.state.is_dead:
		return false
	if global_position.distance_to(player.global_position) > 2.0:
		return false
	var applied := false
	var game_server := get_node("/root/Main/GameServer")
	match pickup_kind:
		Kind.HEALTH:
			applied = player.state.add_health(amount, allow_over_max)
		Kind.ARMOR:
			applied = player.state.add_armor(amount, allow_over_max)
		Kind.AMMO:
			var ammo_weapon: WeaponBase = game_server.weapon_system.get_weapon(weapon_id)
			if ammo_weapon != null:
				applied = player.state.add_ammo(weapon_id, amount, ammo_weapon.maximum_ammo)
		Kind.WEAPON:
			applied = player.state.unlock_weapon(weapon_id)
			var weapon: WeaponBase = game_server.weapon_system.get_weapon(weapon_id)
			if weapon != null:
				applied = player.state.add_ammo(weapon_id, amount, weapon.maximum_ammo) or applied
	if not applied:
		return false
	respawn_at_msec = Time.get_ticks_msec() + int(respawn_delay * 1000.0)
	replicate_available.rpc(false, respawn_at_msec)
	return true


func get_network_state() -> Dictionary:
	return {
		"available": available,
		"respawn_at_msec": respawn_at_msec,
	}


func apply_bootstrap_state(state_data: Dictionary) -> void:
	available = bool(state_data.get("available", true))
	respawn_at_msec = int(state_data.get("respawn_at_msec", 0))
	_apply_available_visual()


@rpc("authority", "call_local", "reliable")
func replicate_available(new_available: bool, new_respawn_at_msec: int) -> void:
	available = new_available
	respawn_at_msec = new_respawn_at_msec
	_apply_available_visual()


func _on_body_entered(body: Node3D) -> void:
	if multiplayer.is_server() and body.has_method("is_arena_player"):
		server_try_collect(body)


func _apply_material() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = visual_color
	material.metallic = 0.15
	material.roughness = 0.45
	material.emission_enabled = true
	material.emission = visual_color * 0.35
	visual.material_override = material


func _apply_available_visual() -> void:
	if not is_node_ready():
		return
	visual.visible = available
	collision.set_deferred("disabled", not available)
	set_deferred("monitoring", available)
	if available:
		position.y = base_height
