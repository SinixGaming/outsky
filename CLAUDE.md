# Outsky

keep responses concise without losing key information

## What this is

Outsky is a 2D side-view pixel-art action-RPG built in **Godot 4.7.1** (GDScript). The world ("Outsky") is large and multi-region, with dimensions/realms and per-location storylines, explored through a **room-streamed** overworld (one screen/level-chunk loaded at a time, connected by doors/transitions) rather than one continuous level. The player creates a character, allocates stat points, and explores rooms fighting enemies, collecting loot/gold, and progressing between hub towns and wilder regions.

The project is being built incrementally with Claude Code across a long collaborative session. This file exists so any future session (or future me) can pick up with full context instead of re-deriving it.

**Engine note**: the real, correct binary is Godot **4.7.1 stable**, at `C:\Users\user\OneDrive\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe` — matches `project.godot`'s `config/features=PackedStringArray("4.7", ...)`. An old `D:\Godot_v4.3-stable_win64.exe` also exists on this machine — do not use it. Verify with `--version` before trusting a remembered path; a whole session was burned on this once, and a *later* session still reached for the 4.3 binary out of habit before self-correcting mid-session — re-read this note at the start of any sprite/engine work, don't rely on memory.

**Git note**: the git repository root is `D:\` (the whole drive), not this `outsky/` folder — it also contains large amounts of unrelated personal files. Always scope `git add`/`git status` to `outsky/` explicitly.

**Source art drop location**: the user generates protagonist sprite sheets externally (ChatGPT) and drops them in `C:\Users\user\OneDrive\Desktop\SPRITE FOLDER INITIAL OFFICIA\` (newer batches in its `\new\` subfolder). Check there first when asked to integrate "the new sprites."

---

## Directory structure

```
outsky/
  autoloads/          Singletons (see Autoloads section below)
  scripts/
    core/              Shared base classes/components used across entities & rooms
    entities/          Scripts for interactable/gameplay objects (Enemy, Chest, etc.)
    player/            Player controller + player-only components (camera, combo, pools)
    rooms/             Room-specific one-off scripts (e.g. procedural backgrounds)
    save/              PlayerSaveData (the save schema)
    ui/                Menu/HUD/popup controllers
  scenes/
    main/Main.tscn      Root scene: persistent Player + world SubViewport + HUD + popups
    player/Player.tscn
    entities/           One .tscn per entity type, instanced into rooms
    rooms/outsky/        Room scenes (see Rooms section)
    ui/                 MainMenu, StatAllocationPopup, FadeOverlay, (legacy) CharacterCreation
  data/
    config/             Tunable resources (WorldMemoryConfig)
    items/              ItemDefinition .tres resources
    combos/             ComboChain .tres resources (attack data)
  assets/
    sprites/player/      Real protagonist sprite sheet + sliced frames + SpriteFrames resource
    ui/                  Real main menu background art
  project.godot
```

Sprite-pipeline one-off scripts (slicing, alignment, pixel-art pass, feet-align, dashify, etc.) live in the Claude scratchpad, not the repo. Re-derive them from this file's "Sprite pipeline" section if needed again rather than hunting for a specific old script.

Room/content naming convention: `<region>_<name>` room ids (e.g. `outsky_house_start`).

---

## Core architecture

### Autoloads (registered in this order in `project.godot`)

| Autoload | File | Responsibility |
|---|---|---|
| `EventBus` | `autoloads/EventBus.gd` | Pure signal bus, no state. Every cross-system notification flows through here. |
| `GameState` | `autoloads/GameState.gd` | The in-memory "current save" (`data: PlayerSaveData`). Room/rest tracking, inventory/gold, permanent flags, death/respawn sequence. |
| `WorldMemory` | `autoloads/WorldMemory.gd` | Session-scoped, TTL-based per-room memory (dead enemies, drops, harvested nodes) — NOT persisted. |
| `RoomManager` | `autoloads/RoomManager.gd` | Owns the currently-loaded room via `ROOM_REGISTRY` (id string → scene path, never a direct scene reference — avoids circular resources). `current_room_id` is set BEFORE `add_child(new_room)` — see gotchas. |
| `SaveManager` | `autoloads/SaveManager.gd` | Atomic write (`.tmp` → rename) + SHA-256 checksum + one-gen `.bak`. `user://saves/save_slot_0.json`. |
| `ItemDatabase` | `autoloads/ItemDatabase.gd` | Loads `data/items/*.tres` into an id → definition lookup. |
| `ResolutionManager` | `autoloads/ResolutionManager.gd` | Owns SubViewport letterboxing/render-scale. Never sets `SubViewport.size` directly (see gotchas). |

### Room system

`scripts/core/Room.gd` (`class_name Room extends Node2D`) is every room scene's root script. Philosophy: auto-generate a placeholder for anything a room doesn't author itself, but never override real content — every placeholder check is a null-check on a specific child node name.

Exported per-room config: `room_id`, `region_id`, `ground_color`/`ground_size` (placeholder fill if `Ground` Sprite2D has no texture), `floor_thickness` (generates a bottom-strip `StaticBody2D` "Floor" if none authored), `camera_bounds` (true playable extent, decoupled from `ground_size`), `camera_mode` (`fixed`/`dynamic_scroll`/`boss_arena`), `target_aspect_ratio`/`render_scale`, `is_dungeon_room`, `disable_autosave`, auto-generated boundary walls (left/right/top only — Floor seals the bottom).

**`debug_show_ground_line`** (export, default `true`): draws a magenta `Line2D` along the floor collider's **actual top surface**, read directly from the generated `Floor` CollisionShape2D rather than re-derived — so it will visibly disagree with painted floor art if they ever drift apart (the recurring "character floats" bug class). Prints the y-value to console on room load. Switch off for release.

`SpawnPoint`/`RoomTransitionZone` unchanged — doors reference target rooms by `StringName` id, never a direct scene resource.

### Player system (`scripts/player/Player.gd`)

`CharacterBody2D`, state machine `MoveState { GROUND, AIR, CLIMB, DASH }`.

- **Gravity/jump**: default gravity × `gravity_scale`, `jump_velocity=-400.0`, coyote time (0.1s) + jump buffering (100ms).
- **Climb**: `"climbable"` group + vertical input.
- **Dash**: Shift, `dash_speed=280.0`, `dash_duration=0.26s` (lengthened from 0.2 on request — distance = speed×duration, so this is what actually reads as "longer" vs raising speed), `dash_cooldown=7.0s` (deliberately long, meant to shrink with Stamina later — not yet wired), one-dash-per-airtime cap independent of cooldown.
- **Drop-through**: `"one_way_platform"` group + held `move_down`, `drop_through_duration=0.25s`.
- **Shared input buffer** (`_buffer_action`/`consume_buffered_action`): timestamped presses consumed within a window — enables jump/dash buffering and combo chaining.
- **Facing** (`_update_facing`): three tiers, in priority order —
  1. **Attacking** (`_attacking=true`): snaps instantly to cursor, no damping. Must stay undamped — a combo step's visible window (~0.15s) is shorter than any reasonable damping delay, so a damped attack turn visibly swings the wrong way mid-swing.
  2. **A/D held**: instant flip, unchanged from original behavior.
  3. **Idle cursor-aim**: damped via `cursor_facing_dead_zone` (24px) + `cursor_facing_turn_delay` (0.12s hold before a flip commits) — prevents flicker when the cursor sits near the character's centerline. Only applies here.
- **Animation** (`_update_animation`, driven by `move_state`/velocity):
  - `idle` / `walk` / `run` (ground, split by `run_animation_speed_threshold=150.0`) / `jump` / `fall` / `dash`.
  - Punch (`punch_1`/`punch_2`/`punch_3`) driven by `ComboComponent.combo_step_started`, gated by `_attacking`.
  - **Attacking while grounded+moving** plays `punch_walk` instead of a static punch — a walk cycle with the strike baked into the art (legs never freeze). Snaps to `PUNCH_WALK_STRIKE_FRAME` (frame 4 of 8, the extended-arm frame) only when *entering* the animation, not on every chained hit — re-snapping every hit was what froze the legs originally.
  - **Attacking while airborne** always shows the punch pose (every individual strike stays visible — there's no `punch_jump` art to fall back to), but `_air_attack_hold` caps how long it may show *continuously* (0.22s, tuned above one strike's visible window but below sustained-spam duration); past that, jump/fall interjects and the timer resets. Sustained spam reads as "jumping while punching," not frozen.
  - `_locomotion_frame` remembers walk/run's frame position across a punch interrupt so a completed combo resumes the cycle instead of restarting it (only matters for grounded non-`punch_walk` transitions now, since `punch_walk` is itself a full locomotion cycle).

`PlayerCamera` — `dynamic_scroll` (drag-margin dead zone, `drag_margin=0.1`), `fixed` (pinned, `top_level=true`), `boss_arena` (auto-fit zoom with a `min_zoom` panning fallback for oversized rooms, render-scale-corrected — see gotchas). `dynamic_scroll_zoom=2.75` for combat_test_arena.

Resource pools: `Health`, `VitaPool`/`SoulPool` (Vita/Soul unspent — no ability system yet).

### Combat

`ComboComponent` — Timer-driven, data-driven via `ComboChain`/`ComboStep` resources (`data/combos/combo_basic_fist.tres`, 3 steps). **Important for animation work**: during `recovery`, a buffered next attack starts its `_start_step()` on the very next `_process()` frame — meaning `_attacking` is essentially *continuously* true under sustained spam-click, not intermittently true. Any animation-lock logic gated on `_attacking` must account for this (see gotchas — this is what broke naive fixes for "gliding while attacking" twice).

`DamageCalculator` (static) — stat→damage formula, defender-side mitigation implemented but unused (enemies have no stats dict yet).

### Entities (`scripts/entities/*.gd` + matching `scenes/entities/*.tscn`)

All follow one repeated shape: `@onready var sprite`, fill with `PlaceholderTexture.make(size, color)` if empty, `Area2D`/`CharacterBody2D` group-based interaction checks.

| Entity | Pattern |
|---|---|
| `Enemy` | Self-checks `WorldMemory.is_dead()` on `_ready()`. On death: records death, spawns loot, pays gold via `GameState.record_enemy_kill()` — first-ever kill pays full `gold_value`, repeats pay 25%, except `is_dungeon_room` rooms which always pay full. |
| `Boss` | `extends Enemy`, uses `GameState.is_boss_defeated()`/`mark_boss_defeated()` instead of WorldMemory — dying mid-fight respawns a fresh boss on re-entry; a permanently-defeated one is skipped for good. |
| `ItemPickup` | Never authored in a room `.tscn` — always spawned at runtime. |
| `Chest` | Permanent-flag self-check, never respawns once opened. |
| `RestPoint` | Interact "bonfire": sets last-rest point, fully heals Health, autosaves. |
| `Waypoint` | Interact sign: records discovery, no travel-menu UI yet. |
| `Cupboard` | Interact-triggered chargen; emits `EventBus.stat_allocation_requested`, `Main.gd` reacts. |
| `Hazard` | Damages anything with `take_damage()` on contact. |
| `OneWayPlatform` | `one_way_collision=true` + `"one_way_platform"` group tag. |
| `ClimbableZone` | Tags into `"climbable"` group. |
| `StaticFurniture` | Generic solid placeholder prop. |

### Save system & data model

`scripts/save/PlayerSaveData.gd` — plain data object (not a Resource). `save_version=2`. 13-stat model (`health=50, health_regen=0.5, soul=3, attack_speed=1.0, physical_damage=10, magic_damage=5, piercing=0, vamp=0.0, vita=100, armour=0, elemental_point=0, stamina=5, speed=100`). Creation-time growth: 5 points across `health`/`physical_damage`/`magic_damage`/`stamina`/`speed` (+0.3/+0.2/+1/+2 per point respectively, `health` stored-only pending a leveling formula). JSON save (`{"checksum": sha256, "payload": ...}`), atomic write + one-gen `.bak`.

### Death/respawn flow

`Health.died` → `GameState.handle_player_death()`: gold→0, drop quest-temporary items, `WorldMemory.force_clear_room()` on current+previous room → respawn at last rest point → `Main.gd` fully heals the live Player node.

### UI

`MainMenu` (real background art, invisible pixel-positioned buttons), `StatAllocationPopup` (runtime popup, borrows `CharacterCreation.tscn`'s node structure), HUD (health/vita/soul bars with green→yellow→red fill + tween, hotbar, placeholder map panel). `CharacterCreation.tscn` is dead code kept only for the above.

---

## Sprite pipeline — conventions and hard-won methodology

This is the accumulated methodology for turning AI-generated reference sheets into game-ready, aligned, consistent frames. Re-derive the actual scripts from this description; don't assume old scratchpad scripts still exist.

**Slicing**: detect frame boundaries via fully-transparent (or chroma-keyed, for green-screen sheets — key threshold `g > 110 and g > r*1.4 and g > b*1.4`) column/row gaps, not fixed grid math — source sheets are not always evenly spaced.

**Alignment**: `AnimatedSprite2D.centered=true` positions each frame's *canvas center* at the node's world position — so what must match across frames is **head position relative to each frame's own canvas center**, not absolute pixel position, not a shared bounding-box crop. Head anchor = center-x/top-y of opaque pixels in the top ~28% of the silhouette.

**Scale**: use a **pose-independent invariant**, not canvas/bbox height (varies with limb extension) and not a fixed fraction of bbox height (tautological — always returns the same ratio by construction, a real mistake made and caught this session). **Head width** (widest opaque row in the top ~22% of the silhouette) is what's used now — normalize every set to a common target width so the character doesn't change size between animations. A canvas-height-only approach previously let head width swing 26.5% between animations before this was caught; head-width normalization cut that to ~13.7% residual (measurement noise on quantized edges).

**Canvas fit**: after scaling to the shared head-width target, verify the pose actually **fits vertically and horizontally** around the fixed head anchor — head-alignment alone only guarantees the head lines up, not that taller/wider poses (e.g. a new jump pose replacing a shorter old reference) fit the old canvas. Grow the canvas **symmetrically around the head anchor** to fit (never shrink the character to fit), with a real margin (~16px) — a mathematically tight fit still clipped once, from rounding plus a later pixel-art quantization pass nudging edges outward.

**Ground contact**: anchor **ground** animations (idle/walk/run/punch_walk/punch_*) by **feet**, not head — read the true target from `Player.tscn`'s actual `CollisionShape2D` (currently `RectangleShape2D(18,42)` centered on the node → bottom at node-space `+21px` → `÷ sprite scale (0.2)` → canvas-space offset from center). Head-only anchoring let feet float independently per animation as character height changed (idle floated worst, +3.5px, since it's the resting pose you actually stare at). **Do not** feet-anchor airborne (jump/fall) or lunging (dash) poses — dash's lowest point is a trailing foot mid-lunge; feet-aligning it like a standing pose shifted the body down up to 48px and made it look like standing still.

**Leading-leg verification — measure, never eyeball.** Technique: connected-component-detect foot skin-blobs in the lower ~28% of the frame, sample trouser luminance in a window just above each foot, classify front-brighter=NEAR(light leg forward)/front-darker=FAR(dark leg forward). Repeatedly, sheets that *looked* like a correct alternating cycle measured as 100% one-directional. Two synthesis attempts to fake the missing half from one-directional source art both failed and should not be re-attempted: global luminance-band recolor (flipped 2/8 frames — the two legs' shading ramps overlap in luminance, no color rule separates them) and spatial flood-fill leg segmentation (flipped 0/4 — legs merge below the crotch, flood-fill can't isolate them). **What actually works**: get genuinely complementary source art.

**The ChatGPT near-leg-forward problem** (recurring, asked-about again this session): image models default to shading whichever leg is drawn forward as bright/near, because that's the physically-grounded prior they learned — asking for "the dark/far leg forward" fights that prior and reliably fails or silently reverts. Two prompt strategies that empirically worked: (1) reframe the leg colors as a **fixed two-tone costume** ("left leg is always light brown, right leg is always dark brown, regardless of position") rather than any near/far or lighting language — turns it from a physics question into a paint-by-numbers one; (2) ask for **many variations (6-8) of one single wide-stride pose** rather than a described full cycle, then measure and pick the best rather than trusting a described sequence.

**Pixel-art color reduction**: source sheets carried ~83,000 distinct colors (continuous-tone AI shading merely resembling pixel art). Fix: downsample by an integer factor with **area averaging** (ignore transparent texels in the average), quantize to a **single shared palette** (k-means, ~32 colors, computed across all frames at once — a shared palette is what prevents colors shimmering between frames), re-upscale with **nearest** back to the aligned canvas size. Factor 3 was the largest reduction that preserved the eye/pupil/highlight (tested 2–6; 4+ loses the face — the eye is only ~4×3 source px). **Idle uses a gentler factor 2** specifically, since it's the pose you stand and stare at — palette stays shared across factors so there's no color mismatch.

**Color drift correction**: newly-generated sheets can come back visibly warmer than the established look (measured delta ~28–35 RGB distance). Fix for free as a side effect of the above: restrict which animations *contribute samples* to the palette-building step to trusted/reference sets only (idle/jump/fall/dash/punch_*), while still quantizing every frame — including the drifted new ones — *onto* that trusted palette.

**Procedural effects**: pure-geometry effects (unlike character art) can be drawn directly and correctly. Dash speed-lines/afterimage were added this way — horizontal streaks trailing off the character's back edge + a warm (not desaturated-grey — that read as a muddy smudge) afterimage offset backward, both intensity-modulated across the dash's frame arc (ramp → hold → ease).

**Chat-pasted images**: this session, images pasted directly into chat (not manually saved by the user) reliably landed as real, non-empty files at `C:\Users\user\AppData\Local\Temp\codex-clipboard-<uuid>.png` — **this supersedes the old assumption that chat-pastes are always 0-byte placeholders.** The remaining risk is *misidentification* among several recent candidates (a stale/unrelated codex-clipboard file can have a deceptively recent timestamp) — find the most-recently-modified match, then **Read and visually verify its content** before trusting it, rather than trusting recency alone. The user manually saving-and-sending an explicit path still also works and remains unambiguous when available.

---

## Known engine gotchas (hard-won — don't reintroduce these)

1. **Circular `ext_resource` scene references break Godot's loader.** Rooms reference each other by `StringName` id through `RoomManager.ROOM_REGISTRY`, never a direct `PackedScene` export.
2. **`SubViewport.size` cannot be set manually while its container has `stretch=true`.** Use `SubViewportContainer.stretch_shrink` instead.
3. **`RoomManager.current_room_id` must be set before `add_child(new_room)`** — `add_child()` synchronously runs the new room's full `_ready()` chain, and an empty StringName as a Dictionary key crashes on assignment in this build.
4. **Boundary walls must key off `camera_bounds`, not `ground_size`.**
5. **Physics interpolation** (`physics/common/physics_interpolation=true`) is required for smooth `CharacterBody2D` motion above 60Hz displays.
6. **The "menu buttons click lower than drawn" bug is the editor's Game Embed Mode**, not the game — uncheck "Embed Game on Next Play" in the Game bar dropdown. Diagnose via `run_outsky_standalone.bat`. Never nudge control-rect math to compensate for this.
7. One physical key can drive two input actions simultaneously (W → `move_up` + `jump`) with no conflict.
8. **Chat-pasted images**: see "Sprite pipeline" section above — this gotcha's guidance changed this session (codex-clipboard files now reliably contain real bytes; the risk shifted to misidentification, not emptiness).
9. **`godot --headless -s script.gd` never runs the normal bootstrap** — autoloads aren't registered, so any script referencing one by global name fails to compile, cascading to dependents. For isolated `Image`/pixel-math scripts this doesn't matter. For anything touching `RoomManager`/`GameState`/real gameplay flow, temporarily point `run/main_scene` at a throwaway scene, run `godot --headless` with **no** `-s` flag, then restore `run/main_scene` — never leave the throwaway in the tree.
10. **A freshly-written texture has no `.import` sidecar.** Run `godot --headless --import` once after adding/overwriting any `res://` image via script, before relying on it in-game.
11. **`TextureRect.STRETCH_KEEP_ASPECT_COVERED` + anchor-fill needs its overlaid UI repositioned with the same cover-crop transform on every resize** — a static anchor/offset can't reproduce a scale formula that's nonlinear in control size. See `MainMenu.gd::_reposition_art_buttons()`.
12. **A room's `floor_thickness` must be calibrated against where the *art* visually shows the floor**, not assumed — nothing checks physics collision against painted art. Re-check whenever a room's background art changes.
13. **Any HUD `Control` with default `mouse_filter` (`STOP`) silently eats gameplay clicks**, even with no handler attached. All decorative HUD elements need `mouse_filter=2` (IGNORE) explicitly; only real interactive `Button`s keep `STOP`.
14. **`PlayerCamera._auto_fit_zoom()` reads the SubViewport's internal (possibly render-scale-shrunk) resolution**, not on-screen size — multiply back in by `render_scale` before comparing against `min_zoom`, or the boss-arena size safety-net misfires.
15. **`ComboComponent` starts the next buffered combo step on the very next frame during recovery** — `_attacking` is continuously true under sustained spam, not intermittently. Any animation lock gated on it needs either baked-in locomotion art (`punch_walk`) or a hold-timer that periodically interjects (`_air_attack_hold`) — a naive "don't lock while attacking" drops the attack visual entirely, and a naive "resume saved locomotion frame" re-freezes if re-applied on every chained hit instead of only on first entry. See Player system section above.
16. **Cursor-facing damping (dead zone + hold delay) must never apply while `_attacking`** — a combo step's visible window is shorter than any reasonable damping delay, so a damped attack-facing swings the wrong way mid-swing.
17. **Character size across animations must be verified by a pose-independent invariant (head width), not canvas/bbox height** — see Sprite pipeline section. A 26.5% size swing between animations was shipped and caught only by explicit measurement, not visual review.
18. **The Aseprite/pixel-mcp plugin's bundled Windows launch path is broken as shipped**: `.mcp.json` points `command` at `bin/pixel-mcp`, a bash script with no file extension and CRLF line endings — native Windows process spawning (how Claude Code's host launches MCP servers) cannot execute it (confirmed: silent no-op, no exit code, even though the same file runs fine under Git Bash). Fix: edit `.mcp.json` in the plugin's **cache** directory (`C:\Users\user\.claude\plugins\cache\pixel-plugin\pixel-plugin\<version>\.mcp.json`) to point `command` directly at `bin/pixel-mcp-windows-amd64.exe`, and hardcode `env.PIXEL_MCP_CONFIG` to the real Windows config path (`C:\Users\user\AppData\Roaming\pixel-mcp\config.json`) rather than the `${HOME}/.config/...` template, which may not resolve under a native (non-POSIX) spawn. This lives in a cache dir and **may need reapplying after a plugin update**. A full app quit-and-reopen (not just a new chat) is required after any `.mcp.json` change for the MCP tool list to refresh.
19. **Neither Claude nor Aseprite's `draw_pixels`-style tools can originate character art.** There is no visual-generation capability behind them — `draw_pixels` requires *already knowing* the correct color for every coordinate, which is exactly the part that's missing. Demonstrated concretely: a from-scratch "zombie enemy" came out as a crude geometric placeholder (rectangles/circles), not usable character art. What these tools genuinely add over hand-rolled Godot `Image` scripts: proper k-means/octree quantizers with dithering, a real outline pass, `.aseprite` files with layers/tags the user can hand-edit, and — the actually tractable use case — **geometric/rule-based assets** (tiles, platforms, hazards, UI icons) where there's no character-design judgment required. Don't re-attempt "draw me a [character/creature]" from scratch; redirect to the user's external art tool.

---

## Asset status

**Protagonist** (`assets/sprites/player/frames/`, `protagonist_sprite_frames.tres`): fully rebuilt this session from new user-provided sheets. Current animation set: `idle`(3, loop) / `walk`(8, loop) / `run`(8, loop, new — didn't exist before, threshold-gated by speed) / `punch_walk`(8, loop, new — attacking-while-moving) / `jump`(2, non-loop) / `fall`(2, loop) / `dash`(6, non-loop, procedural speed-lines added) / `punch_1`/`punch_2`/`punch_3` (1 frame each, non-loop). All frames share a single ~32-color palette; ground-animation feet are anchored to the real collider; character size is head-width-normalized across sets. See Sprite pipeline section for the methodology if this needs redoing.

Old frame sets are backed up under `_pre_cleanup_sprite_backup/`, timestamped subfolders named `before_<change>_<HHMMSS>` (convention, not an exhaustive list — more accumulate each time frames are touched; check there before assuming art needs regenerating).

Also real: main menu background, `house_start`'s room background (`assets/room/starting_room_bg.png`, HUD-chrome-cropped from the original mockup; the mockup's painted character is still baked into it, near the bed, doesn't overlap interactables).

**Proposed, not started**: a full hooded-cloak-character replacement (Hollow-Knight-style cloth-only motion, no visible limb stepping — sidesteps the leg-alternation problem entirely and is explicitly meant to make future weapon art easier). A detailed 7-part ChatGPT prompt template exists (idle/run/jump/fall/dash/attack/attack-while-moving, one generation request per animation — splitting was the only thing that held consistency this session). **Not yet generated or decided on** — this would replace the current protagonist entirely if pursued; needs an explicit go-ahead, not just "draft me a prompt."

**Still placeholder**: all `combat_test_arena` environment art, enemies (flat red boxes / one crude geometric zombie test), chests, item icons, HUD icons. No CC0 asset pack has been pulled in (would need explicit download go-ahead).

---

## Current priorities / open questions

- **Architecture proposal, endorsed but not started**: split the player sprite into a body layer (`AnimatedSprite2D`, drawn *without* the attacking arm) + an arm pivot (`Node2D` at the shoulder, rotates to aim, holds a weapon-socket child `Node2D` at the hand). This is the real fix for both "attacks should aim at the cursor directionally" and "weapons in the future," and would make `punch_walk`/`_air_attack_hold` unnecessary — the body just keeps playing its own locomotion while the arm animates independently. Needs a fresh session: touches scene structure, `Player.gd`, and the whole frame pipeline, and needs newly-authored art (arm omitted from body frames, separate arm/weapon frames on a consistent pivot).
- **Hooded-cloak full character replacement** — see Asset status. Prompt is ready; generation/decision is pending the user.
- **Known gaps, unchanged from before**: combat_test_arena environment/enemy art still placeholder; Vita/Soul pools unspent (no ability system); dash cooldown not yet linked to the Stamina stat despite the design intent; quick-travel has data fields but no menu/teleport logic; Options/Credits menu buttons inert; no real region content authored yet (Inithia hub town per the original brief doesn't exist — current rooms are test/demo); `CharacterCreation.tscn` is dead code kept only because `StatAllocationPopup` borrows its node structure; combat_test_arena's `dynamic_scroll` camera has limited real scroll room (~200px) in its current small footprint.
