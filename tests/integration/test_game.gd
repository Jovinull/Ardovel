extends GutTest
## The assembled game scene: HUD wiring, death screen, the restart request and hit-stop.

const GameScene := preload("res://game/game.tscn")

var game: Game
var player: Player
var hud: Hud
var death_screen: DeathScreen


func before_each() -> void:
	game = GameScene.instantiate()
	game.show_title = false
	add_child_autofree(game)
	game.start_new()
	await wait_physics_frames(2)
	player = game.level.player
	hud = game.get_node(^"HUD")
	death_screen = game.get_node(^"DeathScreen")


func _hearts() -> Array[int]:
	var quarters: Array[int] = []
	for i in 3:
		quarters.append(hud.heart_quarters(i))
	return quarters


func _press_pause() -> PauseScreen:
	var event := InputEventAction.new()
	event.action = &"pause"
	event.pressed = true
	game.call(&"_unhandled_input", event)
	return game.get_node(^"PauseScreen") as PauseScreen


func test_hud_starts_with_three_full_hearts() -> void:
	assert_eq(_hearts(), [4, 4, 4])


func test_hud_shows_damage_in_quarters() -> void:
	player.health.invulnerability_time = 0.0
	player.health.take_damage(3)
	assert_eq(_hearts(), [4, 4, 1])
	player.health.take_damage(5)
	assert_eq(_hearts(), [4, 0, 0])


func test_interaction_messages_reach_the_hud() -> void:
	player.interactor.interacted.emit(null, "Teste")
	assert_true(hud.is_message_visible())
	player.interactor.interacted.emit(null, "")
	assert_true(hud.is_message_visible(), "empty messages do not replace the current one")


func test_pause_shows_controls_and_resumes_the_world() -> void:
	var pause := _press_pause()
	assert_true(pause.is_open())
	assert_true(get_tree().paused)
	pause.choose(PauseScreen.Choice.CONTROLS)
	assert_true(pause.is_showing_controls())
	assert_true((pause.get_node(^"%Controls") as Label).visible)
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	pause.call(&"_unhandled_input", cancel)
	assert_false(pause.is_showing_controls(), "cancel returns to the pause menu")
	pause.choose(PauseScreen.Choice.RESUME)
	assert_false(pause.is_open())
	assert_false(get_tree().paused)


func test_pause_does_not_interrupt_dialogue() -> void:
	hud.show_message("A short test message.")
	_press_pause()
	assert_false((game.get_node(^"PauseScreen") as PauseScreen).is_open())


func test_pause_menu_responds_to_keyboard_inputs() -> void:
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	game.call(&"_unhandled_input", escape)
	var pause := game.get_node(^"PauseScreen") as PauseScreen
	assert_true(pause.is_open())
	var down := InputEventKey.new()
	down.physical_keycode = KEY_S
	down.pressed = true
	pause.call(&"_unhandled_input", down)
	assert_eq(pause.get(&"_selected"), 1)
	var confirm := InputEventKey.new()
	confirm.physical_keycode = KEY_E
	confirm.pressed = true
	pause.call(&"_unhandled_input", confirm)
	assert_true(pause.is_showing_controls())
	pause.call(&"_unhandled_input", escape)
	assert_false(pause.is_showing_controls())
	pause.call(&"_unhandled_input", escape)
	assert_false(pause.is_open())
	assert_false(get_tree().paused)


func test_pause_menu_responds_to_joypad_inputs() -> void:
	var open := InputEventJoypadButton.new()
	open.button_index = JOY_BUTTON_START
	open.pressed = true
	game.call(&"_input", open)
	game.call(&"_unhandled_input", open)
	var pause := game.get_node(^"PauseScreen") as PauseScreen
	assert_true(pause.is_open())
	var down := InputEventJoypadButton.new()
	down.button_index = JOY_BUTTON_DPAD_DOWN
	down.pressed = true
	pause.call(&"_unhandled_input", down)
	assert_eq(pause.get(&"_selected"), 1)
	var confirm := InputEventJoypadButton.new()
	confirm.button_index = JOY_BUTTON_A
	confirm.pressed = true
	pause.call(&"_unhandled_input", confirm)
	assert_true(pause.is_showing_controls())
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	back.pressed = true
	pause.call(&"_unhandled_input", back)
	assert_false(pause.is_showing_controls())
	pause.call(&"_unhandled_input", back)
	assert_false(pause.is_open())
	assert_false(get_tree().paused)


func test_pause_and_cancel_have_separate_gamepad_bindings() -> void:
	var start := InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	assert_true(start.is_action(&"pause"))
	assert_false(start.is_action(&"ui_cancel"))
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	assert_true(back.is_action(&"ui_cancel"))
	assert_false(back.is_action(&"pause"))


func test_start_toggles_the_open_pause_menu() -> void:
	var pause := _press_pause()
	var start := InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	start.pressed = true
	pause.call(&"_unhandled_input", start)
	assert_false(pause.is_open())
	assert_false(get_tree().paused)


func test_keyboard_prompts_follow_the_input_map() -> void:
	var original_events := InputMap.action_get_events(&"interact")
	for event in original_events:
		InputMap.action_erase_event(&"interact", event)
	var custom_key := InputEventKey.new()
	custom_key.physical_keycode = KEY_Q
	InputMap.action_add_event(&"interact", custom_key)
	assert_eq(InputPrompts.dismiss_label(false, ""), OS.get_keycode_string(KEY_Q))
	for event in original_events:
		InputMap.action_add_event(&"interact", event)


func test_input_mode_switches_between_keyboard_and_gamepad() -> void:
	var guidance: Label = hud.get_node(^"%Guidance")
	var title: TitleScreen = game.get_node(^"TitleScreen")
	var death: DeathScreen = game.get_node(^"DeathScreen")
	var pause: PauseScreen = game.get_node(^"PauseScreen")
	var pad := InputEventJoypadButton.new()
	pad.device = 0
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	game.call(&"_input", pad)
	var joypad_name := String(game.get(&"_joypad_name"))
	assert_true(pause.get(&"_gamepad_active"))
	assert_true(guidance.text.contains(InputPrompts.dismiss_label(true, joypad_name)))
	assert_eq((title.get_node(^"%InputHint") as Label).text,
		InputPrompts.title_hint(true, joypad_name))
	assert_true((death.get_node(^"%Prompt") as Label).visible)
	pause.open()
	pause.choose(PauseScreen.Choice.CONTROLS)
	assert_eq((pause.get_node(^"%Controls") as Label).text,
		InputPrompts.controls_text(true, joypad_name))
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	game.call(&"_input", key)
	assert_false(pause.get(&"_gamepad_active"))
	assert_true(guidance.text.contains(InputPrompts.dismiss_label(false, "")))
	assert_eq((title.get_node(^"%InputHint") as Label).text,
		InputPrompts.title_hint(false, ""))
	assert_false((death.get_node(^"%Prompt") as Label).visible)
	assert_eq((pause.get_node(^"%Controls") as Label).text,
		InputPrompts.controls_text(false, ""))


func test_connecting_a_gamepad_switches_the_prompts() -> void:
	game.call(&"_set_keyboard_active")
	game.call(&"_on_joy_connection_changed", 17, true)
	var title: TitleScreen = game.get_node(^"TitleScreen")
	assert_true(game.get(&"_gamepad_active"))
	assert_eq(game.get(&"_active_joypad"), 17)
	assert_eq((title.get_node(^"%InputHint") as Label).text,
		InputPrompts.title_hint(true, String(game.get(&"_joypad_name"))))


func test_return_to_title_saves_and_continues_the_adventure() -> void:
	game.adventure.set_flag(&"pause_return_test")
	player.health.current = 6
	var pause := _press_pause()
	pause.choose(PauseScreen.Choice.TITLE)
	assert_false(get_tree().paused)
	assert_false(pause.is_open())
	assert_null(game.level, "the old area is removed from the title screen")
	assert_true((game.get_node(^"TitleScreen") as TitleScreen).is_open())
	var saved := game.save_slot.load_adventure()
	assert_eq(saved.health, 6)
	assert_true(saved.has_flag(&"pause_return_test"))
	await wait_process_frames(2)
	(game.get_node(^"TitleScreen") as TitleScreen).choose(TitleScreen.Choice.CONTINUE)
	await wait_process_frames(2)
	assert_eq(game.level.area_id, &"village")
	assert_eq(game.level.player.health.current, 6)
	assert_true(game.adventure.has_flag(&"pause_return_test"))


func test_pause_stays_open_if_saving_before_return_fails() -> void:
	var temporary_path := ProjectSettings.globalize_path(game.save_slot.path + ".tmp")
	assert_eq(DirAccess.make_dir_recursive_absolute(temporary_path), OK)
	var pause := _press_pause()
	pause.choose(PauseScreen.Choice.TITLE)
	assert_true(pause.is_open())
	assert_true(get_tree().paused)
	assert_not_null(game.level)
	assert_eq((pause.get_node(^"%Notice") as Label).text, "PAUSE_SAVE_FAILED")
	pause.choose(PauseScreen.Choice.RESUME)
	assert_eq(DirAccess.remove_absolute(temporary_path), OK)


func test_language_change_updates_the_open_pause_menu() -> void:
	var pause := _press_pause()
	pause.choose(PauseScreen.Choice.LANGUAGE)
	assert_eq(TranslationServer.get_locale(), "en")
	var language_index := pause.choices.find(PauseScreen.Choice.LANGUAGE)
	assert_eq((pause.get_node(^"%Options").get_child(language_index) as Label).text, "Language: English")
	pause.choose(PauseScreen.Choice.CONTROLS)
	assert_true((pause.get_node(^"%Controls") as Label).text.begins_with("Move:"))
	game.switch_language()
	assert_eq(TranslationServer.get_locale(), "pt_BR")
	assert_true((pause.get_node(^"%Controls") as Label).text.begins_with("Mover:"))
	pause.choose(PauseScreen.Choice.BACK)
	pause.choose(PauseScreen.Choice.RESUME)


func test_death_opens_the_death_screen() -> void:
	assert_false(death_screen.is_open())
	player.health.take_damage(999)
	await wait_for_signal(player.died, 4.0)
	assert_true(death_screen.is_open())


func test_restart_action_requests_a_restart_only_when_open() -> void:
	assert_true(death_screen.restart_requested.is_connected(game.respawn), "wired to the game's respawn")
	death_screen.restart_requested.disconnect(game.respawn)  # only the request is under test here
	watch_signals(death_screen)
	var press := InputEventAction.new()
	press.action = &"restart"
	press.pressed = true
	var release := InputEventAction.new()
	release.action = &"restart"
	# Each event object is sent once: Godot rejects parsing the same one twice in a frame.
	Input.parse_input_event(press.duplicate())
	await wait_process_frames(2)
	Input.parse_input_event(release.duplicate())
	await wait_process_frames(2)
	assert_signal_not_emitted(death_screen, "restart_requested")
	death_screen.open()
	Input.parse_input_event(press.duplicate())
	await wait_process_frames(2)
	assert_signal_emitted(death_screen, "restart_requested")
	Input.parse_input_event(release.duplicate())


func test_sword_hit_freezes_the_world_briefly() -> void:
	player.hit_landed.emit()
	assert_eq(Engine.time_scale, 0.0)
	await get_tree().create_timer(0.15, true, false, true).timeout
	assert_eq(Engine.time_scale, 1.0)


func test_a_second_hit_extends_the_freeze() -> void:
	# Long freezes so a slow frame cannot blur the windows: first ends at 0.3, second at 0.5.
	game.hit_stop_time = 0.3
	player.hit_landed.emit()
	await get_tree().create_timer(0.2, true, false, true).timeout
	player.hit_landed.emit()
	await get_tree().create_timer(0.2, true, false, true).timeout
	assert_eq(Engine.time_scale, 0.0, "the first freeze must not release the second")
	await get_tree().create_timer(0.3, true, false, true).timeout
	assert_eq(Engine.time_scale, 1.0)


func test_leaving_the_game_never_leaves_time_frozen() -> void:
	player.hit_landed.emit()
	remove_child(game)
	assert_eq(Engine.time_scale, 1.0)
	add_child(game)
