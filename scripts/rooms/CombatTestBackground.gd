extends Node2D
## The non-interactive BACKGROUND layer for the combat test arena — a
## distant, dimmed/desaturated grass-field-with-trees backdrop. Deliberately
## separate from the room's Ground/Floor (the solid, contrasted FOREGROUND
## terrain the player actually stands on) so the two read as visually
## distinct per the design: background sets regional mood and never has
## collision, foreground is what's actually tangible.

const PlaceholderTextureScript = preload("res://scripts/core/PlaceholderTexture.gd")

@export var sky_size: Vector2i = Vector2i(900, 400)
@export var sky_color: Color = Color(0.42, 0.55, 0.48)
## Local x offsets (relative to this node) for each tree silhouette.
@export var tree_positions: Array[float] = [-330.0, -70.0, 230.0, 380.0]


func _ready() -> void:
	z_index = -10
	# Faded/distant look — dimmer and slightly desaturated relative to the
	# foreground's full-contrast colors.
	modulate = Color(0.62, 0.65, 0.66, 1.0)

	var sky := Sprite2D.new()
	sky.texture = PlaceholderTextureScript.make(sky_size, sky_color)
	add_child(sky)

	for x in tree_positions:
		_add_tree(x)


func _add_tree(x: float) -> void:
	var half := sky_size.y / 2.0

	var trunk := Sprite2D.new()
	trunk.texture = PlaceholderTextureScript.make(Vector2i(14, 70), Color(0.32, 0.22, 0.15))
	trunk.position = Vector2(x, half - 35.0)
	add_child(trunk)

	var canopy := Sprite2D.new()
	canopy.texture = PlaceholderTextureScript.make(Vector2i(60, 60), Color(0.28, 0.42, 0.3))
	canopy.position = Vector2(x, half - 100.0)
	add_child(canopy)
