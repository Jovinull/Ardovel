extends GutTest
## Player settings: the remembered language, which language to show, and bad files.

const PATH := "user://test_saves/settings_unit.cfg"


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_a_chosen_language_survives_a_reload() -> void:
	var settings := Settings.new(PATH)
	settings.locale = "en"
	assert_eq(settings.save(), OK)
	var again := Settings.new(PATH)
	again.load_settings()
	assert_eq(again.locale, "en")


func test_missing_or_unknown_values_leave_the_choice_open() -> void:
	var settings := Settings.new(PATH)
	settings.load_settings()
	assert_eq(settings.locale, "", "no file yet")
	for bad: Variant in ["fr", 3, ["en"]]:
		var file := ConfigFile.new()
		file.set_value(Settings.SECTION, "locale", bad)
		file.save(PATH)
		settings.load_settings()
		assert_eq(settings.locale, "", str(bad))


func test_without_a_choice_the_system_language_is_used_when_the_game_has_it() -> void:
	var settings := Settings.new(PATH)
	assert_eq(settings.effective_locale("en_US"), "en")
	assert_eq(settings.effective_locale("pt_BR"), "pt_BR")
	assert_eq(settings.effective_locale("pt_PT"), "pt_BR", "other Portuguese falls back to pt_BR")
	assert_eq(settings.effective_locale("de_DE"), "pt_BR", "the authoring language otherwise")
	settings.locale = "pt_BR"
	assert_eq(settings.effective_locale("en_US"), "pt_BR", "a choice beats the system")


func test_languages_cycle() -> void:
	assert_eq(Settings.next_locale("pt_BR"), "en")
	assert_eq(Settings.next_locale("en"), "pt_BR")
