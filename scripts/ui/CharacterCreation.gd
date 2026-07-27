extends Control

## Matches PlayerSaveData.GROWTH_KEYS — the only 5 of the 13 stats
## allocatable at creation.
const STAT_IDS := ["health", "physical_damage", "magic_damage", "stamina", "speed"]
const STARTING_POINTS := 5
const STARTING_ROOM_ID := &"outsky_hill_01"
const STARTING_SPAWN_ID := &"default"

@onready var name_edit: LineEdit = $VBoxContainer/NameEdit
@onready var points_label: Label = $VBoxContainer/PointsLabel
@onready var confirm_button: Button = $VBoxContainer/ConfirmButton

var growth_points: Dictionary = {"health": 0, "physical_damage": 0, "magic_damage": 0, "stamina": 0, "speed": 0}
var points_remaining: int = STARTING_POINTS


func _ready() -> void:
	for stat_id in STAT_IDS:
		var row := get_node("VBoxContainer/Stat_%s" % stat_id)
		row.get_node("PlusButton").pressed.connect(_on_stat_button_pressed.bind(stat_id, 1))
		row.get_node("MinusButton").pressed.connect(_on_stat_button_pressed.bind(stat_id, -1))
	confirm_button.pressed.connect(_on_confirm_pressed)
	name_edit.text_changed.connect(func(_t): _refresh_ui())
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
		var row := get_node("VBoxContainer/Stat_%s" % stat_id)
		row.get_node("ValueLabel").text = str(growth_points[stat_id])
	confirm_button.disabled = points_remaining != 0 or name_edit.text.strip_edges().is_empty()


func _on_confirm_pressed() -> void:
	GameState.new_game(name_edit.text.strip_edges(), growth_points, STARTING_ROOM_ID, STARTING_SPAWN_ID)
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
