extends "res://tests/integration/adventure_case.gd"
## The first ruin end to end: getting in from the forest, its two puzzles, the secrets, the
## warden, the heart as the new checkpoint and what the village shows afterwards. Every state
## that matters is checked again after the area is loaded anew.


## Starts in the forest with the shrine awake (the ruin's door is open), as a save would.
func _start_at_the_ruin_door() -> void:
	var adventure := Adventure.new(&"forest", &"ruin")
	adventure.set_flag(&"forest_shrine_awakened")
	adventure.checkpoint_area = &"forest"
	adventure.checkpoint_entry = &"shrine"
	game.save_slot.save(adventure)
	assert_true(game.continue_saved())
	await _settle()


func _enter_ruin() -> void:
	await _start_at_the_ruin_door()
	await _take_exit("Entities/RuinEntrance/ToRuin")
	_assert_at_entry(&"ruin", &"gate")


func _node(path: String) -> Node:
	return game.level.get_node(path)


func _strike(target: Node) -> void:
	(target.get_node(^"Hurtbox") as Hurtbox).receive_hit(Hit.new(1, 0.0, (target as Node2D).global_position))


## Leaves and comes back through the same door, so every object is built again from the save.
func _reload_area() -> void:
	game.travel(game.adventure.area, game.adventure.entry)
	await _settle()


func test_the_door_stays_rooted_until_the_forest_shrine_wakes() -> void:
	game.start_new()
	await _settle()
	await _take_exit("ToForest")
	var roots: RootSeal = _node("Entities/RuinEntrance/Roots")
	assert_false(roots.is_open(), "closed before the shrine")
	await _awaken_shrine()
	assert_true(roots.is_open(), "the shrine's light opens it at once")


func test_into_the_ruin_and_back_out() -> void:
	await _enter_ruin()
	assert_eq(game.save_slot.load_adventure().area, &"ruin")
	await _take_exit("ToForest")
	_assert_at_entry(&"forest", &"ruin")


func test_the_light_puzzle_asks_for_the_guardians_pattern() -> void:
	await _enter_ruin()
	var puzzle: LightsPuzzle = _node("LightsPuzzle")
	var answer: Array[bool] = []
	for i in 4:
		answer.append((_node("Entities/Guardian%d" % (i + 1)) as RuinGuardian).holds_orb)
	assert_eq(puzzle.pattern(), answer, "the answer is what the hall shows")
	assert_true(answer.has(true) and answer.has(false), "not all alike: there is something to notice")
	var seal: RootSeal = _node("Entities/LightsRoots")
	for i in 4:                                            # all lit: not the answer
		_strike(_node("Entities/Orb%d" % (i + 1)))
	assert_false(puzzle.is_solved())
	assert_false(seal.is_open())
	for i in 4:                                            # put out the ones the guardians lack
		if not answer[i]:
			_strike(_node("Entities/Orb%d" % (i + 1)))
	assert_true(puzzle.is_solved())
	await wait_physics_frames(2)
	assert_true(seal.is_open())
	assert_true(game.adventure.has_flag(&"ruin_lights_solved"))
	_strike(_node("Entities/Orb1"))
	assert_eq((_node("Entities/Orb1") as LightPedestal).lit, answer[0], "solved orbs stay as they are")
	await _reload_area()
	assert_true((_node("Entities/LightsRoots") as RootSeal).is_open(), "still open after loading again")
	for i in 4:
		assert_eq((_node("Entities/Orb%d" % (i + 1)) as LightPedestal).lit, answer[i])


func test_the_plate_holds_the_roots_only_while_weighed_down() -> void:
	await _enter_ruin()
	var plate: PressurePlate = _node("FloorDecor/Plate")
	var seal: RootSeal = _node("Entities/PlateRoots")
	_player().global_position = plate.global_position
	await wait_physics_frames(3)
	assert_true(plate.is_pressed())
	assert_true(seal.is_open(), "standing on it shows what it does")
	_player().global_position = plate.global_position + Vector2(0, 40)
	await wait_physics_frames(3)
	assert_false(seal.is_open(), "closes when the hero steps off")
	assert_false(game.adventure.has_flag(&"ruin_roots_solved"))


func test_the_block_takes_the_heros_place_on_the_plate() -> void:
	await _enter_ruin()
	var plate: PressurePlate = _node("FloorDecor/Plate")
	var block: PushBlock = _node("Entities/Block")
	var steps := (plate.position - block.position) / PushBlock.TILE
	for i in int(steps.x):
		assert_true(await block.try_slide(Vector2.RIGHT))
	for i in int(-steps.y):
		assert_true(await block.try_slide(Vector2.UP))
	await wait_physics_frames(4)
	assert_true(game.adventure.has_flag(&"ruin_roots_solved"))
	assert_true((_node("Entities/PlateRoots") as RootSeal).is_open())
	assert_false(await block.try_slide(Vector2.LEFT), "a solved block stays put")
	var plate_at := plate.position
	await _reload_area()
	assert_almost_eq((_node("Entities/Block") as Node2D).position, plate_at, Vector2.ONE)
	assert_true((_node("Entities/PlateRoots") as RootSeal).is_open())


func test_the_hero_pushes_the_block_by_leaning_on_it() -> void:
	await _enter_ruin()
	var block: PushBlock = _node("Entities/Block")
	var start := block.position
	_player().global_position = block.global_position + Vector2(-14, 6)    # on the block's ground line
	await wait_physics_frames(2)
	Input.action_press(&"move_right")
	await wait_seconds(0.8)
	Input.action_release(&"move_right")
	await wait_physics_frames(4)
	assert_almost_eq(block.position, start + Vector2(PushBlock.TILE, 0), Vector2.ONE, "one tile after a moment")


func test_a_block_never_goes_through_a_wall_and_comes_back_when_the_hero_leaves() -> void:
	await _enter_ruin()
	var block: PushBlock = _node("Entities/Block")
	var start := block.position
	var moved := 0
	while await block.try_slide(Vector2.LEFT):
		moved += 1
	assert_lt(moved, 10, "stopped by the west wall")
	assert_gt(block.position.x, 16.0, "still inside the room")
	_player().global_position = block.global_position + Vector2(40, 0)    # in the room...
	await wait_physics_frames(3)
	_player().global_position = Vector2(160, 480)                          # ...then out of it
	await wait_physics_frames(3)
	assert_almost_eq(block.position, start, Vector2.ONE, "back where it started")


func test_the_thin_roots_are_cut_for_good() -> void:
	await _enter_ruin()
	var roots: ThinRoots = _node("Entities/ThinRoots")
	_strike(roots)
	assert_true(roots.is_cut())
	await wait_physics_frames(3)
	assert_true((roots.get_node(^"Collision") as CollisionShape2D).disabled)
	await _reload_area()
	roots = _node("Entities/ThinRoots")
	assert_true(roots.is_cut(), "stubs only, after loading again")
	assert_true((roots.get_node(^"Collision") as CollisionShape2D).disabled)


func test_the_crystal_heart_adds_a_heart_once() -> void:
	await _enter_ruin()
	var base := _player().health.max_health
	var vessel: HeartVessel = _node("Entities/HeartVessel")
	_player().health.invulnerability_time = 0.0
	_player().health.take_damage(3)
	assert_eq((vessel.get_node(^"Interactable") as Interactable).interact(_player()), "HEART_VESSEL_FOUND")
	assert_eq(_player().health.max_health, base + Game.HEART_VESSEL_HEALTH)
	assert_eq(_player().health.current, _player().health.max_health, "and heals fully")
	assert_eq((vessel.get_node(^"Interactable") as Interactable).interact(_player()), "", "only once")
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(_player().health.max_health, base + Game.HEART_VESSEL_HEALTH, "kept across a restart")
	assert_null(game.level.get_node_or_null("Entities/HeartVessel"))


## Puts the hero in the warden's hall, past the door.
func _walk_into_the_hall() -> RootWarden:
	var warden: RootWarden = _node("Entities/RootWarden")
	_player().global_position = warden.global_position + Vector2(0, 50)
	await wait_physics_frames(3)
	return warden


func test_the_fight_locks_the_hall_and_shows_the_warden() -> void:
	await _enter_ruin()
	var warden := await _walk_into_the_hall()
	assert_ne(warden.state, RootWarden.State.DORMANT)
	assert_false((_node("Entities/ArenaRoots") as RootSeal).is_open(), "no way back mid-fight")
	var hud: Hud = game.get_node(^"HUD")
	assert_true(hud.is_boss_bar_visible())
	assert_eq(game.get_node(^"Music").get(&"stream"), (_node("BossArena") as BossArena).music)


func test_the_warden_only_hurts_when_its_core_is_bare() -> void:
	await _enter_ruin()
	var warden := await _walk_into_the_hall()
	_strike(warden)
	assert_eq(warden.health.current, warden.health.max_health, "stone everywhere else: a clank")
	warden.call(&"_enter", RootWarden.State.STUCK)
	assert_true(warden.is_vulnerable())
	_strike(warden)
	assert_eq(warden.health.current, warden.health.max_health - 1)
	assert_lt((game.get_node(^"HUD") as Hud).boss_bar_fraction(), 1.0)


func test_the_slam_is_announced_and_hurts_up_close() -> void:
	await _enter_ruin()
	var warden := await _walk_into_the_hall()
	_player().global_position = warden.global_position + Vector2(0, 24)
	var hp := _player().health.current
	await wait_physics_frames(4)
	assert_eq(warden.state, RootWarden.State.WINDUP, "fists up first")
	assert_eq(_player().health.current, hp, "the warning does no harm")
	await wait_seconds(warden.windup_time + 0.1)
	assert_lt(_player().health.current, hp, "the slam lands on whoever stayed")


func test_from_afar_roots_burst_under_the_hero_after_a_warning() -> void:
	await _enter_ruin()
	var warden := await _walk_into_the_hall()
	_player().global_position = warden.global_position + Vector2(120, 60)
	await wait_seconds(warden.idle_time + 0.2)
	var spikes := game.level.find_children("*", "Node2D", true, false).filter(
			func(n: Node) -> bool: return n is RootSpike)
	assert_gt(spikes.size(), 0, "roots are coming")
	var hp := _player().health.current
	_player().global_position += Vector2(-60, 0)
	await wait_seconds(warden.spike_warning_time + 0.4)
	assert_eq(_player().health.current, hp, "stepping away from the cracks is enough")


func test_at_half_health_the_warden_quickens() -> void:
	await _enter_ruin()
	var warden := await _walk_into_the_hall()
	assert_false(warden.is_enraged())
	warden.call(&"_enter", RootWarden.State.STUCK)
	for i in warden.health.max_health / 2:
		_strike(warden)
	assert_true(warden.is_enraged())


func _beat_the_warden(warden: RootWarden) -> void:
	while warden.health.current > 0:
		warden.call(&"_enter", RootWarden.State.STUCK)
		_strike(warden)
	await WaitFor.signal_or_timeout(get_tree(), warden.defeated, 3.0)  # the warden is freed after
	await wait_physics_frames(3)


func test_beating_the_warden_opens_the_way_once_and_for_all() -> void:
	await _enter_ruin()
	var warden := await _walk_into_the_hall()
	await _beat_the_warden(warden)
	assert_true(game.adventure.has_flag(&"ruin_warden_defeated"))
	assert_false(is_instance_valid(warden))
	for seal_name in ["ArenaRoots", "HeartRoots", "ShortcutRoots"]:
		assert_true((_node("Entities/" + seal_name) as RootSeal).is_open(), seal_name)
	assert_false((game.get_node(^"HUD") as Hud).is_boss_bar_visible())
	await _reload_area()
	assert_null(game.level.get_node_or_null("Entities/RootWarden"), "it does not come back")
	assert_false((_node("BossArena") as BossArena).is_fighting())


func test_falling_mid_fight_resets_the_fight_and_keeps_the_way_open() -> void:
	await _enter_ruin()
	await _walk_into_the_hall()
	await _fall_and_retry()
	_assert_at_entry(&"forest", &"shrine")
	assert_false(game.adventure.has_flag(&"ruin_warden_defeated"))
	assert_false((game.get_node(^"HUD") as Hud).is_boss_bar_visible())
	await _take_exit("Entities/RuinEntrance/ToRuin")
	var warden: RootWarden = _node("Entities/RootWarden")
	assert_eq(warden.state, RootWarden.State.DORMANT)
	assert_eq(warden.health.current, warden.health.max_health, "whole again")
	assert_true((_node("Entities/ArenaRoots") as RootSeal).is_open(), "the hall can be entered")


func test_the_heart_wakes_only_after_the_warden_and_becomes_the_checkpoint() -> void:
	await _enter_ruin()
	var heart: Shrine = _node("Entities/RootHeart")
	var interactable: Interactable = heart.get_node(^"Interactable")
	assert_eq(interactable.interact(_player()), "HEART_DORMANT")
	assert_eq(game.adventure.checkpoint_area, &"forest", "nothing changes while it sleeps")
	await _fall_and_retry()
	_assert_at_entry(&"forest", &"shrine")
	await _take_exit("Entities/RuinEntrance/ToRuin")
	await _beat_the_warden(await _walk_into_the_hall())
	heart = _node("Entities/RootHeart")
	assert_eq((heart.get_node(^"Interactable") as Interactable).interact(_player()), "HEART_AWAKEN")
	assert_eq([game.adventure.checkpoint_area, game.adventure.checkpoint_entry], [&"ruin", &"heart"])
	await _take_exit("ToForest")
	await _take_exit("ToVillage")
	await _fall_and_retry()
	_assert_at_entry(&"ruin", &"heart")


func test_the_mural_can_only_be_read_in_the_heart_light() -> void:
	await _enter_ruin()
	var mural: Mural = _node("Entities/Mural")
	var interactable: Interactable = mural.get_node(^"Interactable")
	assert_eq(interactable.interact(_player()), "MURAL_DARK")
	game.adventure.set_flag(&"ruin_heart_awakened")
	assert_eq((mural.get_node(^"Sprite") as Sprite2D).region_rect, Mural.LIT, "the cuts glow at once")
	assert_eq(interactable.interact(_player()), "MURAL_READ")
	assert_true(game.adventure.has_flag(&"ruin_mural_read"))


func test_the_village_sees_the_light_and_talks_about_it() -> void:
	var adventure := Adventure.new(&"village", &"north")
	for flag in [&"forest_shrine_awakened", &"village_statue_seen_restored", &"elder_thanked",
			&"ruin_warden_defeated", &"ruin_heart_awakened", &"ruin_mural_read"]:
		adventure.set_flag(flag)
	game.save_slot.save(adventure)
	assert_true(game.continue_saved())
	await _settle()
	var statue: GuardianStatue = _node("Entities/GuardianStatue")
	assert_true(statue.calling)
	assert_true((statue.get_node(^"Beacon") as CanvasItem).visible, "a column of light over the square")
	assert_eq((statue.get_node(^"Interactable") as Interactable).interact(_player()), "STATUE_CALLING")
	assert_eq(await _talk("Anselmo"), "ANSELMO_RUIN")
	assert_eq(await _talk("Lia"), "LIA_MURAL", "she has read what the hero read")
	assert_eq(await _talk("Cida"), "CIDA_RUIN")


func test_before_the_ruin_the_statue_has_no_beacon() -> void:
	game.start_new()
	await _settle()
	assert_false((_node("Entities/GuardianStatue/Beacon") as CanvasItem).visible)


func test_a_stuck_warden_can_be_struck_from_in_front_without_getting_hurt() -> void:
	# Found in play: the counter-attack window must not punish whoever takes it.
	await _enter_ruin()
	var warden := await _walk_into_the_hall()
	warden.call(&"_enter", RootWarden.State.STUCK)
	_player().global_position = warden.global_position + Vector2(0, 18)
	_player().face(Vector2.UP)
	var hp := _player().health.current
	await wait_physics_frames(6)
	assert_eq(_player().health.current, hp, "touching it while stuck does no harm")
	Input.action_press(&"attack")
	await wait_physics_frames(2)
	Input.action_release(&"attack")
	await wait_seconds(0.3)
	assert_eq(warden.health.current, warden.health.max_health - 1, "a real swing reaches the core")


func test_a_fall_after_the_crystal_heart_brings_the_hero_back_with_every_heart_full() -> void:
	# Found in play: full health meant the scene's maximum, before the crystal heart was added.
	await _enter_ruin()
	(_node("Entities/HeartVessel/Interactable") as Interactable).interact(_player())
	await _fall_and_retry()
	assert_eq(_player().health.max_health, 12 + Game.HEART_VESSEL_HEALTH)
	assert_eq(_player().health.current, _player().health.max_health)


func test_a_slam_decided_from_the_side_lands_there() -> void:
	# Found in play: the slam was decided at 46px but only reached 30px, leaving a safe spot.
	await _enter_ruin()
	var warden := await _walk_into_the_hall()
	var reach := ((warden.get_node(^"SlamHitbox/Shape") as CollisionShape2D).shape as CircleShape2D).radius
	assert_eq(reach, warden.slam_range, "what triggers a slam is what it reaches")
	_player().global_position = warden.global_position + Vector2(warden.slam_range - 4, 0)
	var hp := _player().health.current
	await wait_physics_frames(3)
	assert_eq(warden.state, RootWarden.State.WINDUP)
	await wait_seconds(warden.windup_time + 0.1)
	assert_lt(_player().health.current, hp)


func test_after_every_slam_roots_come_even_up_close() -> void:
	# Found in play: fighting up close, the root spikes almost never came.
	await _enter_ruin()
	var warden := await _walk_into_the_hall()
	warden.call(&"_enter", RootWarden.State.STUCK)
	_player().global_position = warden.global_position + Vector2(0, 26)
	await wait_seconds(warden.stuck_time + warden.idle_time + 0.2)
	assert_eq(warden.state, RootWarden.State.CAST, "the roots, not another slam")
	var spikes := game.level.find_children("*", "Node2D", true, false).filter(
			func(n: Node) -> bool: return n is RootSpike)
	assert_gt(spikes.size(), 0)
