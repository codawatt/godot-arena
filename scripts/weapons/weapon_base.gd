class_name WeaponBase
extends Resource

enum WeaponId { RAILGUN, LIGHTNING_GUN, SHOTGUN, GAUNTLET }

@export var weapon_id: WeaponId = WeaponId.RAILGUN
@export var display_name: String = "Weapon"
@export_range(0.0, 500.0, 0.5) var damage: float = 10.0
@export_range(0.1, 500.0, 0.1) var range_meters: float = 50.0
@export_range(0.1, 30.0, 0.1) var fire_rate: float = 1.0
@export_range(0.0, 45.0, 0.1) var spread_degrees: float = 0.0
@export_range(1, 64, 1) var pellet_count: int = 1
@export_range(0, 20, 1) var ammo_cost: int = 1
@export_range(0, 500, 1) var maximum_ammo: int = 100
@export_range(0.0, 50.0, 0.1) var knockback: float = 0.0
@export_range(0.01, 2.0, 0.01) var effect_duration: float = 0.12
@export var effect_color: Color = Color.WHITE


func cooldown_msec() -> int:
	return int(1000.0 / maxf(fire_rate, 0.01))


func server_fire(_context: Dictionary) -> Dictionary:
	return {}
