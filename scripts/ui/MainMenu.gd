extends Control

@onready var new_game_button: Button = $VBoxContainer/NewGameButton
@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var export_button: Button = $VBoxContainer/ExportButton
@onready var import_button: Button = $VBoxContainer/ImportButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var export_dialog: FileDialog = $ExportFileDialog
@onready var import_dialog: FileDialog = $ImportFileDialog


func _ready() -> void:
	continue_button.disabled = not SaveManager.has_save()
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	export_button.pressed.connect(_on_export_pressed)
	import_button.pressed.connect(_on_import_pressed)
	export_dialog.file_selected.connect(_on_export_path_chosen)
	import_dialog.file_selected.connect(_on_import_path_chosen)


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/CharacterCreation.tscn")


func _on_continue_pressed() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
	else:
		status_label.text = "No valid save found."


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
