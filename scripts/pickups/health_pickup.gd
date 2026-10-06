class_name HealthPickup
extends PickupBase


func _init() -> void:
	pickup_kind = Kind.HEALTH
	amount = 25
	respawn_delay = 10.0
	visual_color = Color(0.2, 1.0, 0.35)
