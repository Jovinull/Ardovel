extends GutTest
## The save slot on disk: writing, reading back, broken files and keeping the last good save.

const DIR := "user://test_saves/slot"

var slot: SaveFile


func before_each() -> void:
	var dir := ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	slot = SaveFile.new(DIR.path_join("save.json"))


func _adventure(health: int) -> Adventure:
	var adventure := Adventure.new(&"forest", &"shrine")
	adventure.health = health
	adventure.set_flag(&"shrine_awakened")
	return adventure


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_the_test_run_never_uses_the_real_slot() -> void:
	assert_ne(SaveFile.default_path, "user://save.json")
	assert_true(SaveFile.new().path.begins_with("user://test_saves/"))


func test_nothing_saved_yet() -> void:
	assert_false(slot.exists())
	assert_null(slot.load_adventure())
	assert_eq(slot.status, SaveFile.Status.MISSING)


func test_first_save_then_load() -> void:
	assert_eq(slot.save(_adventure(5)), OK)
	assert_true(slot.exists())
	var loaded := slot.load_adventure()
	assert_eq(slot.status, SaveFile.Status.LOADED)
	assert_eq(loaded.area, &"forest")
	assert_eq(loaded.health, 5)
	assert_true(loaded.has_flag(&"shrine_awakened"))
	assert_false(FileAccess.file_exists(slot.path + ".tmp"), "no temporary file left behind")


func test_saving_again_keeps_the_previous_save_as_backup() -> void:
	slot.save(_adventure(5))
	slot.save(_adventure(3))
	assert_eq(slot.load_adventure().health, 3)
	var backup := SaveFile.new(slot.backup_path())
	assert_eq(backup.load_adventure().health, 5)


func test_a_truncated_save_falls_back_to_the_backup() -> void:
	slot.save(_adventure(5))
	slot.save(_adventure(3))
	var text := FileAccess.get_file_as_string(slot.path)
	_write(slot.path, text.substr(0, text.length() / 2))
	var loaded := slot.load_adventure()
	assert_eq(slot.status, SaveFile.Status.RECOVERED)
	assert_eq(loaded.health, 5)


func test_garbage_without_a_backup_is_reported_as_corrupt() -> void:
	_write(slot.path, "not json at all")
	assert_null(slot.load_adventure())
	assert_eq(slot.status, SaveFile.Status.CORRUPT)
	assert_true(slot.exists(), "still counts as existing progress: a new game must confirm")


func test_a_file_of_zero_bytes_is_corrupt() -> void:
	# What a write cut short by a power loss often leaves behind.
	var zeros := PackedByteArray()
	zeros.resize(64)
	var file := FileAccess.open(slot.path, FileAccess.WRITE)
	file.store_buffer(zeros)
	file.close()
	assert_null(slot.load_adventure())
	assert_eq(slot.status, SaveFile.Status.CORRUPT)


func test_valid_json_with_invalid_fields_is_corrupt() -> void:
	_write(slot.path, JSON.stringify({"version": 1, "area": "forest", "entry": "", "health": 3, "flags": []}))
	assert_null(slot.load_adventure())
	assert_eq(slot.status, SaveFile.Status.CORRUPT)


func test_a_save_from_another_format_version_is_incompatible() -> void:
	var data := _adventure(5).to_dict()
	data["version"] = Adventure.FORMAT_VERSION + 1
	_write(slot.path, JSON.stringify(data))
	assert_null(slot.load_adventure())
	assert_eq(slot.status, SaveFile.Status.INCOMPATIBLE)


func test_saving_over_a_corrupt_file_keeps_the_good_backup() -> void:
	slot.save(_adventure(5))
	slot.save(_adventure(4))
	_write(slot.path, "{ broken")
	assert_eq(slot.save(_adventure(2)), OK)
	assert_eq(slot.load_adventure().health, 2)
	assert_eq(SaveFile.new(slot.backup_path()).load_adventure().health, 5,
			"the unreadable file did not replace the last good backup")


func test_a_failed_write_leaves_the_previous_save_untouched() -> void:
	slot.save(_adventure(5))
	# The temporary path is taken by a folder, so the new data cannot be written.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(slot.path + ".tmp"))
	assert_ne(slot.save(_adventure(1)), OK)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(slot.path + ".tmp"))
	assert_eq(slot.load_adventure().health, 5)
