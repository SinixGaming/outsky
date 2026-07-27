class_name ComboStep
extends Resource
## One step of a combo chain. Timing is placeholder (no real animations
## exist yet) — the seam a future AnimationPlayer binds to is
## ComboComponent's combo_step_started signal, so replacing these numbers
## with real animation-driven timing needs no redesign.

@export var animation_name: StringName = &""
@export_enum("physical", "magic") var damage_type: String = "physical"
@export var damage_multiplier: float = 1.0

@export var startup_time: float = 0.05
@export var active_time: float = 0.1
@export var recovery_time: float = 0.15

## How long after this step's active window a buffered attack press still
## chains into the next step, instead of resetting the combo.
@export var input_window_after: float = 0.3
