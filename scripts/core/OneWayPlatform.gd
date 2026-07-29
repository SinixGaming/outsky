class_name OneWayPlatform
extends StaticBody2D
## A "downable" platform — solid from above, but the player can hold
## move_down while standing on it to fall through (see Player._drop_through
## in scripts/player/Player.gd). Self-tags into "one_way_platform" (same
## idiom as ClimbableZone.gd tagging "climbable") so Player.gd can tell a
## shelf apart from ordinary terrain, which is never in this group — most
## floors structurally cannot be dropped through, only platforms placed
## with this script can.

const PlaceholderTextureScript = preload("res://scripts/core/PlaceholderTexture.gd")

@export var platform_size: Vector2 = Vector2(96, 12)
@export var platform_color: Color = Color(0.5, 0.35, 0.2)
@export var indicator_thickness: float = 3.0
@export var indicator_color: Color = Color(0.95, 0.85, 0.3)

@onready var body_sprite: Sprite2D = $BodySprite
@onready var indicator_sprite: Sprite2D = $IndicatorSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("one_way_platform")

	if body_sprite.texture == null:
		body_sprite.texture = PlaceholderTextureScript.make(Vector2i(platform_size), platform_color)
	if indicator_sprite.texture == null:
		indicator_sprite.texture = PlaceholderTextureScript.make(Vector2i(Vector2(platform_size.x, indicator_thickness)), indicator_color)
		indicator_sprite.position = Vector2(0, -(platform_size.y / 2.0) + (indicator_thickness / 2.0))

	if collision_shape.shape == null:
		var shape := RectangleShape2D.new()
		shape.size = platform_size
		collision_shape.shape = shape
	collision_shape.one_way_collision = true

	# Simple, non-overwhelming "you can drop through here" cue.
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(indicator_sprite, "modulate:a", 0.6, 1.2)
	tween.tween_property(indicator_sprite, "modulate:a", 1.0, 1.2)
