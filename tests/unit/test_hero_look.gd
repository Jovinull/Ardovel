extends GutTest
## How what is worn shows on the hero (HeroLook): every piece of head, torso, hands and legs has a
## worn sheet that covers every frame and direction; weapons and shields keep what is in front of the
## hero in front; with nothing visible worn the hero's own sheets are used untouched; pieces go on
## in one order whatever the order given; gloves cover the fist on the weapon; a look is put
## together once and kept; rings and accessories do not show.

const WORN_SIZE := Vector2i(216, 160)
const ARMOR_SLOTS: Array[StringName] = [ItemCatalog.HEAD, ItemCatalog.TORSO, ItemCatalog.HANDS, ItemCatalog.LEGS]
const LIGHT: Array[StringName] = [&"straw_hat", &"padded_doublet", &"work_mitts", &"rope_sandals"]
const BALANCED: Array[StringName] = [&"traveller_hood", &"traveller_coat", &"traveller_bracers", &"traveller_boots"]
const HEAVY: Array[StringName] = [&"quarry_helm", &"quarry_breastplate", &"quarry_gauntlets", &"quarry_greaves"]


func before_each() -> void:
	HeroLook.forget()


func _items(ids: Array[StringName]) -> Array[ItemDef]:
	var items: Array[ItemDef] = []
	for id in ids:
		items.append(ItemCatalog.find(id))
	return items


func _image(texture: Texture2D) -> Image:
	var image := texture.get_image().duplicate() as Image
	image.convert(Image.FORMAT_RGBA8)
	return image


func _pieces() -> Array[ItemDef]:
	var pieces: Array[ItemDef] = []
	for id in ItemCatalog.ITEMS:
		var item := ItemCatalog.find(id)
		if item.slot in ARMOR_SLOTS:
			pieces.append(item)
	return pieces


## Opaque pixels of `image` inside `rect`.
func _opaque(image: Image, rect: Rect2i) -> int:
	var count := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if image.get_pixel(x, y).a > 0.0:
				count += 1
	return count


func test_every_piece_of_armour_shows_in_every_frame_of_walking() -> void:
	var pieces := _pieces()
	assert_eq(pieces.size(), 16)
	for piece in pieces:
		assert_not_null(piece.worn_sheet, String(piece.id))
		var sheet := _image(piece.worn_sheet)
		assert_eq(sheet.get_size(), WORN_SIZE, String(piece.id))
		for direction in 4:
			for frame in 4:
				var rect := Rect2i(direction * 16, frame * 16, 16, 16)
				assert_gt(_opaque(sheet, rect), 0, "%s, direction %d, frame %d" % [piece.id, direction, frame])
		for direction in 4:
			var rect := Rect2i(96, direction * 40, 120, 40)
			if piece.slot == ItemCatalog.HANDS and direction >= 2:
				continue  # in side swings the hand is the fist on the weapon (see the glove test)
			assert_gt(_opaque(sheet, rect), 0, "%s swinging, row %d" % [piece.id, direction])


func test_worn_sheets_are_pixel_art() -> void:
	for piece in _pieces():
		var sheet := _image(piece.worn_sheet)
		var colours := {}
		var blended := 0
		for y in sheet.get_height():
			for x in sheet.get_width():
				var pixel := sheet.get_pixel(x, y)
				if pixel.a > 0.0 and pixel.a < 1.0:
					blended += 1
				elif pixel.a > 0.0:
					colours[pixel.to_html(false)] = true
		assert_eq(blended, 0, "%s: no half-transparent pixels" % piece.id)
		assert_lte(colours.size(), 12, "%s: a small palette" % piece.id)


func test_rings_and_accessories_do_not_show() -> void:
	for id in ItemCatalog.ITEMS:
		var item := ItemCatalog.find(id)
		if not item.slot in ARMOR_SLOTS:
			assert_null(item.worn_sheet, String(id))


func test_weapons_and_shields_know_what_is_in_front() -> void:
	for id in ItemCatalog.ITEMS:
		var item := ItemCatalog.find(id)
		if item.category == ItemCatalog.WEAPON:
			assert_not_null(item.attack_layers, String(id))
			assert_eq(_image(item.attack_layers).get_size(), Vector2i(240, 160), String(id))
			var front := _image(item.attack_layers).get_region(Rect2i(0, 0, 120, 160))
			var sheet := _image(item.attack_sheet)
			for y in 160:
				for x in 120:
					var pixel := front.get_pixel(x, y)
					if pixel.a > 0.0 and pixel != sheet.get_pixel(x, y):
						fail_test("%s: the front layer must be cut from the attack sheet (%d, %d)" % [id, x, y])
						return
		elif item.category == ItemCatalog.SHIELD:
			assert_not_null(item.guard_front, String(id))
			assert_eq(_image(item.guard_front).get_size(), Vector2i(96, 24), String(id))


func test_with_nothing_visible_the_hero_is_untouched() -> void:
	var sword := ItemCatalog.find(&"wayfarer_sword")
	var shield := ItemCatalog.find(&"traveller_shield")
	var look := HeroLook.of(sword, shield, _items([&"whitestone_ring", &"crew_gloves"] as Array[StringName]))
	assert_eq(look.walk, HeroLook.WALK, "the very same texture")
	assert_eq(look.hurt, HeroLook.HURT)
	assert_eq(look.death, HeroLook.DEATH)
	assert_eq(look.attack, sword.attack_sheet)
	assert_eq(look.guard, shield.guard_sheet)
	assert_null(HeroLook.of(sword, null, []).guard, "no shield, no guard frames")


func test_worn_pixels_cover_the_hero_and_the_rest_stays() -> void:
	var helm := ItemCatalog.find(&"quarry_helm")
	var look := HeroLook.of(ItemCatalog.find(&"wayfarer_sword"), null, [helm] as Array[ItemDef])
	var walk := _image(look.walk)
	var base := _image(HeroLook.WALK)
	var worn := _image(helm.worn_sheet)
	var changed := 0
	for y in 64:
		for x in 64:
			var mark := worn.get_pixel(x, y)
			if mark.a > 0.0:
				assert_eq(walk.get_pixel(x, y), mark)
				changed += 1
			elif walk.get_pixel(x, y) != base.get_pixel(x, y):
				fail_test("(%d, %d) changed where the helm has nothing" % [x, y])
				return
	assert_gt(changed, 200, "the helm is plainly there")


func test_pieces_go_on_in_one_order() -> void:
	var sword := ItemCatalog.find(&"wayfarer_sword")
	var forward := HeroLook.of(sword, null, _items(HEAVY))
	var reversed := HEAVY.duplicate()
	reversed.reverse()
	HeroLook.forget()
	var backward := HeroLook.of(sword, null, _items(reversed))
	assert_eq(forward.key, backward.key)
	assert_eq(_image(forward.walk).get_data(), _image(backward.walk).get_data())
	assert_eq(_image(forward.attack).get_data(), _image(backward.attack).get_data())


func test_the_weapon_in_front_stays_in_front() -> void:
	for id: StringName in [&"wayfarer_sword", &"quarry_maul", &"traveller_staff"]:
		var weapon := ItemCatalog.find(id)
		var attack := _image(HeroLook.of(weapon, null, _items(HEAVY)).attack)
		var front := _image(weapon.attack_layers)
		for y in 160:
			for x in 120:
				var pixel := front.get_pixel(x, y)
				var fist := front.get_pixel(120 + x, y)
				if pixel.a > 0.0 and fist.a == 0.0 and attack.get_pixel(x, y) != pixel:
					fail_test("%s: (%d, %d) is covered by the armour" % [id, x, y])
					return
	pass_test("weapons drawn in front of the hero stay in front of what they wear")


func test_gloves_cover_the_fist_on_the_weapon_and_bracers_do_not() -> void:
	var sword := ItemCatalog.find(&"wayfarer_sword")
	var base := _image(sword.attack_sheet)
	var fist := _image(sword.attack_layers).get_region(Rect2i(120, 0, 120, 160))
	var gloved := _image(HeroLook.of(sword, null, _items([&"quarry_gauntlets"] as Array[StringName])).attack)
	var bare := _image(HeroLook.of(sword, null, _items([&"traveller_bracers"] as Array[StringName])).attack)
	var covered := 0
	var kept := 0
	for y in 160:
		for x in 120:
			var pixel := fist.get_pixel(x, y)
			if pixel.a == 0.0 or base.get_pixel(x, y) != pixel:
				continue
			if gloved.get_pixel(x, y) != pixel:
				covered += 1
			if bare.get_pixel(x, y) == pixel:
				kept += 1
	assert_gt(covered, 10, "the gauntlet grips the sword")
	assert_gt(kept, 10, "a bare hand stays bare")
	for row in [2, 3]:
		var side := Rect2i(0, row * 40, 120, 40)
		assert_ne(gloved.get_region(side).get_data(), base.get_region(side).get_data(), "gloved in side swing %d" % row)


func test_a_raised_shield_shows_the_armour_behind_it() -> void:
	var shield := ItemCatalog.find(&"crew_board_shield")
	var look := HeroLook.of(ItemCatalog.find(&"quarry_maul"), shield, _items(HEAVY))
	var guard := _image(look.guard)
	var walk := _image(look.walk)
	var front := _image(shield.guard_front)
	assert_eq(guard.get_size(), Vector2i(96, 24))
	for direction in 4:
		for y in 16:
			for x in 16:
				var at := Vector2i(direction * 24 + 4 + x, 4 + y)
				var expected := front.get_pixelv(at) if front.get_pixelv(at).a > 0.0 else walk.get_pixel(direction * 16 + x, y)
				if expected.a > 0.0 and guard.get_pixelv(at) != expected:
					fail_test("direction %d, (%d, %d)" % [direction, x, y])
					return
	pass_test("the hero behind the shield wears what they wear")


func test_the_three_kits_look_different() -> void:
	var sword := ItemCatalog.find(&"wayfarer_sword")
	var kits := [LIGHT, BALANCED, HEAVY]
	var walks: Array[PackedByteArray] = []
	for kit: Array[StringName] in kits:
		walks.append(_image(HeroLook.of(sword, null, _items(kit)).walk).get_data())
	assert_ne(walks[0], walks[1])
	assert_ne(walks[1], walks[2])
	assert_ne(walks[0], walks[2])
	assert_ne(walks[0], _image(HeroLook.WALK).get_data())


func test_putting_looks_together_never_changes_the_sheets() -> void:
	var maul := ItemCatalog.find(&"quarry_maul")
	var shield := ItemCatalog.find(&"crew_board_shield")
	var sheets: Array[Texture2D] = [HeroLook.WALK, HeroLook.HURT, HeroLook.DEATH, maul.attack_sheet, shield.guard_sheet]
	var before: Array[PackedByteArray] = []
	for sheet in sheets:
		before.append(_image(sheet).get_data())
	for kit: Array[StringName] in [LIGHT, BALANCED, HEAVY]:
		HeroLook.forget()
		HeroLook.of(maul, shield, _items(kit))
	for i in sheets.size():
		assert_eq(_image(sheets[i]).get_data(), before[i], "sheet %d untouched" % i)


func test_a_look_is_put_together_once_and_kept() -> void:
	var sword := ItemCatalog.find(&"wayfarer_sword")
	var first := HeroLook.of(sword, null, _items(HEAVY))
	assert_same(HeroLook.of(sword, null, _items(HEAVY)), first, "asked again, the same look")
	for id: StringName in [&"straw_hat", &"traveller_hood", &"ruin_circlet"]:
		HeroLook.of(sword, null, _items([id] as Array[StringName]))
	assert_same(HeroLook.of(sword, null, _items(HEAVY)), first, "still kept after a few others")
	for id in ItemCatalog.ITEMS:
		var item := ItemCatalog.find(id)
		if item.slot in ARMOR_SLOTS:
			HeroLook.of(sword, null, [item] as Array[ItemDef])
	assert_not_same(HeroLook.of(sword, null, _items(HEAVY)), first, "only the last few are kept")


func test_the_profile_carries_what_shows() -> void:
	var adventure := Adventure.new()
	for id in [&"wayfarer_sword", &"quarry_helm", &"traveller_coat", &"bark_shield", &"whitestone_ring"]:
		adventure.add_item(id)
	adventure.equip(ItemCatalog.MAIN_HAND, &"wayfarer_sword")
	adventure.equip(ItemCatalog.HEAD, &"quarry_helm")
	adventure.equip(ItemCatalog.TORSO, &"traveller_coat")
	adventure.equip(ItemCatalog.OFF_HAND, &"bark_shield")
	adventure.equip(ItemCatalog.RING_1, &"whitestone_ring")
	var profile := HeroLoadout.profile(adventure, 12)
	assert_eq(profile.shield.id, &"bark_shield")
	assert_eq(profile.pieces.size(), 2, "the helm and the coat; the ring does not show")
	var look := profile.look()
	assert_same(HeroLoadout.profile(adventure, 12).look(), look, "the same equipment, the same look")
	assert_eq(look.key, "wayfarer_sword|bark_shield|traveller_coat|quarry_helm")
