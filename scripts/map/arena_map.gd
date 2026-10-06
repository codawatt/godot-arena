@tool
class_name ArenaMap
extends Node3D

const GENERATED_ROOT_NAME := "__GeneratedArena"

@export_tool_button("Bake Arena Into Scene")
var bake_arena_button: Callable = bake_arena

@export_tool_button("Clear Baked Arena")
var clear_arena_button: Callable = clear_baked_arena

const HEALTH_SCENE := preload("res://scenes/pickups/health_pickup.tscn")
const ARMOR_SCENE := preload("res://scenes/pickups/armor_pickup.tscn")
const AMMO_SCENE := preload("res://scenes/pickups/ammo_pickup.tscn")
const WEAPON_SCENE := preload("res://scenes/pickups/weapon_pickup.tscn")
const KILL_VOLUME_SCRIPT := preload("res://scripts/map/kill_volume.gd")

const FLOOR_COLOR := Color(0.18, 0.22, 0.3)
const UPPER_COLOR := Color(0.22, 0.3, 0.42)
const WALL_COLOR := Color(0.11, 0.14, 0.2)
const COVER_COLOR := Color(0.35, 0.24, 0.16)
const EDGE_COLOR := Color(0.13, 0.52, 0.64)

func _ready() -> void:
	# Never build automatically just because the scene opened in the editor.
	if Engine.is_editor_hint():
		return

	# Build at runtime only when the arena has not already been baked.
	if not has_node(GENERATED_ROOT_NAME):
		_create_arena()
func bake_arena() -> void:
	if not Engine.is_editor_hint():
		return

	clear_baked_arena(false)

	var generated_root := _create_arena()
	var scene_root := get_tree().edited_scene_root

	_assign_editor_owner(generated_root, scene_root)
	EditorInterface.mark_scene_as_unsaved()


func clear_baked_arena(mark_unsaved: bool = true) -> void:
	var generated_root := get_node_or_null(GENERATED_ROOT_NAME)

	if generated_root == null:
		return

	remove_child(generated_root)
	generated_root.free()

	if mark_unsaved and Engine.is_editor_hint():
		EditorInterface.mark_scene_as_unsaved()


func _create_arena() -> Node3D:
	var generated_root := Node3D.new()
	generated_root.name = GENERATED_ROOT_NAME
	add_child(generated_root)

	_build_lighting(generated_root)
	_build_geometry(generated_root)
	_build_spawns(generated_root)
	_build_pickups(generated_root)
	_build_kill_volume(generated_root)

	return generated_root


func _assign_editor_owner(node: Node, scene_root: Node) -> void:
	if node.owner == null:
		node.owner = scene_root

	for child in node.get_children():
		# Preserve ownership belonging to instanced pickup scenes.
		# Manually generated children normally have no owner.
		if child.owner == null:
			_assign_editor_owner(child, scene_root)

func _build_lighting(parent: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.035, 0.065)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.42, 0.48, 0.62)
	environment.ambient_light_energy = 0.72
	world_environment.environment = environment
	parent.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "ArenaSun"
	sun.rotation_degrees = Vector3(-58.0, -32.0, 0.0)
	sun.light_color = Color(0.82, 0.9, 1.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	parent.add_child(sun)

	for light_data in [
		[Vector3(-16, 8, 0), Color(0.2, 0.65, 1.0)],
		[Vector3(16, 10, 0), Color(1.0, 0.45, 0.2)],
		[Vector3(0, 7, -18), Color(0.4, 1.0, 0.6)],
	]:
		var light := OmniLight3D.new()
		light.position = light_data[0]
		light.light_color = light_data[1]
		light.omni_range = 18.0
		light.light_energy = 2.2
		parent.add_child(light)


func _build_geometry(parent: Node3D) -> void:
	var geometry := Node3D.new()
	geometry.name = "Geometry"
	parent.add_child(geometry)

	_add_box(geometry, "CentralFloor", Vector3(0, -0.5, 0), Vector3(24, 1, 24), FLOOR_COLOR)
	_add_box(geometry, "WestDeck", Vector3(-17, 3.5, 0), Vector3(10, 1, 15), UPPER_COLOR)
	_add_box(geometry, "EastDeck", Vector3(17, 5.5, 0), Vector3(10, 1, 15), UPPER_COLOR)
	_add_box(geometry, "NorthDeck", Vector3(0, 2.5, -18), Vector3(14, 1, 10), UPPER_COLOR)
	_add_box(geometry, "SouthIsland", Vector3(0, 0.5, 18), Vector3(18, 1, 8), UPPER_COLOR)

	_add_stairs(geometry, "WestStair", Vector3(-12.4, 0, 5.0), Vector3.LEFT, 8, 3.6, 0.5, 0.75)
	_add_stairs(geometry, "EastStair", Vector3(12.4, 0, -5.0), Vector3.RIGHT, 12, 3.6, 0.5, 0.75)
	_add_stairs(geometry, "NorthStair", Vector3(4.5, 0, -12.4), Vector3.FORWARD, 6, 3.2, 0.5, 0.9)

	# A narrow safe bridge leaves a separate two-meter jump gap beside it.
	_add_box(geometry, "SouthBridge", Vector3(-7.0, 0.25, 13.0), Vector3(2.4, 0.5, 4.0), EDGE_COLOR)
	_add_box(geometry, "SouthBridgeStep", Vector3(-7.0, 0.75, 14.3), Vector3(2.4, 0.5, 1.4), EDGE_COLOR)

	# Outer corridors and containment walls.
	_add_box(geometry, "WestBoundary", Vector3(-24, 3.0, 0), Vector3(1, 6, 48), WALL_COLOR)
	_add_box(geometry, "EastBoundary", Vector3(24, 3.0, 0), Vector3(1, 6, 48), WALL_COLOR)
	_add_box(geometry, "NorthBoundary", Vector3(0, 3.0, -24), Vector3(48, 6, 1), WALL_COLOR)
	_add_box(geometry, "SouthBoundary", Vector3(0, 3.0, 24), Vector3(48, 6, 1), WALL_COLOR)
	_add_box(geometry, "NorthCorridorLeft", Vector3(-7.5, 4.25, -18), Vector3(1, 3.5, 10), WALL_COLOR)
	_add_box(geometry, "NorthCorridorRight", Vector3(7.5, 4.25, -18), Vector3(1, 3.5, 10), WALL_COLOR)
	_add_box(geometry, "WestRail", Vector3(-17, 5.0, -7.4), Vector3(10, 2, 0.35), EDGE_COLOR)
	_add_box(geometry, "EastRail", Vector3(17, 7.0, 7.4), Vector3(10, 2, 0.35), EDGE_COLOR)

	# Central cover supports close-range loops without blocking long sightlines entirely.
	_add_box(geometry, "CoverA", Vector3(-4.5, 1.4, -2.5), Vector3(2.2, 2.8, 2.2), COVER_COLOR)
	_add_box(geometry, "CoverB", Vector3(4.5, 1.0, 3.5), Vector3(3.0, 2.0, 1.7), COVER_COLOR)
	_add_box(geometry, "CoverC", Vector3(0, 1.1, 7.5), Vector3(5.0, 2.2, 1.0), COVER_COLOR)
	_add_box(geometry, "WestCover", Vector3(-17.5, 5.0, 3.5), Vector3(2.0, 2.0, 2.0), COVER_COLOR)
	_add_box(geometry, "EastCover", Vector3(17.5, 7.0, -3.5), Vector3(2.0, 2.0, 2.0), COVER_COLOR)

	# Bright trim makes level changes readable at arena movement speeds.
	_add_box(geometry, "CentralTrimNorth", Vector3(0, 0.08, -11.85), Vector3(24, 0.16, 0.3), EDGE_COLOR)
	_add_box(geometry, "CentralTrimSouth", Vector3(0, 0.08, 11.85), Vector3(24, 0.16, 0.3), EDGE_COLOR)


func _build_spawns(parent: Node3D) -> void:
	var spawns := Node3D.new()
	spawns.name = "SpawnPoints"
	parent.add_child(spawns)
	_add_spawn(spawns, "SpawnCentralNW", Vector3(-6, 1.0, -6), -0.75)
	_add_spawn(spawns, "SpawnCentralSE", Vector3(6, 1.0, 6), 2.35)
	_add_spawn(spawns, "SpawnWest", Vector3(-17, 5.0, -4), -1.57)
	_add_spawn(spawns, "SpawnEast", Vector3(17, 7.0, 4), 1.57)
	_add_spawn(spawns, "SpawnNorth", Vector3(0, 4.0, -18), 0.0)
	_add_spawn(spawns, "SpawnSouth", Vector3(0, 2.0, 18), 3.14)
	_add_spawn(spawns, "SpawnWestSouth", Vector3(-9, 1.0, 8), -2.2)
	_add_spawn(spawns, "SpawnEastNorth", Vector3(9, 1.0, -8), 0.9)


func _build_pickups(parent: Node3D) -> void:
	var pickups := Node3D.new()
	pickups.name = "Pickups"
	parent.add_child(pickups)

	_add_pickup(pickups, HEALTH_SCENE, "HealthCentral", Vector3(0, 1.15, 0))
	_add_pickup(pickups, HEALTH_SCENE, "HealthSouth", Vector3(5, 2.15, 18))
	_add_pickup(pickups, HEALTH_SCENE, "HealthNorth", Vector3(-4, 4.15, -19))
	_add_pickup(pickups, ARMOR_SCENE, "ArmorWest", Vector3(-17, 5.15, 5))
	_add_pickup(pickups, ARMOR_SCENE, "ArmorEast", Vector3(17, 7.15, -5))

	var rail_ammo = _add_pickup(pickups, AMMO_SCENE, "AmmoRail", Vector3(7, 1.15, -8))
	rail_ammo.configure_ammo(0, 5)
	var lightning_ammo = _add_pickup(pickups, AMMO_SCENE, "AmmoLightning", Vector3(-7, 1.15, 8))
	lightning_ammo.configure_ammo(1, 35)
	var shotgun_ammo = _add_pickup(pickups, AMMO_SCENE, "AmmoShotgun", Vector3(0, 4.15, -15))
	shotgun_ammo.configure_ammo(2, 10)

	var rail = _add_pickup(pickups, WEAPON_SCENE, "WeaponRailgun", Vector3(-17, 5.15, 0))
	rail.configure_weapon(0, 5, Color(0.2, 0.9, 1.0))
	var lightning = _add_pickup(pickups, WEAPON_SCENE, "WeaponLightning", Vector3(17, 7.15, 0))
	lightning.configure_weapon(1, 30, Color(0.45, 0.65, 1.0))
	var shotgun = _add_pickup(pickups, WEAPON_SCENE, "WeaponShotgun", Vector3(0, 4.15, -18))
	shotgun.configure_weapon(2, 8, Color(1.0, 0.68, 0.25))
	var gauntlet = _add_pickup(pickups, WEAPON_SCENE, "WeaponGauntlet", Vector3(-5, 2.15, 18))
	gauntlet.configure_weapon(3, 0, Color(1.0, 0.25, 0.2))


func _build_kill_volume(parent: Node3D) -> void:
	var hazard_visual := MeshInstance3D.new()
	hazard_visual.name = "HazardVisual"
	hazard_visual.position = Vector3(0, -9.5, 0)
	var hazard_mesh := BoxMesh.new()
	hazard_mesh.size = Vector3(70, 0.2, 70)
	hazard_visual.mesh = hazard_mesh
	hazard_visual.material_override = _make_material(Color(1.0, 0.04, 0.02, 0.32), true)
	parent.add_child(hazard_visual)

	var kill_volume := Area3D.new()
	kill_volume.name = "KillVolume"
	kill_volume.position = Vector3(0, -13.0, 0)
	kill_volume.collision_layer = 0
	kill_volume.collision_mask = 2
	kill_volume.set_script(KILL_VOLUME_SCRIPT)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80, 5, 80)
	shape_node.shape = shape
	kill_volume.add_child(shape_node)
	parent.add_child(kill_volume)


func _add_box(
	parent: Node3D,
	box_name: String,
	box_position: Vector3,
	size: Vector3,
	color: Color
) -> void:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = box_position
	body.collision_layer = 1
	body.collision_mask = 2
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(color)
	body.add_child(mesh_instance)
	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	collision_shape.shape = box_shape
	body.add_child(collision_shape)
	parent.add_child(body)


func _add_stairs(
	parent: Node3D,
	prefix: String,
	start: Vector3,
	direction: Vector3,
	steps: int,
	width: float,
	step_height: float,
	step_depth: float
) -> void:
	for index in steps:
		var height := step_height * float(index + 1)
		var center := start + direction * step_depth * float(index)
		center.y += height * 0.5

		var size := Vector3(width, height, step_depth)

		if absf(direction.x) > 0.5:
			size = Vector3(step_depth, height, width)

		_add_box(
			parent,
			"%s_%02d" % [prefix, index],
			center,
			size,
			UPPER_COLOR
		)

func _add_spawn(parent: Node3D, spawn_name: String, spawn_position: Vector3, yaw: float) -> void:
	var marker := Marker3D.new()
	marker.name = spawn_name
	marker.position = spawn_position
	marker.rotation.y = yaw
	marker.add_to_group("spawn_points")
	parent.add_child(marker)


func _add_pickup(parent: Node3D, scene: PackedScene, pickup_name: String, pickup_position: Vector3):
	var pickup = scene.instantiate()
	pickup.name = pickup_name
	pickup.position = pickup_position
	parent.add_child(pickup)
	return pickup


func _make_material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emissive:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b) * 0.45
	return material
