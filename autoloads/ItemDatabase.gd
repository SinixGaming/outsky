extends Node
## Loads every data/items/*.tres into an item_id -> ItemDefinition lookup.
## The death/respawn flow (Stage 6) uses this to tell quest-temporary items
## apart from permanent ones without hardcoding item ids anywhere.

const ITEMS_DIR := "res://data/items/"

var _definitions: Dictionary = {}  # Dictionary[StringName, ItemDefinition]


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	var dir := DirAccess.open(ITEMS_DIR)
	if dir == null:
		push_warning("ItemDatabase: could not open %s" % ITEMS_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var resource: Resource = load(ITEMS_DIR + file_name)
			if resource is ItemDefinition and resource.item_id != &"":
				_definitions[resource.item_id] = resource
		file_name = dir.get_next()
	dir.list_dir_end()


func get_definition(item_id: StringName) -> ItemDefinition:
	return _definitions.get(item_id)


func is_quest_temporary(item_id: StringName) -> bool:
	var def := get_definition(item_id)
	return def != null and def.is_quest_temporary
