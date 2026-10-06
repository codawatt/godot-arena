class_name RailgunWeapon
extends WeaponBase


func server_fire(context: Dictionary) -> Dictionary:
	var shooter = context["shooter"]
	var origin: Vector3 = context["origin"]
	var direction: Vector3 = context["direction"]
	var end_point := origin + direction * range_meters
	var query := PhysicsRayQueryParameters3D.create(origin, end_point, 3, [shooter.get_rid()])
	query.collide_with_areas = false
	var hit: Dictionary = context["space_state"].intersect_ray(query)
	if not hit.is_empty():
		end_point = hit["position"]
		var collider = hit.get("collider")
		if collider != null and collider.has_method("is_arena_player"):
			context["damage_system"].apply_damage(
				collider, damage, shooter.peer_id, direction, knockback, context["attack_id"]
			)
	return {
		"kind": "rail",
		"origin": origin,
		"points": [end_point],
		"color": effect_color,
		"duration": effect_duration,
	}
