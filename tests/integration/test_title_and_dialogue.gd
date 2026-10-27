extends GutTest
## The title menu (never replacing progress by accident) and the paged dialogue box.

const GameScene := preload("res://game/game.tscn")
const DIR := "user://test_saves/title"

var game: Game
var title: TitleScreen
var hud: Hud


func before_each() -> void:
	var dir := ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))


func _launch() -> void:
	game = GameScene.instantiate()
	game.save_path = DIR.path_join("save.json")
	add_child_autofree(game)
	title = game.get_node(^"TitleScreen")
	hud = game.get_node(^"HUD")
	await wait_physics_frames(1)


func _write_save(text: String) -> void:
	var file := FileAccess.open(DIR.path_join("save.json"), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_first_launch_offers_a_new_adventure_and_quitting() -> void:
	await _launch()
	assert_true(title.is_open())
	assert_eq(title.choices, [TitleScreen.Choice.NEW, TitleScreen.Choice.LANGUAGE, TitleScreen.Choice.QUIT])
	title.choose(TitleScreen.Choice.NEW)
	assert_false(title.is_open())
	assert_eq(game.level.area_id, &"village")


func test_title_selection_is_marked_after_navigation() -> void:
	await _launch()
	var down := InputEventAction.new()
	down.action = &"move_down"
	down.pressed = true
	title.call(&"_unhandled_input", down)
	await wait_physics_frames(2)
	assert_eq(title.get(&"_selected"), 1)
	var selected := title.get_node(^"%Options").get_child(1) as Label
	assert_true(selected.text.begins_with("> "))


func test_first_step_guidance_can_be_dismissed_and_clears_after_anselmo() -> void:
	await _launch()
	TranslationServer.set_locale("pt_BR")
	title.choose(TitleScreen.Choice.NEW)
	assert_true(hud.is_guidance_visible())
	var guidance := (hud.get_node(^"%Guidance") as Label).text
	var expected_guidance := InputPrompts.format_template(tr("FIRST_STEP_GUIDANCE"), [
		InputPrompts.pause_label(false),
		InputPrompts.dismiss_label(false, ""),
	])
	assert_eq(guidance, expected_guidance)
	var dismiss := InputEventAction.new()
	dismiss.action = &"interact"
	dismiss.pressed = true
	hud.call(&"_unhandled_input", dismiss)
	await get_tree().create_timer(Hud.GUIDANCE_FADE_TIME + 0.1).timeout
	assert_false(hud.is_guidance_visible(), "the player can hide the hint with interact")
	hud.set_guidance("FIRST_STEP_GUIDANCE")
	assert_false(hud.is_guidance_visible(), "a dismissed hint does not pop back up")
	var npc: Npc = game.level.get_node(^"Entities/Anselmo")
	game.level.player.global_position = npc.global_position + Vector2(0, 14)
	await wait_physics_frames(3)
	assert_true(game.level.player.interactor.interact(game.level.player))
	assert_false(hud.is_guidance_visible(), "the hint disappears after the first objective is learned")
	assert_true(game.adventure.has_flag(&"heard_of_shrine"))


func test_first_step_guidance_fades_after_nine_seconds() -> void:
	await _launch()
	title.choose(TitleScreen.Choice.NEW)
	assert_true(hud.is_guidance_visible())
	await get_tree().create_timer(Hud.GUIDANCE_HOLD_TIME + Hud.GUIDANCE_FADE_TIME + 0.1).timeout
	assert_false(hud.is_guidance_visible())


func test_a_saved_adventure_can_be_continued() -> void:
	SaveFile.new(DIR.path_join("save.json")).save(Adventure.new(&"forest", &"south"))
	await _launch()
	assert_eq(title.choices[0], TitleScreen.Choice.CONTINUE)
	title.choose(TitleScreen.Choice.CONTINUE)
	assert_eq(game.level.area_id, &"forest")
	assert_true(hud.is_guidance_visible(), "an unfinished first objective remains visible after Continue")


func test_a_new_adventure_over_a_save_asks_first() -> void:
	var saved := Adventure.new(&"forest", &"shrine")
	saved.set_flag(&"forest_shrine_awakened")
	SaveFile.new(DIR.path_join("save.json")).save(saved)
	await _launch()
	title.choose(TitleScreen.Choice.NEW)
	assert_true(title.is_open(), "not started yet")
	assert_eq(title.choices, [TitleScreen.Choice.CANCEL, TitleScreen.Choice.CONFIRM_NEW], "'no' comes first")
	title.choose(TitleScreen.Choice.CANCEL)
	assert_eq(title.choices[0], TitleScreen.Choice.CONTINUE)
	assert_true(game.save_slot.load_adventure().has_flag(&"forest_shrine_awakened"), "progress untouched")
	title.choose(TitleScreen.Choice.NEW)
	title.choose(TitleScreen.Choice.CONFIRM_NEW)
	assert_false(game.save_slot.load_adventure().has_flag(&"forest_shrine_awakened"), "replaced on purpose")


func test_an_unreadable_save_is_reported_and_still_protected() -> void:
	_write_save("{ \"version\": 1, \"area\": ")
	await _launch()
	assert_eq(title.choices, [TitleScreen.Choice.NEW, TitleScreen.Choice.LANGUAGE, TitleScreen.Choice.QUIT])
	assert_eq((title.get_node(^"%Notice") as Label).text, "SAVE_UNREADABLE")
	title.choose(TitleScreen.Choice.NEW)
	assert_true(title.is_open(), "replacing even an unreadable save needs confirmation")


func test_messages_are_paged_and_wait_for_the_reader() -> void:
	await _launch()
	watch_signals(hud)
	hud.show_message("Primeira página.\n\nSegunda página.", "Seu Anselmo")
	assert_signal_emit_count(hud, "dialogue_started", 1)
	assert_eq((hud.get_node(^"%Speaker") as Label).text, "Seu Anselmo")
	hud.advance()
	assert_eq((hud.get_node(^"%Message") as Label).visible_characters, -1, "first press finishes typing")
	assert_true((hud.get_node(^"%NextArrow") as Control).visible)
	hud.advance()
	assert_eq((hud.get_node(^"%Message") as Label).text, "Segunda página.")
	hud.advance()
	hud.advance()
	assert_false(hud.is_message_visible())
	assert_signal_emit_count(hud, "dialogue_finished", 1)
