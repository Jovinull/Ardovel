extends GutHookScript
## Runs before the whole suite: every save made during the run goes to a throwaway folder, so
## tests can never read or overwrite the player's real save slot.

const TEST_SAVE_DIR := "user://test_saves"


func run() -> void:
	SaveFile.default_path = TEST_SAVE_DIR.path_join("save.json")
	var dir := ProjectSettings.globalize_path(TEST_SAVE_DIR)
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
