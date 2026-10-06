class_name KillVolume
extends Area3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if multiplayer.is_server() and body.has_method("is_arena_player"):
		get_node("/root/Main/GameServer").handle_environmental_death(body)
