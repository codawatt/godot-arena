class_name AmmoPickup
extends PickupBase


func _init() -> void:
	pickup_kind = Kind.AMMO
	amount = 10
	respawn_delay = 12.0
	visual_color = Color(1.0, 0.82, 0.18)
