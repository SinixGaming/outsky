extends Node
## Global signal bus. Holds no state — lets gameplay nodes (Room, Enemy,
## ItemPickup, UI) communicate without direct references to each other.
## Godot's linter flags every signal here as "unused" because nothing in
## THIS file connects them — that's expected for a pure event bus (other
## scripts connect from outside); the warning_ignore annotations just quiet
## harmless debugger noise, not a real problem.

@warning_ignore("unused_signal")
signal enemy_died(room_id: StringName, spawn_uid: StringName, death_position: Vector2)
@warning_ignore("unused_signal")
signal item_dropped(room_id: StringName, item_uid: StringName, item_id: StringName, count: int, drop_position: Vector2)
@warning_ignore("unused_signal")
signal item_collected(room_id: StringName, item_uid: StringName)
@warning_ignore("unused_signal")
signal room_changed(room_id: StringName)
@warning_ignore("unused_signal")
signal player_stats_changed()
@warning_ignore("unused_signal")
signal gold_changed(new_gold: int, new_ether: int)
@warning_ignore("unused_signal")
signal player_died()
@warning_ignore("unused_signal")
signal player_respawned(room_id: StringName, spawn_id: StringName)
@warning_ignore("unused_signal")
signal waypoint_interacted(waypoint_id: StringName)
@warning_ignore("unused_signal")
signal hotbar_slot_changed(slot: int)
@warning_ignore("unused_signal")
signal stat_allocation_requested()
