class_name VitaPool
extends Node
## Mana-equivalent resource pool. Shape mirrors Health.gd deliberately, but
## as an independent script (not a subclass) — nothing spends Vita yet, so
## this only exists to give the HUD a real signal to bind to instead of
## polling GameState.data.stats directly.

signal pool_changed(current: int, max_value: int)

@export var max_vita: int = 100
var current_vita: int


func _ready() -> void:
	current_vita = max_vita


func spend(amount: int) -> bool:
	if current_vita < amount:
		return false
	current_vita -= amount
	pool_changed.emit(current_vita, max_vita)
	return true


func restore(amount: int) -> void:
	current_vita = min(max_vita, current_vita + amount)
	pool_changed.emit(current_vita, max_vita)
