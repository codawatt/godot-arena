class_name ShotgunWeapon
extends WeaponBase


func server_fire(context: Dictionary) -> Dictionary:
	var shooter = context["shooter"]
	var origin: Vector3 = context["origin"]
	var forward: Vector3 = context["direction"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(context["seed"])
	var right := forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	var up := right.cross(forward).normalized()
	var spread_tangent := tan(deg_to_rad(spread_degrees))
	var endpoints: Array[Vector3] = []
	var hit_counts: Dictionary = {}
	var hit_targets: Dictionary = {}

	for pellet_index in pellet_count:
		var disk_angle := rng.randf_range(0.0, TAU)
		var disk_radius := sqrt(rng.randf()) * spread_tangent
		var pellet_direction := (
			forward
			+ right * cos(disk_angle) * disk_radius
			+ up * sin(disk_angle) * disk_radius
		).normalized()
		var end_point := origin + pellet_direction * range_meters
		var query := PhysicsRayQueryParameters3D.create(origin, end_point, 3, [shooter.get_rid()])
		query.collide_with_areas = false
		var hit: Dictionary = context["space_state"].intersect_ray(query)
		if not hit.is_empty():
			end_point = hit["position"]
			var collider = hit.get("collider")
			if collider != null and collider.has_method("is_arena_player"):
				var target_id := int(collider.peer_id)
				hit_counts[target_id] = int(hit_counts.get(target_id, 0)) + 1
				hit_targets[target_id] = collider
		endpoints.append(end_point)

	# Pellets are counted separately, then combined into one idempotent damage event per target.
	for target_id in hit_counts:
		var event_id := "%s:%s" % [context["attack_id"], target_id]
		context["damage_system"].apply_damage(
			hit_targets[target_id],
			damage * int(hit_counts[target_id]),
			shooter.peer_id,
			forward,
			knockback * int(hit_counts[target_id]),
			event_id
		)

	return {
		"kind": "shotgun",
		"origin": origin,
		"points": endpoints,
		"color": effect_color,
		"duration": effect_duration,
		"seed": int(context["seed"]),
	}
