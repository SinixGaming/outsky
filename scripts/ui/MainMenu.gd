extends Control
## Background now fills the window edge-to-edge via
## TextureRect.STRETCH_KEEP_ASPECT_COVERED (see MainMenu.tscn) instead of
## being displayed at native size on a fixed offset — that removes the
## letterbox-style gray margins, but "covered" mode's scale-to-cover math
## (scale = max(W/tex_w, H/tex_h), then center-crop the overflow axis) is
## nonlinear in the control's size, so a static anchor/offset can't track it
## across arbitrary window sizes. _reposition_art_buttons() below reproduces
## that exact transform every time the window resizes, so these invisible
## buttons stay pixel-locked to the art regardless of window size/aspect.
##
## NOTE: the long-running "buttons are clickable lower than they're drawn"
## bug was NOT caused by this code, or by DPI. It was the editor's game
## embedding (Editor Settings > Run > Window Placement > Game Embed Mode,
## default "Floating window") adding a Game bar that offsets mouse input by
## roughly its own height. Confirmed by running standalone
## (`godot --path <project>`), where clicks land correctly. If click
## positions ever look wrong again, verify standalone BEFORE touching these
## rects — nudging them to compensate just breaks the real build.
##
## The offsets stored in MainMenu.tscn are overwritten at runtime by
## ART_BUTTON_RECTS below; they're kept in sync only so the editor preview
## isn't misleading at the default 1920x1080. Edit ART_BUTTON_RECTS, not the
## scene, if a button ever needs to move for real.

@onready var background: TextureRect = $Background
@onready var new_game_button: Button = $Background/NewGameButton
@onready var continue_button: Button = $Background/ContinueButton
@onready var quit_button: Button = $Background/QuitButton
@onready var export_button: Button = $ExportButton
@onready var import_button: Button = $ImportButton
@onready var status_label: Label = $StatusLabel
@onready var export_dialog: FileDialog = $ExportFileDialog
@onready var import_dialog: FileDialog = $ImportFileDialog
@onready var new_game_confirm_dialog: ConfirmationDialog = $NewGameConfirmDialog

const STARTING_ROOM_ID := &"outsky_house_start"
const STARTING_SPAWN_ID := &"default"

## Native-art-pixel rects the buttons were hand-placed at when the
## background was still displayed 1:1 (1672x941 source image). Kept as the
## single source of truth; _reposition_art_buttons() maps these into
## whatever rect STRETCH_KEEP_ASPECT_COVERED actually renders the art into.
const ART_BUTTON_RECTS := {
	"NewGameButton": Rect2(175, 328, 415, 77),
	"ContinueButton": Rect2(175, 415, 415, 75),
	"OptionsButton": Rect2(195, 520, 230, 55),
	"CreditsButton": Rect2(195, 582, 230, 55),
	"QuitButton": Rect2(195, 644, 230, 55),
}


func _ready() -> void:
	continue_button.disabled = not SaveManager.has_save()
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	export_button.pressed.connect(_on_export_pressed)
	import_button.pressed.connect(_on_import_pressed)
	export_dialog.file_selected.connect(_on_export_path_chosen)
	import_dialog.file_selected.connect(_on_import_path_chosen)
	new_game_confirm_dialog.confirmed.connect(_start_new_game)

	resized.connect(_reposition_art_buttons)
	_reposition_art_buttons()


## Reproduces TextureRect's STRETCH_KEEP_ASPECT_COVERED transform by hand so
## the (invisible) buttons on top of the art can be placed with the exact
## same math, instead of drifting from it at non-16:9 window sizes.
func _reposition_art_buttons() -> void:
	if background.texture == null:
		return
	var control_size := background.size
	var tex_size := background.texture.get_size()
	if control_size.x <= 0.0 or control_size.y <= 0.0 or tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return

	var scale: float = max(control_size.x / tex_size.x, control_size.y / tex_size.y)
	var displayed_size := tex_size * scale
	var top_left := (control_size - displayed_size) / 2.0

	for button_name in ART_BUTTON_RECTS:
		var button: Control = get_node("Background/%s" % button_name)
		var native_rect: Rect2 = ART_BUTTON_RECTS[button_name]
		button.position = top_left + native_rect.position * scale
		button.size = native_rect.size * scale


func _on_new_game_pressed() -> void:
	if SaveManager.has_save():
		new_game_confirm_dialog.popup_centered()
	else:
		_start_new_game()


## Spawns a fresh, zero-allocated character directly into the starting
## house — chargen now happens diegetically at the house's Cupboard rather
## than on a separate pre-game screen. Deliberately does not autosave (see
## Room.disable_autosave on house_start): this entry point is still a
## testing pass.
func _start_new_game() -> void:
	GameState.new_game("Wanderer", {}, STARTING_ROOM_ID, STARTING_SPAWN_ID)
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")


func _on_continue_pressed() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
	else:
		status_label.text = "No valid save found."


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_export_pressed() -> void:
	# Load first so we validate + export a real save, never a stale/blank
	# in-memory GameState (GameState may still be default at the menu).
	if not SaveManager.load_game():
		status_label.text = "No valid save to export."
		return
	export_dialog.popup_centered()


func _on_export_path_chosen(path: String) -> void:
	if SaveManager.export_save(path):
		status_label.text = "Exported to %s" % path
	else:
		status_label.text = "Export failed."


func _on_import_pressed() -> void:
	import_dialog.popup_centered()


func _on_import_path_chosen(path: String) -> void:
	if SaveManager.import_save(path):
		continue_button.disabled = false
		status_label.text = "Imported save from %s" % path
	else:
		status_label.text = "Import failed — invalid or corrupt file."
