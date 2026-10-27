extends GutTest
## Shared steps for tests that play the adventure on the real game scene: a game with its own
## save folder (named after the test script), travelling, talking, awakening the shrine and
## falling. Not a test script itself (no "test_" prefix).

const GameScene := preload("res://game/game.tscn")
const WaitFor := preload("res://tests/support/wait_for.gd")

var game: Game


func before_each() -> void:
	var dir := ProjectSettings.globalize_path(save_dir())
	DirAccess.make_dir_recursive_absolute(dir)
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	game = _launch()


func after_each() -> void:
	Input.action_release(&"attack")


func save_dir() -> String:
	return "user://test_saves".path_join((get_script() as Script).resource_path.get_file().get_basename())


## A game process, as far as the scene goes: same save file, no title.
func _launch() -> Game:
	var launched: Game = GameScene.instantiate()
	launched.save_path = save_dir().path_join("save.json")
	launched.show_title = false
	add_child_autofree(launched)
	return launched


## Ends this game and starts a new one on the same save, like closing and reopening it.
func _restart() -> void:
	game.queue_free()
	await wait_physics_frames(2)
	game = _launch()


func _player() -> Player:
	return game.level.player


func _settle() -> void:
	for i in 180:
		if not game.is_travelling():
			break
		await wait_physics_frames(1)
	await wait_physics_frames(3)


## Walks the hero into the area's passage and waits for the trip to finish.
func _take_exit(exit_name: String) -> void:
	var exit: AreaExit = game.level.get_node(exit_name)
	_player().global_position = exit.global_position + Vector2(0, 4)
	await wait_physics_frames(3)
	await _settle()


func _awaken_shrine() -> Shrine:
	var shrine: Shrine = game.level.get_node(^"Entities/Shrine")
	_player().global_position = shrine.global_position + Vector2(0, 14)
	await wait_physics_frames(3)
	assert_true(_player().interactor.interact(_player()), "the shrine is within reach")
	game.get_node(^"HUD").call(&"_close_box")
	game.get_node(^"HUD").emit_signal(&"dialogue_finished")
	await wait_physics_frames(3)
	return shrine


## Talks to a villager until the dialogue closes; returns the key of what they said.
func _talk(npc_name: String) -> String:
	var npc: Npc = game.level.get_node("Entities/" + npc_name)
	var said := [""]
	var listen := func(_target: Interactable, message: String) -> void: said[0] = message
	_player().interactor.interacted.connect(listen)
	_player().global_position = npc.global_position + Vector2(0, 14)
	await wait_physics_frames(3)
	_player().interactor.interact(_player())
	_player().interactor.interacted.disconnect(listen)
	var hud: Hud = game.get_node(^"HUD")
	while hud.is_message_visible():
		hud.advance()
	await wait_physics_frames(3)
	return said[0]


## The hero falls where they stand and the player picks "try again".
func _fall_and_retry() -> void:
	_player().health.take_damage(999)
	# Not wait_for_signal(): the fallen hero is freed by the respawn (see WaitFor).
	await WaitFor.signal_or_timeout(get_tree(), _player().died, 4.0)
	game.respawn()
	await _settle()


func _assert_at_entry(area: StringName, entry: StringName) -> void:
	assert_eq(game.level.area_id, area)
	assert_almost_eq(_player().global_position, game.level.entry(entry).global_position, Vector2.ONE,
			"at %s/%s" % [area, entry])
