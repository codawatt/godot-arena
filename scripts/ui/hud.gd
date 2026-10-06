class_name ArenaHUD
extends CanvasLayer

@onready var root: Control = $Root
@onready var health_label: Label = $Root/Stats/Health
@onready var armor_label: Label = $Root/Stats/Armor
@onready var weapon_label: Label = $Root/Stats/Weapon
@onready var ammo_label: Label = $Root/Stats/Ammo
@onready var connection_label: Label = $Root/ConnectionStatus
@onready var respawn_label: Label = $Root/Respawn
@onready var kill_feed_label: Label = $Root/KillFeed
@onready var scoreboard_panel: PanelContainer = $Root/Scoreboard
@onready var scoreboard_label: Label = $Root/Scoreboard/Margin/Rows

var kill_messages: Array[Dictionary] = []
var has_session: bool = false


func _ready() -> void:
	root.visible = false
	respawn_label.visible = false
	scoreboard_panel.visible = false


func _process(_delta: float) -> void:
	if not has_session:
		return
	scoreboard_panel.visible = Input.is_action_pressed("scoreboard")
	var now := Time.get_ticks_msec()
	var changed := false
	while not kill_messages.is_empty() and int(kill_messages[0]["expires"]) <= now:
		kill_messages.pop_front()
		changed = true
	if changed:
		_refresh_kill_feed()


func show_session(show: bool) -> void:
	has_session = show
	root.visible = show
	if not show:
		scoreboard_panel.visible = false


func set_connection_status(message: String) -> void:
	connection_label.text = message


func set_player_state(state: PlayerState, weapon_name: String, respawn_remaining: float) -> void:
	show_session(true)
	health_label.text = "HEALTH  %03d" % state.health
	armor_label.text = "ARMOR   %03d" % state.armor
	weapon_label.text = weapon_name.to_upper()
	if state.selected_weapon == int(WeaponBase.WeaponId.GAUNTLET):
		ammo_label.text = "AMMO    ∞"
	else:
		ammo_label.text = "AMMO    %03d" % int(state.ammo.get(state.selected_weapon, 0))
	respawn_label.visible = state.is_dead
	respawn_label.text = "RESPAWNING IN %.1f" % respawn_remaining if state.is_dead else ""


func set_scoreboard(scoreboard: Array) -> void:
	var lines: PackedStringArray = ["SCOREBOARD", ""]
	for entry_value in scoreboard:
		var entry := Dictionary(entry_value)
		lines.append("%-18s  %3d / %3d" % [str(entry.get("name", "Player")), int(entry.get("kills", 0)), int(entry.get("deaths", 0))])
	if scoreboard.is_empty():
		lines.append("No players")
	scoreboard_label.text = "\n".join(lines)


func add_kill_message(message: String) -> void:
	kill_messages.append({"text": message, "expires": Time.get_ticks_msec() + 6000})
	while kill_messages.size() > 5:
		kill_messages.pop_front()
	_refresh_kill_feed()


func clear_session() -> void:
	has_session = false
	root.visible = false
	respawn_label.visible = false
	kill_messages.clear()
	kill_feed_label.text = ""


func _refresh_kill_feed() -> void:
	var lines: PackedStringArray = []
	for item in kill_messages:
		lines.append(str(item["text"]))
	kill_feed_label.text = "\n".join(lines)
