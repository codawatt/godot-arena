class_name PlayerController
extends Node

@export var ground_speed: float = 12.5
@export var ground_acceleration: float = 14.0
@export var ground_friction: float = 7.0
@export var air_speed: float = 12.5
@export var air_acceleration: float = 2.4
@export var jump_speed: float = 7.4
@export var gravity: float = 20.0


func simulate(body: CharacterBody3D, move_input: Vector2, yaw: float, jump_held: bool, delta: float) -> void:
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var wish_direction := right * move_input.x + forward * -move_input.y
	if wish_direction.length_squared() > 1.0:
		wish_direction = wish_direction.normalized()

	var on_ground := body.is_on_floor()
	if on_ground:
		if not jump_held:
			_apply_friction(body, delta)
		if wish_direction.length_squared() > 0.001:
			_accelerate(body, wish_direction.normalized(), ground_speed, ground_acceleration, delta)
		if jump_held:
			# Holding jump intentionally permits classic auto-bunny-hop timing.
			body.velocity.y = jump_speed
		elif body.velocity.y < 0.0:
			body.velocity.y = -0.5
	else:
		body.velocity.y -= gravity * delta
		if wish_direction.length_squared() > 0.001:
			_accelerate(body, wish_direction.normalized(), air_speed, air_acceleration, delta)

	body.move_and_slide()


func _apply_friction(body: CharacterBody3D, delta: float) -> void:
	var horizontal := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var speed := horizontal.length()
	if speed < 0.01:
		body.velocity.x = 0.0
		body.velocity.z = 0.0
		return
	var new_speed := maxf(0.0, speed - speed * ground_friction * delta)
	horizontal *= new_speed / speed
	body.velocity.x = horizontal.x
	body.velocity.z = horizontal.z


func _accelerate(
	body: CharacterBody3D,
	wish_direction: Vector3,
	wish_speed: float,
	acceleration: float,
	delta: float
) -> void:
	var current_speed := body.velocity.dot(wish_direction)
	var add_speed := wish_speed - current_speed
	if add_speed <= 0.0:
		return
	var acceleration_speed := minf(acceleration * wish_speed * delta, add_speed)
	body.velocity += wish_direction * acceleration_speed
