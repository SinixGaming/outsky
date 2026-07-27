class_name PlayerSaveData
extends RefCounted
## Plain data object for the player's save. Deliberately NOT a Resource —
## serialized to/from a Dictionary by SaveManager so the save file's shape
## never depends on GDScript class structure (see SaveManager.gd).

const CURRENT_VERSION := 2

## The 13-stat model. Bases per design: Health 50, Health Regen 0.5/s (slow —
## full regen in ~100s), Soul 3, Attack Speed 1.0 (multiplier, weapon-driven),
## Physical Damage 10, Magic Damage 5, Piercing 0, Vamp 0.0, Vita 100
## (regenerates fast via VitaPool's fixed rate, not this stat), Armour 0
## (flat reduction), Elemental Point 0, Stamina 5 (cooldowns only — not
## movement), Speed 100.
const DEFAULT_STATS := {
	"health": 50,
	"health_regen": 0.5,
	"soul": 3,
	"attack_speed": 1.0,
	"physical_damage": 10,
	"magic_damage": 5,
	"piercing": 0,
	"vamp": 0.0,
	"vita": 100,
	"armour": 0,
	"elemental_point": 0,
	"stamina": 5,
	"speed": 100,
}

## Raw 0-5 point counts allocated at character creation, permanent and never
## revisited. Only these 5 of the 13 stats are choosable at creation.
const GROWTH_KEYS := ["health", "physical_damage", "magic_damage", "stamina", "speed"]

var save_version: int = CURRENT_VERSION
var character_name: String = ""
var stats: Dictionary = DEFAULT_STATS.duplicate()
var creation_growth: Dictionary = {"health": 0, "physical_damage": 0, "magic_damage": 0, "stamina": 0, "speed": 0}

var level: int = 1
var xp: int = 0
var inventory: Array = []  # Array[Dictionary]: {"item_id": StringName, "count": int}
var current_room_id: StringName = &""
var current_spawn_id: StringName = &"default"
var defeated_bosses: Array = []  # Array[StringName]

## Currency. Gold is the common currency (kills, chests); ether is rarer
## (dungeon runs / high-tier kills), used for stat upgrades / trading.
var gold: int = 0
var ether: int = 0

## Where the player wakes up on death, fully healed.
var last_rest_room_id: StringName = &""
var last_rest_spawn_id: StringName = &"default"

## Permanent "ever killed" counts, keyed "<room_id>::<spawn_uid>" — distinct
## from WorldMemory's session-scoped respawn tracking. Used to discount gold
## payouts on repeat kills of the same overworld enemy.
var killed_enemies: Dictionary = {}  # Dictionary[String, int]

## Permanent flags, same pattern as defeated_bosses.
var opened_chests: Array = []  # Array[String]
var discovered_waypoints: Array = []  # Array[String]


func to_dict() -> Dictionary:
	return {
		"save_version": save_version,
		"character_name": character_name,
		"stats": stats.duplicate(),
		"creation_growth": creation_growth.duplicate(),
		"level": level,
		"xp": xp,
		"inventory": inventory.duplicate(true),
		"current_room_id": String(current_room_id),
		"current_spawn_id": String(current_spawn_id),
		"defeated_bosses": defeated_bosses.duplicate(),
		"gold": gold,
		"ether": ether,
		"last_rest_room_id": String(last_rest_room_id),
		"last_rest_spawn_id": String(last_rest_spawn_id),
		"killed_enemies": killed_enemies.duplicate(),
		"opened_chests": opened_chests.duplicate(),
		"discovered_waypoints": discovered_waypoints.duplicate(),
	}


static func from_dict(data: Dictionary) -> PlayerSaveData:
	var save := PlayerSaveData.new()
	save.save_version = int(data.get("save_version", CURRENT_VERSION))
	save.character_name = String(data.get("character_name", ""))

	var loaded_stats: Dictionary = data.get("stats", {})
	for key in save.stats.keys():
		if loaded_stats.has(key):
			save.stats[key] = loaded_stats[key]

	var loaded_growth: Dictionary = data.get("creation_growth", {})
	for key in save.creation_growth.keys():
		if loaded_growth.has(key):
			save.creation_growth[key] = int(loaded_growth[key])

	save.level = int(data.get("level", 1))
	save.xp = int(data.get("xp", 0))
	save.inventory = data.get("inventory", []).duplicate(true)
	save.current_room_id = StringName(data.get("current_room_id", ""))
	save.current_spawn_id = StringName(data.get("current_spawn_id", "default"))
	save.defeated_bosses = data.get("defeated_bosses", []).duplicate()

	save.gold = int(data.get("gold", 0))
	save.ether = int(data.get("ether", 0))
	save.last_rest_room_id = StringName(data.get("last_rest_room_id", ""))
	save.last_rest_spawn_id = StringName(data.get("last_rest_spawn_id", "default"))
	save.killed_enemies = data.get("killed_enemies", {}).duplicate()
	save.opened_chests = data.get("opened_chests", []).duplicate()
	save.discovered_waypoints = data.get("discovered_waypoints", []).duplicate()

	return save
