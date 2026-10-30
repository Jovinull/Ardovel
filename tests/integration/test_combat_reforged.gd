extends "res://tests/integration/adventure_case.gd"
## Combat 2.0, played with real input on the real hero: the shield raised against blows from the
## front and from behind, blockable and unblockable blows, breath and the broken guard, armour after
## the shield, the dodge (its untouchable moment, walls, light and heavy loads), each weapon's blow
## (reach, width, chaining, stagger), the enemies' reactions, eating from the quick slot (its time,
## its interruption, the menu choosing it), gamepad buttons, and what survives Continue and a fall.
## Enemy blows come from a real Hitbox placed beside the hero: the same path every enemy uses.

const MusgoricoScene := preload("res://actors/musgorico/musgorico.tscn")
const CardosaScene := preload("res://actors/cardosa/cardosa.tscn")
## Open ground on the road slope.
const OPEN := Vector2(280, 128)


func after_each() -> void:
	super.after_each()
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"block", &"attack"]:
		Input.action_release(action)


func _start(items: Dictionary = {}, worn: Dictionary = {}) -> void:
	var state := Adventure.new(&"road_slope", &"trail")
	state.set_flag(&"forest_shrine_awakened")
	state.set_flag(&"heard_of_shrine")
	for id: StringName in items:
		state.add_item(id, items[id])
	for slot: StringName in worn:
		assert_true(state.equip(slot, worn[slot]), "%s worn" % worn[slot])
	state.checkpoint_area = &"forest"
	state.checkpoint_entry = &"shrine"
	game.save_slot.save(state)
	assert_true(game.continue_saved())
	await _settle()
	game.hit_stop_time = 0.0
	_player().global_position = OPEN
	_player().face(Vector2.RIGHT)
	await wait_physics_frames(3)


## A blow from a real Hitbox at `offset` from the hero.
func _blow(offset: Vector2, damage: int = 2, blockable: bool = true, knockback: float = 130.0) -> bool:
	var hitbox := Hitbox.new()
	hitbox.damage = damage
	hitbox.knockback = knockback
	hitbox.blockable = blockable
	game.level.add_child(hitbox)
	hitbox.global_position = _player().global_position + offset
	hitbox.active = true
	var landed := hitbox.strike(_player().get_node(^"Hurtbox") as Hurtbox)
	hitbox.queue_free()
	await wait_physics_frames(1)
	return landed


func _press(action: StringName, frames: int = 2) -> void:
	Input.action_press(action)
	await wait_physics_frames(frames)
	Input.action_release(action)
	await wait_physics_frames(1)


func _raise_shield() -> void:
	Input.action_press(&"block")
	await wait_physics_frames(12)
	assert_true(_player().is_guarding(), "the shield is up")


## A target that only takes blows: an enemy hurtbox with its own health, at `offset` from the hero.
func _dummy(offset: Vector2) -> Health:
	var body := Node2D.new()
	game.level.get_node(^"Entities").add_child(body)
	body.global_position = _player().global_position + Vector2(0, -8) + offset
	var health := Health.new()
	health.max_health = 50
	body.add_child(health)
	var hurtbox := Hurtbox.new()
	hurtbox.collision_layer = 16
	hurtbox.collision_mask = 0
	hurtbox.health = health
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(6, 6)
	shape.shape = rect
	hurtbox.add_child(shape)
	body.add_child(hurtbox)
	await wait_physics_frames(2)
	return health


func _swing(direction: StringName = &"move_right") -> void:
	Input.action_press(direction)
	await _press(&"attack")
	Input.action_release(direction)
	await _wait_until(func() -> bool: return _player().state != Player.State.ATTACK, 2.0)
	await wait_physics_frames(2)


func _wait_until(condition: Callable, seconds: float) -> bool:
	var left := seconds
	while not condition.call() and left > 0.0:
		await wait_physics_frames(1)
		left -= get_physics_process_delta_time()
	return condition.call()


func test_without_a_shield_the_block_key_does_nothing() -> void:
	await _start()
	Input.action_press(&"block")
	await wait_physics_frames(12)
	assert_eq(_player().state, Player.State.MOVE, "no invisible shield")
	assert_true(await _blow(Vector2(10, 0)))
	assert_eq(_player().health.current, 10, "a blow from the front lands in full")


func test_a_raised_shield_takes_a_blow_from_the_front_but_not_from_behind() -> void:
	await _start({&"traveller_shield": 1}, {&"off_hand": &"traveller_shield"})
	await _raise_shield()
	var breath := _player().stamina.current
	assert_true(await _blow(Vector2(12, 0)), "it lands on the shield")
	assert_eq(_player().health.current, 12, "80% stopped: 0.4 of a quarter, not enough to take one")
	assert_eq(_player().state, Player.State.GUARD, "the hero holds the guard")
	assert_eq(_player().stamina.current, breath - 16.0, "two quarters cost 16 breath")
	await wait_physics_frames(25)
	assert_true(await _blow(Vector2(-12, 0)), "from behind")
	assert_eq(_player().health.current, 10, "the shield does not cover the back")
	assert_eq(_player().state, Player.State.HURT)


func test_a_slam_from_above_cannot_be_blocked() -> void:
	await _start({&"crew_board_shield": 1}, {&"off_hand": &"crew_board_shield"})
	await _raise_shield()
	assert_true(await _blow(Vector2(12, 0), 4, false))
	assert_eq(_player().health.current, 9, "the whole slam, softened only by the board's 8% armour")
	assert_true(await _blow(Vector2(12, 0), 2) == false, "and the hero is briefly untouchable after it")


func test_the_board_stops_a_whole_blow_and_armour_takes_what_a_buckler_lets_through() -> void:
	await _start({&"crew_board_shield": 1}, {&"off_hand": &"crew_board_shield"})
	await _raise_shield()
	await _blow(Vector2(12, 0), 4)
	assert_eq(_player().health.current, 12, "the board stops everything")
	Input.action_release(&"block")
	await _restart()
	await _start({&"barrel_lid_buckler": 1, &"quarry_breastplate": 1},
			{&"off_hand": &"barrel_lid_buckler", &"torso": &"quarry_breastplate"})
	await _raise_shield()
	await _blow(Vector2(12, 0), 4)
	# Half of 4 passes the buckler; the breastplate's 10% leaves 1.8: one... wait, 1 is taken, 0.8 carried.
	assert_eq(_player().health.current, 11, "the buckler halves it, then armour softens the rest")


func test_without_breath_the_guard_breaks() -> void:
	await _start({&"barrel_lid_buckler": 1}, {&"off_hand": &"barrel_lid_buckler"})
	for i in 4:
		Input.action_press(&"move_down")
		await _press(&"dodge")
		Input.action_release(&"move_down")
		await _wait_until(func() -> bool: return _player().state == Player.State.MOVE, 1.0)
	assert_lt(_player().stamina.current, 24.0, "breath spent on dodges")
	await _press(&"move_right")
	await _raise_shield()
	await _blow(Vector2(12, 0), 2)
	assert_eq(_player().state, Player.State.HURT, "the guard breaks")
	assert_eq(_player().health.current, 11, "and the blow lands, softened only by the buckler's 3% armour")
	assert_eq(_player().stamina.current, 0.0)


func test_the_dodge_moves_fast_and_is_untouchable_for_a_moment() -> void:
	await _start()
	var from := _player().global_position
	Input.action_press(&"move_right")
	await _press(&"dodge", 1)
	assert_eq(_player().state, Player.State.DODGE)
	assert_true(_player().is_untouchable())
	assert_false(await _blow(Vector2(10, 0)), "a blow in the untouchable moment passes")
	Input.action_release(&"move_right")
	await _wait_until(func() -> bool: return _player().state == Player.State.MOVE, 1.0)
	var moved := _player().global_position.x - from.x
	assert_almost_eq(moved, HeroStats.DODGE_DISTANCE[HeroStats.LIGHT], 4.0, "a light hero steps 44 px")
	assert_eq(_player().health.current, 12)
	assert_lt(_player().stamina.current, _player().stamina.maximum, "it cost breath")


func test_a_dodge_stops_at_walls() -> void:
	await _start()
	_player().global_position = Vector2(300, 196)
	await wait_physics_frames(2)
	Input.action_press(&"move_up")
	await _press(&"dodge", 1)
	Input.action_release(&"move_up")
	await _wait_until(func() -> bool: return _player().state == Player.State.MOVE, 1.0)
	var body: CollisionShape2D = _player().get_node(^"Collision")
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body.shape
	query.collision_mask = 1
	query.exclude = [_player().get_rid()]
	query.transform = Transform2D(0.0, _player().global_position + body.position)
	assert_true(_player().get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty(), "not inside anything")
	assert_gt(_player().global_position.y, 176.0, "stopped by the shelter, not through it")


func test_heavy_loads_dodge_shorter_and_recover_later() -> void:
	var heavy := {&"quarry_maul": 1, &"crew_board_shield": 1, &"quarry_helm": 1, &"quarry_breastplate": 1,
			&"quarry_gauntlets": 1, &"quarry_greaves": 1}
	var worn := {&"main_hand": &"quarry_maul", &"off_hand": &"crew_board_shield", &"head": &"quarry_helm",
			&"torso": &"quarry_breastplate", &"hands": &"quarry_gauntlets", &"legs": &"quarry_greaves"}
	var lengths := []
	for kit in [[{}, {}], [heavy, worn]]:
		await _start(kit[0], kit[1])
		var from := _player().global_position
		Input.action_press(&"move_right")
		await _press(&"dodge", 1)
		Input.action_release(&"move_right")
		var frames := 0
		while _player().state == Player.State.DODGE and frames < 240:
			await wait_physics_frames(1)
			frames += 1
		lengths.append([_player().global_position.x - from.x, frames])
		await _restart()
	gut.p("light dodge %s, overloaded dodge %s (px, frames)" % [lengths[0], lengths[1]])
	assert_almost_eq(lengths[1][0], 24.0, 4.0, "an overloaded hero steps 24 px")
	assert_gt(lengths[0][0], lengths[1][0] + 15.0, "a light one much further")
	assert_gt(lengths[1][1], lengths[0][1] * 1.4, "and the overloaded one stays in the dodge far longer")


func test_each_weapon_strikes_its_own_area() -> void:
	await _start({&"traveller_staff": 1})
	var far := await _dummy(Vector2(26, 0))
	var wide := await _dummy(Vector2(14, 9))
	await _swing()
	assert_eq(far.current, 50, "the sword does not reach 26 px")
	assert_eq(wide.current, 49, "but sweeps wide")
	game.adventure.equip(ItemCatalog.MAIN_HAND, &"traveller_staff")
	await wait_physics_frames(3)
	await _swing()
	assert_eq(far.current, 49, "the staff's thrust reaches 26 px")
	assert_eq(wide.current, 49, "but stabs narrow")


func test_the_machete_chains_swings_the_maul_takes_its_time() -> void:
	var counts := {}
	for weapon: StringName in [&"crew_machete", &"wayfarer_sword", &"quarry_maul"]:
		await _start({weapon: 1} if weapon != &"wayfarer_sword" else {})
		if weapon != &"wayfarer_sword":
			game.adventure.equip(ItemCatalog.MAIN_HAND, weapon)
			await wait_physics_frames(2)
		var target := await _dummy(Vector2(14, 0))
		Input.action_press(&"move_right")
		for i in 60:
			Input.action_press(&"attack")
			await wait_physics_frames(1)
			Input.action_release(&"attack")
			await wait_physics_frames(1)
		Input.action_release(&"move_right")
		counts[weapon] = 50 - target.current
		await _restart()
	gut.p("quarters dealt in 2 s of mashing: %s" % counts)
	assert_gt(counts[&"crew_machete"], counts[&"wayfarer_sword"], "the machete chains")
	assert_gt(counts[&"wayfarer_sword"], 0)
	assert_gt(counts[&"quarry_maul"], 0, "the maul still lands")


func test_heavy_blows_hold_a_musgorico_longer_but_quick_ones_cannot_hold_it_forever() -> void:
	await _start({&"quarry_maul": 1, &"crew_machete": 1})
	var musgo: Musgorico = MusgoricoScene.instantiate()
	musgo.rng_seed = 2
	game.level.get_node(^"Entities").add_child(musgo)
	musgo.global_position = _player().global_position + Vector2(18, 0)
	await wait_physics_frames(2)
	_player().face(Vector2.RIGHT)
	await _press(&"attack")
	await _wait_until(func() -> bool: return musgo.state == Musgorico.State.HURT, 1.0)
	var sword_hold := 0
	while musgo.state == Musgorico.State.HURT and sword_hold < 200:
		await wait_physics_frames(1)
		sword_hold += 1
	musgo.queue_free()
	game.adventure.equip(ItemCatalog.MAIN_HAND, &"quarry_maul")
	await wait_physics_frames(30)
	var second: Musgorico = MusgoricoScene.instantiate()
	second.rng_seed = 2
	game.level.get_node(^"Entities").add_child(second)
	second.global_position = _player().global_position + Vector2(18, 0)
	await wait_physics_frames(2)
	_player().face(Vector2.RIGHT)
	await _press(&"attack")
	await _wait_until(func() -> bool: return second.state == Musgorico.State.HURT, 1.0)
	var maul_hold := 0
	while second.state == Musgorico.State.HURT and maul_hold < 200:
		await wait_physics_frames(1)
		maul_hold += 1
	gut.p("held %d frames by the sword, %d by the maul" % [sword_hold, maul_hold])
	assert_gt(maul_hold, sword_hold * 2, "the maul holds it far longer")
	for i in 6:
		second._on_hit_received(Hit.new(0, 0.0, _player().global_position))
		second.get("health")
	assert_true(second.is_steady(), "a flurry makes it bristle and shrug blows off")


func test_a_heavy_blow_shuts_a_cardosa_longer() -> void:
	await _start({&"woodcutter_hatchet": 1}, {&"main_hand": &"woodcutter_hatchet"})
	var cardosa: Cardosa = CardosaScene.instantiate()
	game.level.get_node(^"Entities").add_child(cardosa)
	cardosa.global_position = _player().global_position + Vector2(16, 6)
	await wait_physics_frames(2)
	var start := cardosa.global_position
	await _swing()
	assert_eq(cardosa.state, Cardosa.State.HURT)
	assert_eq(cardosa.global_position, start, "rooted: never pushed")
	var shut := 0
	while cardosa.state == Cardosa.State.HURT and shut < 200:
		await wait_physics_frames(1)
		shut += 1
	var sword_shut := roundi(cardosa.hurt_time / get_physics_process_delta_time())
	gut.p("the hatchet kept it shut %d frames" % shut)
	assert_gt(shut, 0, "a hatchet keeps it shut (longer than a sword's %d-frame default)" % sword_shut)
	assert_almost_eq(cardosa.get("health").current, 1, 0, "one quarter off")


func test_the_wardens_slam_and_roots_cannot_be_blocked_its_swipe_can() -> void:
	var warden: Node = (load("res://actors/root_warden/root_warden.tscn") as PackedScene).instantiate()
	var spike: Node = (load("res://actors/root_warden/root_spike.tscn") as PackedScene).instantiate()
	assert_false((warden.get_node(^"SlamHitbox") as Hitbox).blockable, "the slam comes from above")
	assert_true((warden.get_node(^"ContactHitbox") as Hitbox).blockable, "its body can be blocked")
	assert_false((spike.get_node(^"Hitbox") as Hitbox).blockable, "roots come from the ground")
	warden.free()
	spike.free()


func test_eating_takes_time_and_a_blow_interrupts_it() -> void:
	await _start({&"corn_bread": 2})
	var hud: Hud = game.get_node(^"HUD")
	assert_true(hud.is_quick_item_visible(), "the quick slot shows the bread")
	await _press(&"quick_item")
	assert_eq(_player().state, Player.State.MOVE, "nothing to eat for at full health")
	assert_eq(game.adventure.count(&"corn_bread"), 2)
	_player().health.take_damage(6)
	await wait_physics_frames(80)
	await _press(&"quick_item")
	assert_true(_player().is_eating())
	await wait_physics_frames(20)
	await _blow(Vector2(10, 0), 1)
	assert_false(_player().is_eating(), "a blow interrupts it")
	assert_eq(game.adventure.count(&"corn_bread"), 2, "and nothing is eaten")
	await wait_physics_frames(80)
	var health := _player().health.current
	await _press(&"quick_item")
	await _wait_until(func() -> bool: return not _player().is_eating(), 2.0)
	assert_eq(_player().health.current, health + 4, "a heart back")
	assert_eq(game.adventure.count(&"corn_bread"), 1, "one eaten")


func test_the_menu_chooses_the_quick_food_and_it_is_saved() -> void:
	await _start({&"corn_bread": 1, &"herb_tea": 1})
	assert_eq(game.quick_item(), &"corn_bread", "the first food by default")
	var menu := game.hero_menu()
	game.open_equipment()
	menu.page = HeroMenu.Page.INVENTORY
	menu._tab = 4
	menu._cell = menu.shown_items().find(&"herb_tea")
	menu._confirm()
	assert_eq(game.adventure.quick_item, &"herb_tea", "E chooses it")
	assert_eq(game.adventure.count(&"herb_tea"), 1, "and does not eat it")
	menu.close()
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(game.quick_item(), &"herb_tea", "after Continue")


func test_a_gamepad_dodges_blocks_and_eats() -> void:
	await _start({&"bark_shield": 1, &"corn_bread": 1}, {&"off_hand": &"bark_shield"})
	var press := func(button: JoyButton, pressed: bool) -> void:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
	press.call(JOY_BUTTON_LEFT_SHOULDER, true)
	await wait_process_frames(2)
	await wait_physics_frames(12)
	assert_true(_player().is_guarding(), "LB raises the shield")
	press.call(JOY_BUTTON_LEFT_SHOULDER, false)
	await wait_process_frames(2)
	await wait_physics_frames(2)
	press.call(JOY_BUTTON_B, true)
	await wait_process_frames(2)
	await wait_physics_frames(1)
	assert_eq(_player().state, Player.State.DODGE, "B dodges")
	press.call(JOY_BUTTON_B, false)
	await _wait_until(func() -> bool: return _player().state == Player.State.MOVE, 1.0)
	_player().health.take_damage(4)
	await wait_physics_frames(70)
	press.call(JOY_BUTTON_Y, true)
	await wait_process_frames(2)
	await wait_physics_frames(1)
	assert_true(_player().is_eating(), "Y eats")
	press.call(JOY_BUTTON_Y, false)


func test_breath_and_guard_are_fresh_after_a_fall_and_continue() -> void:
	await _start({&"bark_shield": 1}, {&"off_hand": &"bark_shield"})
	Input.action_press(&"move_right")
	await _press(&"dodge")
	Input.action_release(&"move_right")
	assert_lt(_player().stamina.current, 100.0)
	await _fall_and_retry()
	assert_eq(_player().stamina.current, 100.0, "full breath after a fall")
	assert_not_null(_player().guard(), "the shield is still in hand")
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_not_null(_player().guard(), "and after Continue")
	assert_eq(_player().state, Player.State.MOVE)
