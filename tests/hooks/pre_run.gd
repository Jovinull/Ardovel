extends GutHookScript
## Runs before the whole suite: every save and settings file used during the run lives in a
## throwaway folder, so tests can never read or overwrite the player's own files. The run
## starts in the authoring language whatever the machine's language is.

const TEST_SAVE_DIR := "user://test_saves"


func run() -> void:
	SaveFile.default_path = TEST_SAVE_DIR.path_join("save.json")
	Settings.default_path = TEST_SAVE_DIR.path_join("settings.cfg")
	var dir := ProjectSettings.globalize_path(TEST_SAVE_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	var settings := Settings.new()
	settings.locale = Settings.LOCALES[0]
	settings.save()
	TranslationServer.set_locale(settings.locale)
