class_name Main
extends Node

@onready var network: NetworkManager = $NetworkManager
@onready var game_server: GameServer = $GameServer
@onready var game_client: GameClient = $GameClient
@onready var hud: ArenaHUD = $HUD
@onready var menu: StartMenu = $StartMenu

var pending_player_name: String = "Ranger"
var running_dedicated: bool = false


func _ready() -> void:
	menu.host_requested.connect(_host_game)
	menu.join_requested.connect(_join_game)
	menu.dedicated_requested.connect(_start_dedicated)
	menu.disconnect_requested.connect(_disconnect)
	game_client.menu_toggle_requested.connect(_toggle_menu)
	network.connected_to_server.connect(_on_connected_to_server)
	network.connection_failed.connect(_on_connection_failed)
	network.disconnected_from_server.connect(_on_server_disconnected)
	network.status_changed.connect(_on_network_status)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	call_deferred("_apply_command_line")


func _host_game(player_name: String, port: int) -> void:
	pending_player_name = _fallback_name(player_name)
	var error := network.start_server(port)
	if error != OK:
		return
	running_dedicated = false
	game_server.activate_server(false)
	game_client.begin_session(1, pending_player_name)
	game_server.register_local_player(pending_player_name)
	menu.set_connected(true)
	menu.show_menu(false)
	hud.show_session(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _join_game(player_name: String, address: String, port: int) -> void:
	pending_player_name = _fallback_name(player_name)
	var url := NetworkManager.build_websocket_url(address, port)
	var error := network.start_client(url)
	if error != OK:
		return
	running_dedicated = false
	menu.set_connected(true)
	menu.set_status("Connecting to %s …" % url)


func _start_dedicated(port: int) -> void:
	var error := network.start_server(port)
	if error != OK:
		return
	running_dedicated = true
	game_server.activate_server(true)
	menu.set_connected(true)
	menu.set_status("Dedicated server running on WebSocket port %d." % port)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_connected_to_server() -> void:
	var peer_id := multiplayer.get_unique_id()
	game_client.begin_session(peer_id, pending_player_name)
	game_client.register_with_server()
	menu.show_menu(false)
	hud.show_session(true)
	# Browsers may require one additional click on the canvas before pointer lock is granted.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_connection_failed(message: String) -> void:
	_cleanup_to_menu(message)


func _on_server_disconnected() -> void:
	_cleanup_to_menu("Disconnected from server.")


func _on_network_status(message: String) -> void:
	menu.set_status(message)
	hud.set_connection_status(message)


func _disconnect() -> void:
	game_server.reset_session()
	game_client.end_session()
	network.disconnect_network()
	running_dedicated = false
	menu.set_connected(false)
	menu.show_menu(true)
	menu.set_status("Disconnected. Ready.")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _cleanup_to_menu(message: String) -> void:
	game_server.reset_session()
	game_client.end_session()
	network.disconnect_network()
	running_dedicated = false
	menu.set_connected(false)
	menu.show_menu(true)
	menu.set_status(message)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _toggle_menu() -> void:
	if not game_client.session_active:
		return
	var should_show := not menu.is_menu_visible()
	menu.show_menu(should_show)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if should_show else Input.MOUSE_MODE_CAPTURED


func _apply_command_line() -> void:
	var args := OS.get_cmdline_user_args()
	var port := 8910
	var requested_name := "Ranger"
	var join_url := ""
	var dedicated_requested := false
	var host_requested := false
	for argument in args:
		if argument == "--dedicated" or argument == "--server":
			dedicated_requested = true
		elif argument == "--host":
			host_requested = true
		elif argument.begins_with("--port="):
			port = clampi(int(argument.trim_prefix("--port=")), 1024, 65535)
		elif argument.begins_with("--name="):
			requested_name = argument.trim_prefix("--name=")
		elif argument.begins_with("--join="):
			join_url = argument.trim_prefix("--join=")
	if dedicated_requested:
		_start_dedicated(port)
	elif host_requested:
		_host_game(requested_name, port)
	elif not join_url.is_empty():
		_join_game(requested_name, join_url, port)


func _fallback_name(value: String) -> String:
	var cleaned := value.strip_edges()
	return cleaned if not cleaned.is_empty() else "Ranger"
