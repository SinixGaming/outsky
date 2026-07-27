class_name Boss
extends Enemy
## Bosses never touch WorldMemory's respawn-suppression. Since RoomManager
## fully destroys/recreates rooms on every transition, dying mid-fight and
## re-entering the arena naturally spawns a fresh full-HP boss — a
## permanently-defeated boss is skipped via GameState.is_boss_defeated()
## instead. This is the entire boss-reset design: no death-flow-specific
## code needed anywhere else.

@export var boss_id: StringName = &""


func _is_already_defeated() -> bool:
	return GameState.is_boss_defeated(boss_id)


func _record_death() -> void:
	GameState.mark_boss_defeated(boss_id)
