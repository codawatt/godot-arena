extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main = packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var network_error: Error = main.network.start_server(8937, "127.0.0.1")
	_check(network_error == OK, "test server starts")
	main.game_server.activate_server(false)
	main.game_client.begin_session(1, "Tester")
	main.game_server.register_local_player("Tester")
	main.game_server.match_manager.register_player(2, "Target")
	main.game_server._spawn_player_local(2, "Target", Vector3(3, 1, 0), 0.0)
	await physics_frame

	var shooter = main.game_server.players[1]
	var target = main.game_server.players[2]
	shooter.global_position = Vector3(-3, 1, 0)
	target.global_position = Vector3(3, 1, 0)
	await physics_frame

	_fire_at(main, shooter, target, 0, Vector3(3, 1.25, 0))
	_check(target.state.is_dead, "railgun applies an authoritative lethal hit")
	_check(int(shooter.state.ammo[0]) == 9, "railgun consumes server ammo")

	_reset_target(target, Vector3(8, 1, 0))
	await physics_frame
	_fire_at(main, shooter, target, 1, Vector3(8, 1.25, 0))
	_check(target.state.health == 93, "lightning gun applies one fixed damage tick")

	_reset_target(target, Vector3(2, 1, 0))
	await physics_frame
	_fire_at(main, shooter, target, 2, Vector3(2, 1.25, 0))
	_check(target.state.health < 100, "shotgun deterministic pellets hit and aggregate damage")

	_reset_target(target, Vector3(-1.25, 1, 0))
	await physics_frame
	_fire_at(main, shooter, target, 3, Vector3(-1.25, 1.25, 0))
	_check(target.state.health == 50, "gauntlet respects short range and cooldown path")

	_reset_target(target, Vector3(3, 1, 0))
	await physics_frame
	main.game_server.damage_system.apply_damage(target, 10, 1, Vector3.RIGHT, 0, "dedupe")
	main.game_server.damage_system.apply_damage(target, 10, 1, Vector3.RIGHT, 0, "dedupe")
	_check(target.state.health == 90, "duplicate attack event is applied only once")

	var health_pickup = main.get_node("ArenaMap/Pickups/HealthCentral")
	target.global_position = health_pickup.global_position
	target.state.health = 50
	var collected: bool = health_pickup.server_try_collect(target)
	_check(collected and target.state.health == 75 and not health_pickup.available, "health pickup validates and changes server state")

	main.game_server.reset_session()
	main.network.disconnect_network()
	if failures.is_empty():
		print("GAMEPLAY_SMOKE_OK: weapons, damage dedupe, and pickup authority passed")
		quit(0)
	else:
		for failure in failures:
			push_error("GAMEPLAY_SMOKE_FAILED: %s" % failure)
		quit(1)


func _fire_at(main, shooter, target, weapon_id: int, target_point: Vector3) -> void:
	shooter.state.selected_weapon = weapon_id
	shooter.next_fire_msec.erase(weapon_id)
	var direction: Vector3 = (target_point - shooter.get_aim_origin()).normalized()
	shooter.aim_yaw = atan2(-direction.x, -direction.z)
	shooter.aim_pitch = asin(clampf(direction.y, -1.0, 1.0))
	main.game_server.weapon_system.process_fire(shooter, true, Time.get_ticks_msec())


func _reset_target(target, target_position: Vector3) -> void:
	target.respawn_at(target_position)
	target.state.armor = 0
	target.state.health = 100


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
