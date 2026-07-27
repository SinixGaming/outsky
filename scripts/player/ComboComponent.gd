class_name ComboComponent
extends Node
## Timer-driven combo state machine, child of Player. Reads Player's shared
## input buffer (see Player.consume_buffered_action) rather than polling
## presses directly, so a fast attack press during recovery still chains
## instead of getting dropped or forcing a reset. Data-driven via a
## ComboChain resource — no attack-specific logic is hardcoded here.

signal combo_step_started(step_index: int, step: ComboStep)
signal combo_reset()

@export var chain: ComboChain
## How long, from a fully idle state, a fresh attack press is honored to
## start the chain (matches the general input-buffer feel, not tied to any
## one step's timing).
@export var idle_start_window_ms: int = 150

var _player: Player = null
var _timer: Timer
var _step_index: int = -1
var _current_step: ComboStep = null
var _phase: String = "idle"  # idle, startup, active, recovery


func _ready() -> void:
	_player = get_parent() as Player
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)


func _process(_delta: float) -> void:
	if chain == null or chain.steps.is_empty() or _player == null:
		return

	if _phase == "idle":
		if _player.consume_buffered_action(&"attack", idle_start_window_ms):
			_start_step(0)
	elif _phase == "recovery":
		var window_ms := int(_current_step.input_window_after * 1000.0)
		if _player.consume_buffered_action(&"attack", window_ms):
			var next_index := _step_index + 1
			if next_index >= chain.steps.size():
				next_index = 0
			_start_step(next_index)


func _start_step(index: int) -> void:
	_step_index = index
	_current_step = chain.steps[index]
	_phase = "startup"
	combo_step_started.emit(index, _current_step)
	_timer.start(max(0.01, _current_step.startup_time))


func _on_timer_timeout() -> void:
	match _phase:
		"startup":
			_phase = "active"
			_apply_hit()
			_timer.start(max(0.01, _current_step.active_time))
		"active":
			_phase = "recovery"
			_timer.start(max(0.01, _current_step.recovery_time))
		"recovery":
			_reset()


func _reset() -> void:
	_step_index = -1
	_current_step = null
	_phase = "idle"
	combo_reset.emit()


func _apply_hit() -> void:
	if _current_step == null:
		return
	var raw_damage := DamageCalculator.compute_raw_damage(GameState.data.stats, _current_step.damage_type, _current_step.damage_multiplier)
	for body in _player.attack_area.get_overlapping_bodies():
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			body.take_damage(raw_damage)
			var vamp_heal := DamageCalculator.compute_vamp_heal(raw_damage, GameState.data.stats)
			if vamp_heal > 0:
				_player.health.heal(vamp_heal)
