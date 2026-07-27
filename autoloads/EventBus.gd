extends Node
## Global signal bus. Holds no state — lets gameplay nodes (Room, Enemy,
## ItemPickup, UI) communicate without direct references to each other.

signal enemy_died(room_id: StringName, spawn_uid: StringName, death_position: Vector2)
signal item_dropped(room_id: StringName, item_uid: StringName, item_id: StringName, count: int, drop_position: Vector2)
signal item_collected(room_id: StringName, item_uid: StringName)
signal room_changed(room_id: StringName)
signal player_stats_changed()
signal gold_changed(new_gold: int, new_ether: int)
signal player_died()
signal player_respawned(room_id: StringName, spawn_id: StringName)
signal waypoint_interacted(waypoint_id: StringName)
