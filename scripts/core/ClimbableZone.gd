class_name ClimbableZone
extends Area2D
## Marks a region (ladder, vine, tower face) the player can climb. Player.gd
## detects overlap via its ClimbDetector child and checks group membership —
## this script's only job is to add itself to that group, so placing a
## ClimbableZone anywhere in a room needs no other wiring.


func _ready() -> void:
	add_to_group("climbable")
