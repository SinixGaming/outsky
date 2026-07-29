extends Node2D
## Root scene. Registers the persistent player/room-container/fade-overlay
## with RoomManager and the SubViewport/container pair with
## ResolutionManager, then enters whatever room GameState says we're in —
## the exact same path for a freshly-created character and a loaded save.
## Also owns the HUD (native-resolution, outside the world SubViewport) and
## the Cupboard-triggered stat-allocation popup.

const StatAllocationPopupScene := preload("res://scenes/ui/StatAllocationPopup.tscn")

@onready var subviewport_container: SubViewportContainer = $ViewportLayer/SubViewportContainer
@onready var subviewport: SubViewport = $ViewportLayer/SubViewportContainer/SubViewport
@onready var room_container: Node2D = $ViewportLayer/SubViewportContainer/SubViewport/RoomContainer
@onready var player: Player = $ViewportLayer/SubViewportContainer/SubViewport/Player
@onready var fade_overlay: FadeOverlay = $ViewportLayer/SubViewportContainer/SubViewport/FadeOverlay
@onready var popup_layer: CanvasLayer = $PopupLayer

@onready var health_bar: ProgressBar = $HUD/Root/TopLeft/HealthRow/HealthBar
@onready var vita_bar: ProgressBar = $HUD/Root/TopLeft/VitaRow/VitaBar
@onready var soul_bar: ProgressBar = $HUD/Root/TopLeft/SoulRow/SoulBar
@onready var hotbar_slots: Array = []

## Health fill recolors as it depletes (green -> yellow -> red) so low HP
## reads at a glance instead of only via the numeric bar length.
const HEALTH_COLOR_HIGH := Color(0.28, 0.7, 0.32, 1)
const HEALTH_COLOR_MID := Color(0.85, 0.7, 0.15, 1)
const HEALTH_COLOR_LOW := Color(0.78, 0.16, 0.16, 1)
const HEALTH_MID_THRESHOLD := 0.6
const HEALTH_LOW_THRESHOLD := 0.3
const BAR_TWEEN_DURATION := 0.35

## No per-frame "health bar at 90%/80%/70%..." art exists or is needed —
## the bars are plain data-driven ProgressBars; depletion is animated by
## tweening the .value property. Swapping in real bar art later only means
## switching these to TextureProgressBar (texture_under/over/progress) and
## keeping this same tween — the animation approach doesn't change.
var _health_tween: Tween
var _vita_tween: Tween
var _soul_tween: Tween


func _ready() -> void:
	ResolutionManager.register(subviewport_container, subviewport)
	RoomManager.register(room_container, player, fade_overlay)

	player.health.health_changed.connect(_on_health_changed)
	player.vita.pool_changed.connect(_on_vita_changed)
	player.soul.pool_changed.connect(_on_soul_changed)
	player.health.died.connect(_on_player_died)
	EventBus.player_respawned.connect(_on_player_respawned)
	EventBus.stat_allocation_requested.connect(_on_stat_allocation_requested)
	EventBus.hotbar_slot_changed.connect(_on_hotbar_slot_changed)

	for child in $HUD/Root/BottomLeft/HotbarRow.get_children():
		hotbar_slots.append(child)

	_on_health_changed(player.health.current_health, player.health.max_health)
	_on_vita_changed(player.vita.current_vita, player.vita.max_vita)
	_on_soul_changed(player.soul.current_soul, player.soul.max_soul)
	_on_hotbar_slot_changed(player.active_hotbar_slot)

	await RoomManager.change_room_by_id(GameState.data.current_room_id, GameState.data.current_spawn_id)


func _on_health_changed(current: int, max_value: int) -> void:
	health_bar.max_value = max_value
	_health_tween = _animate_bar_value(_health_tween, health_bar, current)

	var fraction := float(current) / float(max(1, max_value))
	var fill := health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		if fraction <= HEALTH_LOW_THRESHOLD:
			fill.bg_color = HEALTH_COLOR_LOW
		elif fraction <= HEALTH_MID_THRESHOLD:
			fill.bg_color = HEALTH_COLOR_MID
		else:
			fill.bg_color = HEALTH_COLOR_HIGH


func _on_vita_changed(current: int, max_value: int) -> void:
	vita_bar.max_value = max_value
	_vita_tween = _animate_bar_value(_vita_tween, vita_bar, current)


func _on_soul_changed(current: int, max_value: int) -> void:
	soul_bar.max_value = max_value
	_soul_tween = _animate_bar_value(_soul_tween, soul_bar, current)


## Kills any in-flight tween for this bar (so rapid repeated damage doesn't
## queue up a stack of stale tweens fighting each other) and eases the
## displayed value toward the new target instead of snapping instantly.
func _animate_bar_value(existing: Tween, bar: ProgressBar, target: int) -> Tween:
	if existing:
		existing.kill()
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(bar, "value", float(target), BAR_TWEEN_DURATION)
	return tween


func _on_hotbar_slot_changed(slot: int) -> void:
	for i in range(hotbar_slots.size()):
		hotbar_slots[i].get_node("Highlight").visible = (i + 1 == slot)


func _on_player_died() -> void:
	GameState.handle_player_death()


## GameState owns the data/room-transition side of dying; this is the
## scene-tree side, resetting the live Player's resource pools once it's
## back in the rest-point room.
func _on_player_respawned(_room_id: StringName, _spawn_id: StringName) -> void:
	player.health.current_health = player.health.max_health
	player.health.health_changed.emit(player.health.current_health, player.health.max_health)
	player.vita.current_vita = player.vita.max_vita
	player.vita.pool_changed.emit(player.vita.current_vita, player.vita.max_vita)
	player.soul.current_soul = player.soul.max_soul
	player.soul.pool_changed.emit(player.soul.current_soul, player.soul.max_soul)


## Cupboard interaction (see scripts/entities/Cupboard.gd) — instantiate
## the popup and pause the tree so the player can't move/attack/dash while
## it's open. The popup's own process_mode is ALWAYS so its buttons still
## work; it unpauses and frees itself on confirm.
func _on_stat_allocation_requested() -> void:
	var popup: Control = StatAllocationPopupScene.instantiate()
	popup_layer.add_child(popup)
	get_tree().paused = true


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var room_disables_autosave := RoomManager.current_room != null and RoomManager.current_room.disable_autosave
		if not room_disables_autosave:
			SaveManager.save_game()
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
