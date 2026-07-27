class_name ItemDefinition
extends Resource
## Static data for one item type. Inventory/save data references items by
## item_id string (see PlayerSaveData), never inlines this data, so
## balance/content changes here never require save migrations.

@export var item_id: StringName = &""
@export var display_name: String = ""
@export var max_stack: int = 99
@export var icon: Texture2D

## Quest keys and similar: dropped (not kept) on player death, per the
## death/economy design — prevents a key becoming stranded somewhere
## unreachable after a death, at the cost of restarting the quest.
@export var is_quest_temporary: bool = false
