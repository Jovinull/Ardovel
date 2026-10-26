class_name SaveFile
extends RefCounted
## The single save slot: an Adventure as JSON under user://.
##
## A write never destroys the last good save: the new data goes to "<path>.tmp" and is read back
## before it replaces the slot, and the previous valid save is kept as "<path>.bak". Loading
## falls back to that backup when the main file is missing or unreadable.

enum Status { NONE, LOADED, RECOVERED, MISSING, CORRUPT, INCOMPATIBLE }

## Where the game keeps its slot. The test run points this elsewhere (tests/hooks/pre_run.gd)
## so tests can never touch a player's save.
static var default_path := "user://save.json"

var path: String
## Outcome of the last load_adventure().
var status: Status = Status.NONE
var _read_status: Status = Status.NONE


func _init(file_path: String = "") -> void:
	path = file_path if not file_path.is_empty() else default_path


func backup_path() -> String:
	return path + ".bak"


## True when anything that may hold progress exists, even unreadable: a new adventure would
## replace it, so callers should confirm first.
func exists() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(backup_path())


func load_adventure() -> Adventure:
	if not exists():
		status = Status.MISSING
		return null
	var main := _read(path)
	if main != null:
		status = Status.LOADED
		return main
	var main_status := _read_status
	var backup := _read(backup_path())
	if backup != null:
		status = Status.RECOVERED
		return backup
	status = main_status if FileAccess.file_exists(path) else _read_status
	return null


func save(adventure: Adventure) -> Error:
	var temp := path + ".tmp"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(adventure.to_dict(), "\t"))
	var written := file.get_error()
	file.close()
	if written != OK:
		return written
	if _read(temp) == null:
		return ERR_FILE_CORRUPT
	# Only a readable save is worth keeping as the backup; an unreadable one is just replaced.
	if _read(path) != null:
		var kept := _replace(path, backup_path())
		if kept != OK:
			return kept
	return _replace(temp, path)


func _read(file_path: String) -> Adventure:
	if not FileAccess.file_exists(file_path):
		_read_status = Status.MISSING
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(file_path)) != OK or not json.data is Dictionary:
		_read_status = Status.CORRUPT
		return null
	var adventure := Adventure.from_dict(json.data)
	if adventure == null:
		var version: Variant = (json.data as Dictionary).get("version")
		var other_version := (version is float or version is int) and int(version) != Adventure.FORMAT_VERSION
		_read_status = Status.INCOMPATIBLE if other_version else Status.CORRUPT
	return adventure


## Moves `from` over `to`. Removing first keeps this portable: renaming onto an existing file
## is not guaranteed on every platform.
static func _replace(from: String, to: String) -> Error:
	if FileAccess.file_exists(to):
		var removed := DirAccess.remove_absolute(to)
		if removed != OK:
			return removed
	return DirAccess.rename_absolute(from, to)
