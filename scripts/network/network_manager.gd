class_name NetworkManager
extends Node

signal server_started(port: int)
signal connected_to_server
signal connection_failed(message: String)
signal disconnected_from_server
signal status_changed(message: String)

var socket_peer: WebSocketMultiplayerPeer
var server_mode: bool = false


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func start_server(port: int, bind_address: String = "0.0.0.0") -> Error:
	disconnect_network()
	socket_peer = WebSocketMultiplayerPeer.new()
	socket_peer.inbound_buffer_size = 262144
	socket_peer.outbound_buffer_size = 262144
	var error := socket_peer.create_server(port, bind_address)
	if error != OK:
		status_changed.emit("Could not listen on port %d: %s" % [port, error_string(error)])
		return error
	multiplayer.multiplayer_peer = socket_peer
	server_mode = true
	status_changed.emit("WebSocket server listening on port %d" % port)
	server_started.emit(port)
	return OK


func start_client(url: String) -> Error:
	disconnect_network()
	socket_peer = WebSocketMultiplayerPeer.new()
	socket_peer.inbound_buffer_size = 262144
	socket_peer.outbound_buffer_size = 262144
	var error := socket_peer.create_client(url)
	if error != OK:
		status_changed.emit("Could not start connection: %s" % error_string(error))
		return error
	multiplayer.multiplayer_peer = socket_peer
	server_mode = false
	status_changed.emit("Connecting to %s …" % url)
	return OK


func disconnect_network() -> void:
	if socket_peer != null:
		socket_peer.close()
	socket_peer = null
	server_mode = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func is_network_active() -> bool:
	return socket_peer != null


static func build_websocket_url(address: String, port: int) -> String:
	var cleaned := address.strip_edges()
	if cleaned.begins_with("ws://") or cleaned.begins_with("wss://"):
		# A full URL may contain a reverse-proxy path and therefore takes precedence.
		return cleaned
	if cleaned.is_empty():
		cleaned = "127.0.0.1"
	return "ws://%s:%d" % [cleaned, port]


func _on_connected_to_server() -> void:
	print("[Network] Connected to server as peer %d" % multiplayer.get_unique_id())
	status_changed.emit("Connected as peer %d" % multiplayer.get_unique_id())
	connected_to_server.emit()


func _on_connection_failed() -> void:
	print("[Network] Connection failed")
	status_changed.emit("Connection failed")
	connection_failed.emit("Connection failed")


func _on_server_disconnected() -> void:
	print("[Network] Server disconnected")
	status_changed.emit("Server disconnected")
	disconnected_from_server.emit()


func _on_peer_connected(peer_id: int) -> void:
	if server_mode:
		print("[Network] Peer %d connected" % peer_id)
		status_changed.emit("Peer %d connected; awaiting registration" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if server_mode:
		print("[Network] Peer %d disconnected" % peer_id)
		status_changed.emit("Peer %d disconnected" % peer_id)
