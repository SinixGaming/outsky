class_name DamageCalculator
extends RefCounted
## Centralizes the stat -> damage formula so Player/Enemy/Boss share one
## implementation instead of duplicating math. Defender-side mitigation
## (armour/piercing) requires the defender to carry a stats dict, which
## enemies don't yet (Phase 2 enemies are still placeholders) — that half
## of the formula is included now so combat code written against it doesn't
## need to change once enemy stats exist, but callers with no defender
## stats can skip straight to apply_defense with an empty dict (no-op).

static func compute_raw_damage(attacker_stats: Dictionary, damage_type: String, multiplier: float) -> int:
	var stat_key := "magic_damage" if damage_type == "magic" else "physical_damage"
	var base: float = float(attacker_stats.get(stat_key, 0))
	return int(round(base * multiplier))


## armour is a flat reduction (per the design — not a percentage); piercing
## ignores some of it. defender_stats may be empty (no mitigation applied).
static func apply_defense(raw_damage: int, defender_stats: Dictionary, piercing: float = 0.0) -> int:
	var armour: float = float(defender_stats.get("armour", 0))
	var effective_armour: float = max(0.0, armour - piercing)
	return max(0, int(round(raw_damage - effective_armour)))


static func compute_vamp_heal(damage_dealt: int, attacker_stats: Dictionary) -> int:
	var vamp: float = float(attacker_stats.get("vamp", 0.0))
	return int(round(damage_dealt * vamp))
