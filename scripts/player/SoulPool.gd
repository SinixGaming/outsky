class_name SoulPool
extends Node
## Resource for powerful ultimate-tier spells. Shape mirrors Health.gd
## deliberately, but as an independent script (not a subclass) — nothing
## spends Soul yet, so this only exists to give the HUD a real signal to
## bind to instead of polling GameState.data.stats directly.

signal pool_changed(current: int, max_value: int)

@export var max_soul: int = 3
var current_soul: int


func _ready() -> void:
	current_soul = max_soul


func spend(amount: int) -> bool:
	if current_soul < amount:
		return false
	current_soul -= amount
	pool_changed.emit(current_soul, max_soul)
	return true


func restore(amount: int) -> void:
	current_soul = min(max_soul, current_soul + amount)
	pool_changed.emit(current_soul, max_soul)
