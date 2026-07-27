class_name WorldMemoryConfig
extends Resource
## Tunable timers for the room-memory TTL system. A data asset rather than
## hardcoded constants so these can be adjusted without touching WorldMemory.gd.

@export var item_expiry_seconds: float = 300.0
@export var enemy_respawn_seconds: float = 480.0
## Resource/harvest nodes are meant scarcer than trash-mob respawns, and are
## never cleared by player death (see WorldMemory.force_clear_room), so a
## longer default is appropriate.
@export var resource_respawn_seconds: float = 900.0
@export var prune_sweep_interval_seconds: float = 45.0
