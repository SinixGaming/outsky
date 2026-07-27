extends Node
## Pure disk I/O. Atomic write + SHA-256 checksum + one-generation backup,
## defeating the two realistic failure modes for a single-player desktop
## save: crash/power-loss mid-write, and silent bit-rot/partial corruption.

const PlayerSaveDataScript = preload("res://scripts/save/PlayerSaveData.gd")

const SAVE_DIR := "user://saves/"
const SAVE_FILENAME := "save_slot_0.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_DIR + SAVE_FILENAME)


func save_game() -> bool:
	return _write_save_file(SAVE_DIR + SAVE_FILENAME, GameState.data.to_dict())


## Loads the primary save, falling back to the .bak generation if the
## primary is missing/corrupt. Returns false only if neither is usable.
func load_game() -> bool:
	var data := _read_save_file(SAVE_DIR + SAVE_FILENAME)
	if data.is_empty():
		data = _read_save_file(SAVE_DIR + SAVE_FILENAME + ".bak")
		if data.is_empty():
			return false
		push_warning("SaveManager: primary save missing/corrupt, recovered from backup")
	GameState.data = PlayerSaveDataScript.from_dict(data)
	return true


## Re-serializes the LIVE in-memory GameState straight to a user-chosen
## path, through the same atomic-write routine as the real save slot.
func export_save(dest_path: String) -> bool:
	return _write_save_file(dest_path, GameState.data.to_dict(), false)


## Validates the chosen file before ever touching the real save slot —
## an imported file is never trusted blindly, same gate as a normal load.
func import_save(src_path: String) -> bool:
	var data := _read_save_file(src_path)
	if data.is_empty():
		push_warning("SaveManager: import source failed validation: %s" % src_path)
		return false
	if not _write_save_file(SAVE_DIR + SAVE_FILENAME, data):
		return false
	GameState.data = PlayerSaveDataScript.from_dict(data)
	return true


## --- Internal: atomic write with checksum + backup ---

func _write_save_file(path: String, data_dict: Dictionary, make_backup: bool = true) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())

	var payload_string := JSON.stringify(data_dict)
	var envelope := {
		"checksum": _sha256(payload_string),
		"payload": payload_string,
	}
	var envelope_string := JSON.stringify(envelope)

	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: failed to open %s for writing (error %s)" % [tmp_path, FileAccess.get_open_error()])
		return false
	file.store_string(envelope_string)
	file.flush()
	file.close()

	if make_backup and FileAccess.file_exists(path):
		var dir := DirAccess.open(path.get_base_dir())
		if dir:
			dir.copy(path, path + ".bak")

	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		push_error("SaveManager: failed to open directory for %s" % path)
		return false
	var err := dir.rename(tmp_path, path)
	if err != OK:
		push_error("SaveManager: atomic rename failed for %s (error %s)" % [path, err])
		return false
	return true


func _read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("checksum") or not parsed.has("payload"):
		push_warning("SaveManager: malformed save envelope at %s" % path)
		return {}

	var payload_string: String = parsed["payload"]
	if _sha256(payload_string) != parsed["checksum"]:
		push_warning("SaveManager: checksum mismatch at %s" % path)
		return {}

	var payload: Variant = JSON.parse_string(payload_string)
	if typeof(payload) != TYPE_DICTIONARY:
		push_warning("SaveManager: payload is not a valid object at %s" % path)
		return {}
	return payload


func _sha256(text: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	return ctx.finish().hex_encode()
