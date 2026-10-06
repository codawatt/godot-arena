class_name ArmorPickup
extends PickupBase


func _init() -> void:
	pickup_kind = Kind.ARMOR
	amount = 50
	respawn_delay = 18.0
	visual_color = Color(0.2, 0.65, 1.0)
