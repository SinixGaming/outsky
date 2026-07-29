class_name StaticFurniture
extends StaticBody2D
## Generic solid placeholder furniture piece — bed, table, kitchen counter,
## training dummy, etc. Same "fill the texture slot only if it's empty"
## guard every entity in this project already uses, generalized once
## instead of repeating it per furniture type.

const PlaceholderTextureScript = preload("res://scripts/core/PlaceholderTexture.gd")

@export var placeholder_size: Vector2i = Vector2i(48, 24)
@export var placeholder_color: Color = Color(0.5, 0.35, 0.2)

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	if sprite.texture == null:
		sprite.texture = PlaceholderTextureScript.make(placeholder_size, placeholder_color)
	if collision_shape.shape == null:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(placeholder_size)
		collision_shape.shape = shape
