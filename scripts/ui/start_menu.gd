class_name StartMenu
extends CanvasLayer

signal host_requested(player_name: String, port: int)
signal join_requested(player_name: String, address: String, port: int)
signal dedicated_requested(port: int)
signal disconnect_requested

@onready var root: Control = $Root
@onready var player_name_edit: LineEdit = $Root/Center/Panel/Margin/VBox/PlayerName
@onready var address_edit: LineEdit = $Root/Center/Panel/Margin/VBox/Address
@onready var port_edit: LineEdit = $Root/Center/Panel/Margin/VBox/Port
@onready var host_button: Button = $Root/Center/Panel/Margin/VBox/PrimaryButtons/Host
@onready var join_button: Button = $Root/Center/Panel/Margin/VBox/PrimaryButtons/Join
@onready var dedicated_button: Button = $Root/Center/Panel/Margin/VBox/Dedicated
@onready var disconnect_button: Button = $Root/Center/Panel/Margin/VBox/Disconnect
@onready var status_label: Label = $Root/Center/Panel/Margin/VBox/Status


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	dedicated_button.pressed.connect(_on_dedicated_pressed)
	disconnect_button.pressed.connect(func() -> void: disconnect_requested.emit())
	dedicated_button.visible = not OS.has_feature("web")
	disconnect_button.disabled = true


func set_status(message: String) -> void:
	status_label.text = message


func show_menu(show: bool) -> void:
	root.visible = show


func is_menu_visible() -> bool:
	return root.visible


func set_connected(connected: bool) -> void:
	host_button.disabled = connected
	join_button.disabled = connected
	dedicated_button.disabled = connected
	disconnect_button.disabled = not connected


func get_requested_player_name() -> String:
	return player_name_edit.text.strip_edges()


func _on_host_pressed() -> void:
	host_requested.emit(get_requested_player_name(), _read_port())


func _on_join_pressed() -> void:
	join_requested.emit(get_requested_player_name(), address_edit.text, _read_port())


func _on_dedicated_pressed() -> void:
	dedicated_requested.emit(_read_port())


func _read_port() -> int:
	return clampi(int(port_edit.text), 1024, 65535)
