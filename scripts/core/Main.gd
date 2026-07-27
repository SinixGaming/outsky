extends Node2D
## Root scene. Registers the persistent player/room-container/fade-overlay
## with RoomManager and the SubViewport/container pair with
## ResolutionManager, then enters whatever room GameState says we're in —
## the exact same path for a freshly-created character and a loaded save.

@onready var subviewport_container: SubViewportContainer = $ViewportLayer/SubViewportContainer
@onready var subviewport: SubViewport = $ViewportLayer/SubViewportContainer/SubViewport
@onready var room_container: Node2D = $ViewportLayer/SubViewportContainer/SubViewport/RoomContainer
@onready var player: Player = $ViewportLayer/SubViewportContainer/SubViewport/Player
@onready var fade_overlay: FadeOverlay = $ViewportLayer/SubViewportContainer/SubViewport/FadeOverlay
@onready var hud_health_label: Label = $HUD/HealthLabel


func _ready() -> void:
	ResolutionManager.register(subviewport_container, subviewport)
	RoomManager.register(room_container, player, fade_overlay)
	player.health.health_changed.connect(_on_player_health_changed)
	player.health.died.connect(_on_player_died)
	EventBus.player_respawned.connect(_on_player_respawned)
	_on_player_health_changed(player.health.current_health, player.health.max_health)

	await RoomManager.change_room_by_id(GameState.data.current_room_id, GameState.data.current_spawn_id)


func _on_player_health_changed(current: int, max_hp: int) -> void:
	hud_health_label.text = "HP: %d / %d" % [current, max_hp]


func _on_player_died() -> void:
	GameState.handle_player_death()


## GameState owns the data/room-transition side of dying; this is the
## scene-tree side, resetting the live Player's resource pools once it's
## back in the rest-point room. (Soul/Vita pools aren't implemented yet —
## Health is the only pool restored for now.)
func _on_player_respawned(_room_id: StringName, _spawn_id: StringName) -> void:
	player.health.current_health = player.health.max_health
	player.health.health_changed.emit(player.health.current_health, player.health.max_health)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SaveManager.save_game()
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
