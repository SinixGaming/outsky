class_name Player
extends CharacterBody2D
## Side-view controller: gravity, jump (with coyote time + jump buffering),
## and a climb state for surfaces in the "climbable" group. Discrete-press
## actions (jump, attack, hotbar) go through a small timestamp-based input
## buffer (_buffer_action/consume_buffered_action) rather than being acted
## on only in the exact frame they arrive — this is what makes jump-buffering
## possible and is the same mechanism Stage 4's combo system consumes, so
## fast/near-simultaneous presses never silently get dropped.

const PlaceholderTextureScript = preload("res://scripts/core/PlaceholderTexture.gd")

enum MoveState { GROUND, AIR, CLIMB }

@export var move_speed: float = 140.0
@export var jump_velocity: float = -400.0
@export var gravity_scale: float = 1.0
@export var coyote_time: float = 0.1
@export var jump_buffer_window_ms: int = 100

@onready var sprite: Sprite2D = $Sprite2D
@onready var health: Health = $Health
@onready var attack_area: Area2D = $AttackArea
@onready var climb_detector: Area2D = $ClimbDetector
@onready var camera: PlayerCamera = $Camera2D
@onready var combo: ComboComponent = $ComboComponent

var move_state: MoveState = MoveState.AIR
var active_hotbar_slot: int = 1

var _coyote_timer: float = 0.0
var _climbable_overlap_count: int = 0
var _input_buffer: Dictionary = {}  # StringName -> Time.get_ticks_msec() at press


func _ready() -> void:
	add_to_group("player")
	if sprite.texture == null:
		sprite.texture = PlaceholderTextureScript.make(Vector2i(20, 32), Color(0.2, 0.5, 0.9))
	move_speed = float(GameState.data.stats.get("speed", move_speed))
	health.max_health = int(GameState.data.stats.get("health", health.max_health))
	health.current_health = health.max_health
	climb_detector.area_entered.connect(_on_climb_area_entered)
	climb_detector.area_exited.connect(_on_climb_area_exited)


func _physics_process(delta: float) -> void:
	_update_coyote_timer(delta)
	_update_move_state()

	if move_state == MoveState.CLIMB:
		var climb_axis := Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
		velocity.y = climb_axis * move_speed
	else:
		velocity.y += _gravity() * delta

	_try_consume_jump()

	var move_axis := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	velocity.x = move_axis * move_speed

	move_and_slide()
	_face_mouse()


func _gravity() -> float:
	return float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)) * gravity_scale


func _update_coyote_timer(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = max(0.0, _coyote_timer - delta)


func _update_move_state() -> void:
	var touching_climbable := _climbable_overlap_count > 0
	var climb_input := absf(Input.get_action_strength("move_up")) > 0.0 or absf(Input.get_action_strength("move_down")) > 0.0

	if touching_climbable and climb_input:
		move_state = MoveState.CLIMB
	elif move_state == MoveState.CLIMB and not touching_climbable:
		move_state = MoveState.AIR
	elif move_state != MoveState.CLIMB:
		move_state = MoveState.GROUND if is_on_floor() else MoveState.AIR


func _try_consume_jump() -> void:
	if move_state == MoveState.CLIMB:
		if consume_buffered_action(&"jump", jump_buffer_window_ms):
			velocity.y = jump_velocity
			move_state = MoveState.AIR
		return
	if _coyote_timer > 0.0 and consume_buffered_action(&"jump", jump_buffer_window_ms):
		velocity.y = jump_velocity
		_coyote_timer = 0.0


func _face_mouse() -> void:
	sprite.flip_h = get_global_mouse_position().x < global_position.x


## --- Shared input buffer ---
## Records the timestamp of a discrete press; consume_buffered_action lets
## any system (jump handling here, Stage 4's combo component later) check
## "was this pressed within the last N ms" without racing _physics_process.

func _buffer_action(action: StringName) -> void:
	_input_buffer[action] = Time.get_ticks_msec()


func consume_buffered_action(action: StringName, window_ms: int) -> bool:
	if not _input_buffer.has(action):
		return false
	var pressed_at: int = _input_buffer[action]
	if Time.get_ticks_msec() - pressed_at <= window_ms:
		_input_buffer.erase(action)
		return true
	_input_buffer.erase(action)
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		_buffer_action(&"jump")
		return
	if event.is_action_pressed("attack"):
		_buffer_action(&"attack")
		return
	for i in range(1, 10):
		if event.is_action_pressed("hotbar_%d" % i):
			active_hotbar_slot = i
			return


func _on_climb_area_entered(area: Area2D) -> void:
	if area.is_in_group("climbable"):
		_climbable_overlap_count += 1


func _on_climb_area_exited(area: Area2D) -> void:
	if area.is_in_group("climbable"):
		_climbable_overlap_count = max(0, _climbable_overlap_count - 1)
