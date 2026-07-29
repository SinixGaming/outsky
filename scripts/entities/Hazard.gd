class_name Hazard
extends Area2D
## Spikes/traps — part of the solid, interactable FOREGROUND layer (unlike
## decorative background pieces, this has real collision-adjacent presence:
## no physical body to stand on, but it hurts on contact). Damages anything
## with a take_damage() method that touches it — works against the player
## via Player.take_damage() and would work against enemies too if ever
## placed to hit them.

const PlaceholderTextureScript = preload("res://scripts/core/PlaceholderTexture.gd")

@export var damage: int = 5
@export var placeholder_size: Vector2i = Vector2i(20, 16)
@export var placeholder_color: Color = Color(0.75, 0.15, 0.15)

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	if sprite.texture == null:
		sprite.texture = PlaceholderTextureScript.make(placeholder_size, placeholder_color)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
