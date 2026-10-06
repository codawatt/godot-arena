class_name WeaponPickup
extends PickupBase


func _init() -> void:
	pickup_kind = Kind.WEAPON
	amount = 8
	respawn_delay = 20.0
	visual_color = Color(0.9, 0.35, 1.0)
