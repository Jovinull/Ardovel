extends GutTest
## Translations: the tables match their source, every key the game uses exists in every
## language, texts fit the dialogue box, and the language can be switched and is remembered.

const CSV := "res://locale/text.csv"
const GameScene := preload("res://game/game.tscn")
const HudScene := preload("res://ui/hud/hud.tscn")
const PauseScene := preload("res://ui/pause/pause_screen.tscn")
const DIR := "user://test_saves/localization"
## Folders holding the game's scripts and scenes.
const GAME_DIRS: Array[String] = [
	"res://actors", "res://combat", "res://fx", "res://game", "res://interaction", "res://items", "res://ui",
	"res://world",
]
## Lines the message box shows at once.
const BOX_LINES := 3


func before_each() -> void:
	var dir := ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))


func after_each() -> void:
	TranslationServer.set_locale(Settings.LOCALES[0])


## Rows of the source table: key -> {locale: text}.
func _source_table() -> Dictionary:
	var file := FileAccess.open(CSV, FileAccess.READ)
	var header := file.get_csv_line()
	var table := {}
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < header.size() or row[0].is_empty():
			continue
		var texts := {}
		for column in range(1, header.size()):
			texts[header[column]] = row[column].c_unescape()
		table[row[0]] = texts
	return table


func test_the_imported_tables_match_the_source() -> void:
	# The generated .translation files are committed; they must never lag behind text.csv.
	var table := _source_table()
	assert_gt(table.size(), 0)
	for locale in Settings.LOCALES:
		var translation := TranslationServer.get_translation_object(locale)
		assert_eq(translation.locale, locale)
		assert_eq(translation.get_message_count(), table.size(), locale)
		for key: String in table:
			assert_eq(String(translation.get_message(key)), table[key][locale], "%s %s" % [locale, key])


func test_every_key_has_a_text_in_every_language() -> void:
	var table := _source_table()
	for key: String in table:
		for locale in Settings.LOCALES:
			var text: String = table[key][locale]
			assert_false(text.strip_edges().is_empty(), "%s %s" % [locale, key])
			assert_ne(text, key, "%s %s shows its key" % [locale, key])


func test_the_game_uses_exactly_the_keys_of_the_table() -> void:
	var keys := RegEx.create_from_string("\"([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\"")
	var used := {}
	for dir in GAME_DIRS:
		for path in _game_files(dir):
			for found in keys.search_all(FileAccess.get_file_as_string(path)):
				used[found.get_string(1)] = path
	var table := _source_table()
	var unknown := used.keys().filter(func(key: String) -> bool: return not table.has(key))
	var unused := table.keys().filter(func(key: String) -> bool: return not used.has(key))
	assert_eq(unknown, [], "keys without a text")
	assert_eq(unused, [], "texts nothing shows")


func test_no_player_text_is_left_in_scripts_or_scenes() -> void:
	# Accented letters in a string literal mean Portuguese text that skipped the table.
	var strings := RegEx.create_from_string("\"(?:[^\"\\\\]|\\\\.)*\"")
	var leftovers := {}
	for dir in GAME_DIRS:
		for path in _game_files(dir):
			for literal in strings.search_all(FileAccess.get_file_as_string(path)):
				for ch in literal.get_string():
					if ch.unicode_at(0) > 126:
						leftovers[literal.get_string()] = path
	assert_eq(leftovers, {})


func test_every_page_fits_the_message_box_in_every_language() -> void:
	var hud: Hud = HudScene.instantiate()
	add_child_autofree(hud)
	var label: Label = hud.get_node(^"%Message")
	var table := _source_table()
	for key: String in table:
		for locale in Settings.LOCALES:
			for page in (table[key][locale] as String).split("\n\n", false):
				label.text = page
				assert_lte(label.get_line_count(), BOX_LINES, "%s %s: %s" % [locale, key, page])


func test_pause_controls_fit_on_the_pause_screen_in_every_language() -> void:
	var pause: PauseScreen = PauseScene.instantiate()
	add_child_autofree(pause)
	pause.open()
	pause.choose(PauseScreen.Choice.CONTROLS)
	var controls: Label = pause.get_node(^"%Controls")
	for locale in Settings.LOCALES:
		TranslationServer.set_locale(locale)
		await wait_process_frames(1)
		assert_eq(controls.get_line_count(), 5, locale)
		assert_lte(controls.get_line_count() * (controls.get_line_height() + 1), int(controls.size.y) + 1, locale)


func test_pause_title_stays_centered_when_scaled() -> void:
	var pause: PauseScreen = PauseScene.instantiate()
	add_child_autofree(pause)
	await wait_process_frames(1)
	var title: Label = pause.get_node(^"%Title")
	var center := title.get_global_transform_with_canvas() * (title.size / 2.0)
	assert_almost_eq(center.x, get_viewport().get_visible_rect().size.x / 2.0, 0.1)


func test_first_step_guidance_fits_in_every_language() -> void:
	var hud: Hud = HudScene.instantiate()
	add_child_autofree(hud)
	hud.set_guidance("FIRST_STEP_GUIDANCE")
	var label: Label = hud.get_node(^"%Guidance")
	var expected: Dictionary = _source_table()["FIRST_STEP_GUIDANCE"]
	for locale in Settings.LOCALES:
		TranslationServer.set_locale(locale)
		await wait_process_frames(1)
		assert_true(hud.is_guidance_visible(), locale)
		var expected_first_line := String(expected[locale]).split("\n")[0]
		assert_eq(label.text.split("\n")[0], expected_first_line, locale)
		var expected_guidance := InputPrompts.format_template(String(expected[locale]), [
			InputPrompts.pause_label(false),
			InputPrompts.dismiss_label(false, ""),
		])
		assert_eq(label.text, expected_guidance, locale)
		assert_lte(label.get_line_count(), 2, locale)


func test_guidance_without_placeholders_is_displayed_unchanged() -> void:
	var hud: Hud = HudScene.instantiate()
	add_child_autofree(hud)
	TranslationServer.set_locale("en")
	hud.set_guidance("BOSS_ROOT_WARDEN")
	var label: Label = hud.get_node(^"%Guidance")
	assert_eq(label.text, "Root Warden")


func _launch(path: String) -> Game:
	var game: Game = GameScene.instantiate()
	game.save_path = DIR.path_join("save.json")
	game.settings_path = path
	add_child_autofree(game)
	await wait_physics_frames(1)
	return game


func test_the_title_switches_language_at_once_and_remembers_it() -> void:
	var path := DIR.path_join("settings.cfg")
	var game := await _launch(path)
	var title: TitleScreen = game.get_node(^"TitleScreen")
	var subtitle: Label = title.get_node(^"Root/Subtitle")
	assert_eq(subtitle.atr(subtitle.text), "O Santuário Esquecido")
	title.choose(TitleScreen.Choice.LANGUAGE)
	assert_eq(TranslationServer.get_locale(), "en")
	assert_eq(subtitle.atr(subtitle.text), "The Forgotten Shrine", "no restart needed")
	var options := title.get_node(^"%Options")
	var language: Label = options.get_child(title.choices.find(TitleScreen.Choice.LANGUAGE))
	assert_eq(language.text.trim_prefix("> ").strip_edges(), "Language: English")
	assert_false(FileAccess.file_exists(game.save_path), "the language is not part of the adventure")
	game.queue_free()
	await wait_physics_frames(2)
	TranslationServer.set_locale("pt_BR")
	var again := await _launch(path)
	assert_eq(TranslationServer.get_locale(), "en", "remembered on the next launch")
	again.get_node(^"TitleScreen").choose(TitleScreen.Choice.LANGUAGE)
	assert_eq(TranslationServer.get_locale(), "pt_BR", "and back")


func test_villagers_speak_the_chosen_language() -> void:
	var settings := Settings.new(DIR.path_join("settings.cfg"))
	settings.locale = "en"
	settings.save()
	var game := await _launch(settings.path)
	game.start_new()
	await wait_physics_frames(2)
	var hud: Hud = game.get_node(^"HUD")
	var player := game.level.player
	var anselmo: Npc = game.level.get_node(^"Entities/Anselmo")
	player.global_position = anselmo.global_position + Vector2(0, 14)
	await wait_physics_frames(3)
	assert_true(player.interactor.interact(player))
	assert_eq((hud.get_node(^"%Speaker") as Label).text, "Anselmo", "no honorific in English")
	assert_eq((hud.get_node(^"%Message") as Label).text, "Morning! Good to see you up and about.")


func _game_files(dir: String) -> Array[String]:
	var files: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() in ["gd", "tscn", "tres"]:
			files.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		files.append_array(_game_files(dir.path_join(sub)))
	return files
