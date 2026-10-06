class_name WeaponEffects
extends Node3D


func show_weapon_effect(effect: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var origin: Vector3 = effect.get("origin", Vector3.ZERO)
	var color: Color = effect.get("color", Color.WHITE)
	var duration := float(effect.get("duration", 0.1))
	var kind := str(effect.get("kind", "rail"))
	var radius := 0.035
	match kind:
		"rail":
			radius = 0.065
		"lightning":
			radius = 0.045
		"shotgun":
			radius = 0.012
		"gauntlet":
			radius = 0.085

	_make_flash(origin, color, duration * 0.45)
	var endpoints: Array = effect.get("points", [])
	for endpoint_value in endpoints:
		var endpoint: Vector3 = endpoint_value
		_make_beam(origin, endpoint, color, radius, duration)
		_make_impact(endpoint, color, radius * 3.2, duration * 1.25)


func _make_beam(
	start: Vector3,
	finish: Vector3,
	color: Color,
	radius: float,
	duration: float
) -> void:
	var delta := finish - start
	var length := delta.length()
	if length < 0.01:
		return
	var beam := MeshInstance3D.new()
	beam.name = "WeaponBeam"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = length
	cylinder.radial_segments = 8
	beam.mesh = cylinder
	beam.material_override = _effect_material(color)
	add_child(beam)
	beam.global_position = (start + finish) * 0.5
	beam.global_basis = _basis_with_y(delta / length)
	_expire(beam, duration)


func _make_flash(position: Vector3, color: Color, duration: float) -> void:
	_make_sphere("MuzzleFlash", position, color, 0.13, duration)


func _make_impact(position: Vector3, color: Color, radius: float, duration: float) -> void:
	_make_sphere("Impact", position, color, clampf(radius, 0.04, 0.22), duration)


func _make_sphere(
	node_name: String,
	position: Vector3,
	color: Color,
	radius: float,
	duration: float
) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	instance.mesh = sphere
	instance.material_override = _effect_material(color)
	add_child(instance)
	instance.global_position = position
	_expire(instance, duration)


func _effect_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	return material


func _basis_with_y(y_axis: Vector3) -> Basis:
	var x_axis := Vector3.UP.cross(y_axis)
	if x_axis.length_squared() < 0.001:
		x_axis = Vector3.RIGHT
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis).orthonormalized()


func _expire(node: Node, duration: float) -> void:
	get_tree().create_timer(maxf(0.01, duration)).timeout.connect(node.queue_free)
