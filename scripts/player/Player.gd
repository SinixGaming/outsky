class_name Player
extends CharacterBody2D
## Side-view controller: gravity, jump (with coyote time + jump buffering),
## a climb state for surfaces in the "climbable" group, a short dash, and
## drop-through for surfaces in the "one_way_platform" group. Discrete-press
## actions (jump, dash, attack, hotbar) go through a small timestamp-based
## input buffer (_buffer_action/consume_buffered_action) rather than being
## acted on only in the exact frame they arrive — this is what makes
## jump/dash-buffering possible and is the same mechanism the combo system
## consumes, so fast/near-simultaneous presses never silently get dropped.

const ONE_WAY_GROUP := "one_way_platform"

enum MoveState { GROUND, AIR, CLIMB, DASH }

@export var move_speed: float = 140.0
## Airborne horizontal speed is move_speed * this — slightly higher than
## grounded so left/right control feels a bit easier to nudge mid-air.
@export var air_move_speed_multiplier: float = 1.2
## Ground speed at or above which the sprite switches from the `walk` cycle to
## the `run` cycle. Both are full 8-frame cycles with proper left/right leg
## alternation. Default sits above the base move_speed so normal movement
## walks and investing in the Speed stat eventually breaks into a run — drop
## this below move_speed (e.g. 90.0) if the character should always run.
@export var run_animation_speed_threshold: float = 150.0
## Longest the airborne punch pose may hold CONTINUOUSLY before the jump/fall
## pose is allowed through again. Stops sustained spam freezing the character
## mid-air; every individual strike still shows.
@export var air_attack_pose_hold: float = 0.22
## How far the cursor must sit from the character (world px) before it can
## turn the sprite. Stops the flicker when the cursor hovers near the body.
@export var cursor_facing_dead_zone: float = 24.0
## How long the cursor must stay on the far side before the sprite turns.
## Small enough to stay responsive, large enough to absorb jitter.
@export var cursor_facing_turn_delay: float = 0.12
@export var jump_velocity: float = -400.0
@export var gravity_scale: float = 1.0
@export var coyote_time: float = 0.1
@export var jump_buffer_window_ms: int = 100

@export var dash_speed: float = 280.0
@export var dash_duration: float = 0.26
## Deliberately long — this is a "use it and wait" ability, not spammable.
## Meant to shrink later as the player invests in Stamina.
@export var dash_cooldown: float = 7.0
@export var dash_buffer_window_ms: int = 100

@export var drop_through_duration: float = 0.25

@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var health: Health = $Health
@onready var vita: VitaPool = $VitaPool
@onready var soul: SoulPool = $SoulPool
@onready var attack_area: Area2D = $AttackArea
@onready var climb_detector: Area2D = $ClimbDetector
@onready var camera: PlayerCamera = $Camera2D
@onready var combo: ComboComponent = $ComboComponent

var move_state: MoveState = MoveState.AIR
var active_hotbar_slot: int = 1

var _coyote_timer: float = 0.0
var _climbable_overlap_count: int = 0
var _input_buffer: Dictionary = {}  # StringName -> Time.get_ticks_msec() at press

var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: float = 1.0
## Beyond the cooldown, dashing mid-air is capped at once per airtime —
## resets the moment the player touches ground again. Without this, the
## cooldown alone still lets a single held-down mash chain enough dashes
## in the air to effectively float/re-jump repeatedly.
var _dash_used_since_grounded: bool = false

## True while a punch animation is actively playing (see
## _on_combo_step_started/_on_combo_reset) — _update_animation() defers to
## it instead of overwriting the punch pose with idle/walk/etc each frame.
var _attacking: bool = false

## Last-played frame index of each locomotion cycle, so an attack that
## interrupts walk/run can resume the cycle instead of snapping it back to
## frame 0 (which read as gliding while spam-attacking).
var _locomotion_frame: Dictionary = {}

## Time the cursor has spent on the opposite side, used to damp turning.
var _facing_hold_timer: float = 0.0

## How long the airborne attack pose has been held without a break.
var _air_attack_hold: float = 0.0

## 0-based index of the punch_walk frame where the arm is fully extended
## (frame 4 of 8). Attacks start here so the strike is visible immediately.
const PUNCH_WALK_STRIKE_FRAME := 3


func _ready() -> void:
	add_to_group("player")
	move_speed = float(GameState.data.stats.get("speed", move_speed))
	health.max_health = int(GameState.data.stats.get("health", health.max_health))
	health.current_health = health.max_health
	vita.max_vita = int(GameState.data.stats.get("vita", vita.max_vita))
	vita.current_vita = vita.max_vita
	soul.max_soul = int(GameState.data.stats.get("soul", soul.max_soul))
	soul.current_soul = soul.max_soul
	climb_detector.area_entered.connect(_on_climb_area_entered)
	climb_detector.area_exited.connect(_on_climb_area_exited)
	combo.combo_step_started.connect(_on_combo_step_started)
	combo.combo_recovery_started.connect(_on_combo_recovery_started)
	combo.combo_reset.connect(_on_combo_reset)
	sprite.play(&"idle")


func _physics_process(delta: float) -> void:
	_update_coyote_timer(delta)
	_dash_cooldown_timer = max(0.0, _dash_cooldown_timer - delta)
	_update_move_state(delta)
	_try_consume_dash()
	_try_consume_jump()

	match move_state:
		MoveState.DASH:
			velocity.y = 0.0
			velocity.x = _dash_direction * dash_speed
		MoveState.CLIMB:
			var climb_axis := Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
			velocity.y = climb_axis * move_speed
		_:
			velocity.y += _gravity() * delta

	if move_state != MoveState.DASH:
		var move_axis := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		var speed := move_speed * air_move_speed_multiplier if move_state == MoveState.AIR else move_speed
		velocity.x = move_axis * speed

	move_and_slide()
	_try_drop_through()
	_update_facing()
	_update_animation()


## Mirrors Enemy.take_damage()'s shape so hazards/enemies can damage the
## player through the same "has_method(&take_damage&)" duck-typed check
## Player already uses when its own attacks hit something.
func take_damage(amount: int) -> void:
	health.take_damage(amount)


func _gravity() -> float:
	return float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)) * gravity_scale


func _update_coyote_timer(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = max(0.0, _coyote_timer - delta)


func _update_move_state(delta: float) -> void:
	if move_state == MoveState.DASH:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			move_state = MoveState.GROUND if is_on_floor() else MoveState.AIR
		return

	var touching_climbable := _climbable_overlap_count > 0
	var climb_input := absf(Input.get_action_strength("move_up")) > 0.0 or absf(Input.get_action_strength("move_down")) > 0.0

	if touching_climbable and climb_input:
		move_state = MoveState.CLIMB
	elif move_state == MoveState.CLIMB and not touching_climbable:
		move_state = MoveState.AIR
	elif move_state != MoveState.CLIMB:
		move_state = MoveState.GROUND if is_on_floor() else MoveState.AIR

	if move_state == MoveState.GROUND:
		_dash_used_since_grounded = false


func _try_consume_jump() -> void:
	if move_state == MoveState.DASH:
		return
	if move_state == MoveState.CLIMB:
		if consume_buffered_action(&"jump", jump_buffer_window_ms):
			velocity.y = jump_velocity
			move_state = MoveState.AIR
		return
	if _coyote_timer > 0.0 and consume_buffered_action(&"jump", jump_buffer_window_ms):
		velocity.y = jump_velocity
		_coyote_timer = 0.0


func _try_consume_dash() -> void:
	if move_state == MoveState.CLIMB or move_state == MoveState.DASH:
		return
	if _dash_cooldown_timer > 0.0:
		return
	if move_state == MoveState.AIR and _dash_used_since_grounded:
		return
	if not consume_buffered_action(&"dash", dash_buffer_window_ms):
		return

	var axis := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	_dash_direction = signf(axis) if absf(axis) > 0.01 else (-1.0 if sprite.flip_h else 1.0)
	move_state = MoveState.DASH
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown
	if not is_on_floor():
		_dash_used_since_grounded = true


## Only the specific platforms in "one_way_platform" (see OneWayPlatform.gd)
## can be dropped through — the auto-generated Floor (Room.gd) and any
## authored terrain are never in that group, so ordinary ground structurally
## can't be dropped through no matter what's held.
func _try_drop_through() -> void:
	if not is_on_floor():
		return
	if not Input.is_action_pressed("move_down"):
		return
	for i in range(get_slide_collision_count()):
		var collider := get_slide_collision(i).get_collider()
		if collider is Node and collider.is_in_group(ONE_WAY_GROUP):
			_drop_through(collider)
			return


func _drop_through(platform: Node) -> void:
	add_collision_exception_with(platform)
	await get_tree().create_timer(drop_through_duration).timeout
	if is_instance_valid(platform):
		remove_collision_exception_with(platform)


## Attacking takes priority over movement: attacks are aimed at the cursor, so
## the character must turn to face it even while running the other way (running
## left and clicking right should swing right, not backwards). Otherwise
## movement input wins, so turning around still reads as instant on A/D, and
## the cursor is the fallback while standing still.
func _update_facing() -> void:
	# Attacks snap to the cursor with NO damping. A combo step is only ~0.15s
	# of visible strike, so routing attacks through the 0.12s turn delay meant
	# the punch was already over by the time the character turned — running
	# left and clicking right visibly swung the wrong way.
	if _attacking:
		_facing_hold_timer = 0.0
		var adx := get_global_mouse_position().x - global_position.x
		if absf(adx) > 1.0:
			sprite.flip_h = adx < 0.0
		return

	var move_axis := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	# Movement input still flips instantly — turning on A/D must feel immediate.
	if absf(move_axis) > 0.01:
		_facing_hold_timer = 0.0
		sprite.flip_h = move_axis < 0.0
		return

	# Cursor-driven facing is deliberately damped. Recomputing it every physics
	# frame made the sprite flicker whenever the cursor sat near the character,
	# since tiny movements cross the centre line repeatedly. Two guards:
	#   - a dead zone, so the cursor must be meaningfully to one side
	#   - a short hold, so a flip cannot be immediately undone
	var dx := get_global_mouse_position().x - global_position.x
	if absf(dx) < cursor_facing_dead_zone:
		return
	var want_left := dx < 0.0
	if want_left == sprite.flip_h:
		_facing_hold_timer = 0.0
		return
	_facing_hold_timer += get_physics_process_delta_time()
	if _facing_hold_timer >= cursor_facing_turn_delay:
		_facing_hold_timer = 0.0
		sprite.flip_h = want_left


## Punch animations are driven directly by ComboComponent's signals (see
## _on_combo_step_started/_on_combo_reset) — this only picks the ambient
## locomotion animation, and steps aside entirely while _attacking is true
## so it never interrupts an in-progress punch pose.
func _update_animation() -> void:
	if _attacking:
		# Airborne only: let the jump/fall pose through if the punch has been
		# held continuously past the cap (sustained spam). Grounded attacks are
		# unaffected — punch_walk already keeps the legs cycling there.
		if move_state == MoveState.AIR:
			_air_attack_hold += get_physics_process_delta_time()
			if _air_attack_hold < air_attack_pose_hold:
				return
		else:
			return
	else:
		_air_attack_hold = 0.0

	var anim: StringName
	match move_state:
		MoveState.DASH:
			anim = &"dash"
		MoveState.AIR:
			anim = &"jump" if velocity.y < 0.0 else &"fall"
		_:
			var speed_x := absf(velocity.x)
			if speed_x <= 5.0:
				anim = &"idle"
			elif speed_x >= run_animation_speed_threshold:
				anim = &"run"
			else:
				anim = &"walk"

	if sprite.animation != anim:
		sprite.play(anim)
		# AnimatedSprite2D.play() always restarts at frame 0. While spam-
		# attacking, the punch interrupts walk/run every ~0.15s, so without
		# this the locomotion cycle never advanced past frame 0-1 and the
		# character appeared to glide across the ground with static legs.
		# Resuming where the cycle left off keeps the legs actually walking
		# between hits.
		if anim == &"walk" or anim == &"run":
			var resume: int = _locomotion_frame.get(anim, 0)
			if resume < sprite.sprite_frames.get_frame_count(anim):
				sprite.frame = resume


## Every hit shows its pose immediately, no matter how fast the player is
## clicking — an earlier attempt skipped poses to guarantee the run
## animation a minimum visible window, but that made attacks feel like they
## weren't registering during spam-clicking. Reliability of the attack pose
## wins; the run animation still gets to show during recovery (see
## _on_combo_recovery_started) for anything other than back-to-back clicks
## faster than a single frame apart.
func _on_combo_step_started(_index: int, step: ComboStep) -> void:
	# Remember where the walk/run cycle was so it can resume rather than
	# restart when the punch releases — see _update_animation().
	if sprite.animation == &"walk" or sprite.animation == &"run":
		_locomotion_frame[sprite.animation] = sprite.frame
	_attacking = true

	# Attacking while moving on the ground uses `punch_walk`: a walk cycle with
	# the strike thrown mid-stride. The static punch poses have planted feet,
	# so playing them while the body translates was what read as gliding —
	# spam-attacking left `_attacking` true almost continuously, and the combo
	# starts its next step on the very frame recovery begins, so the walk cycle
	# never got a chance to draw. Keeping the legs in the attack art itself
	# fixes it without dropping any punch pose.
	if _is_moving_on_ground():
		# Snap to the strike frame only when ENTERING punch_walk, so the swing
		# is visible the instant you click. Re-snapping on every chained hit
		# kept yanking the cycle back to the same frame, which froze the legs —
		# the back leg in particular barely moved. Once the animation is
		# already running, let it keep cycling: the strike comes back around
		# each loop (frames 4 and 5), and the stride stays alive between hits.
		if sprite.animation != &"punch_walk":
			sprite.play(&"punch_walk")
			sprite.frame = PUNCH_WALK_STRIKE_FRAME
		return

	# AIRBORNE: the punch still plays — an attack must always show a strike.
	# It is only prevented from holding INDEFINITELY. Spam-attacking keeps
	# `_attacking` true almost continuously (the combo starts its next step on
	# the frame recovery begins), which previously froze the character mid-air
	# in an attack stance. `_air_attack_hold` caps how long the pose may hold
	# CONTINUOUSLY; once exceeded, jump/fall shows again briefly and the timer
	# resets, so the character keeps reading as airborne. Every individual
	# attack still gets its pose — no strike is ever skipped.
	if move_state == MoveState.AIR:
		_air_attack_hold = 0.0
	sprite.play(step.animation_name)


func _is_moving_on_ground() -> bool:
	return move_state == MoveState.GROUND and absf(velocity.x) > 5.0


## Recovery is "between hits," not part of the visible swing — releasing
## the animation lock here lets walk/idle resume immediately if the player
## is moving, instead of freezing on the punch pose for the whole step
## (which made spam-attacking while moving look like gliding, since the
## legs never animated even though the character kept sliding forward).
func _on_combo_recovery_started() -> void:
	_attacking = false


func _on_combo_reset() -> void:
	_attacking = false


## --- Shared input buffer ---
## Records the timestamp of a discrete press; consume_buffered_action lets
## any system (jump/dash handling here, the combo component) check "was
## this pressed within the last N ms" without racing _physics_process.

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
	if event.is_action_pressed("dash"):
		_buffer_action(&"dash")
		return
	if event.is_action_pressed("attack"):
		_buffer_action(&"attack")
		return
	for i in range(1, 10):
		if event.is_action_pressed("hotbar_%d" % i):
			active_hotbar_slot = i
			EventBus.hotbar_slot_changed.emit(i)
			return


func _on_climb_area_entered(area: Area2D) -> void:
	if area.is_in_group("climbable"):
		_climbable_overlap_count += 1


func _on_climb_area_exited(area: Area2D) -> void:
	if area.is_in_group("climbable"):
		_climbable_overlap_count = max(0, _climbable_overlap_count - 1)
