extends Control
## In-world chargen popup, instantiated by Main.gd when the Cupboard is
## interacted with (see EventBus.stat_allocation_requested). Repurposes
## CharacterCreation.gd's exact stat-row structure/logic (name entry
## dropped — this happens after the character already exists) but applies
## the allocation to the LIVE GameState via apply_creation_growth() instead
## of new_game(), and pushes the result onto the live Player node since
## Player._ready() already ran with the zero-growth starting stats.

const STAT_IDS := ["health", "physical_damage", "magic_damage", "stamina", "speed"]
const STARTING_POINTS := 5

@onready var points_label: Label = $PanelContainer/VBoxContainer/PointsLabel
@onready var confirm_button: Button = $PanelContainer/VBoxContainer/ConfirmButton

var growth_points: Dictionary = {"health": 0, "physical_damage": 0, "magic_damage": 0, "stamina": 0, "speed": 0}
var points_remaining: int = STARTING_POINTS


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for stat_id in STAT_IDS:
		var row := get_node("PanelContainer/VBoxContainer/Stat_%s" % stat_id)
		row.get_node("PlusButton").pressed.connect(_on_stat_button_pressed.bind(stat_id, 1))
		row.get_node("MinusButton").pressed.connect(_on_stat_button_pressed.bind(stat_id, -1))
	confirm_button.pressed.connect(_on_confirm_pressed)
	_refresh_ui()


func _on_stat_button_pressed(stat_id: String, delta: int) -> void:
	if delta > 0 and points_remaining <= 0:
		return
	if delta < 0 and growth_points[stat_id] <= 0:
		return
	growth_points[stat_id] += delta
	points_remaining -= delta
	_refresh_ui()


func _refresh_ui() -> void:
	points_label.text = "Points remaining: %d" % points_remaining
	for stat_id in STAT_IDS:
		var row := get_node("PanelContainer/VBoxContainer/Stat_%s" % stat_id)
		row.get_node("ValueLabel").text = str(growth_points[stat_id])
	confirm_button.disabled = points_remaining != 0


func _on_confirm_pressed() -> void:
	GameState.apply_creation_growth(growth_points)
	_push_to_live_player()
	get_tree().paused = false
	queue_free()


func _push_to_live_player() -> void:
	var player: Player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	player.health.max_health = int(GameState.data.stats.get("health", player.health.max_health))
	player.health.current_health = player.health.max_health
	player.move_speed = float(GameState.data.stats.get("speed", player.move_speed))
	player.health.health_changed.emit(player.health.current_health, player.health.max_health)
