class_name HeroLook
extends RefCounted
## The hero's frames with what they wear: the walk (and idle), hurt, death, attack and guard sheets
## put together once, when the equipment changes, and then used as the hero's own sheets. Nothing is
## drawn per frame.
##
## Each head, torso, hands and legs piece has a worn sheet (ItemDef.worn_sheet, 216x160) holding the
## piece as it shows over every frame of the hero, in the places named below; it is drawn by hand
## in art-production (src/hero_wear.py, tools/ardovel/hero_wear_build.py, whose compose() is this
## same rule). Pieces go on legs first, then torso, hands and head. In the swings the part of the
## weapon in front of the hero goes on top again (ItemDef.attack_layers), and gloves also cover the
## fist that grips it; with a shield up, the hero as worn goes on the guard sheet and the part of
## the shield in front of them on top (ItemDef.guard_front).
##
## With nothing visible worn, the sheets are the hero's own textures, untouched. The last few looks
## are kept, so changing back and forth (or the menu's preview) does not put them together again.

const WALK: Texture2D = preload("res://assets/ardovel/characters/hero_walk.png")
const HURT: Texture2D = preload("res://assets/ardovel/characters/hero_hurt.png")
const DEATH: Texture2D = preload("res://assets/ardovel/characters/hero_death.png")
## Where each of the hero's sheets is on a worn sheet.
const WALK_AT := Rect2i(0, 0, 64, 64)
const HURT_AT := Rect2i(0, 64, 64, 16)
const DEATH_AT := Rect2i(0, 80, 96, 32)
const ATTACK_AT := Rect2i(96, 0, 120, 160)
## Two pixels of a worn hands piece: the colours its fist takes (light, shade); clear if it leaves
## the hand bare.
const GLOVE_AT := Vector2i(0, 112)
const SKIN := Color("ef914f")
const SKIN_SHADE := Color("d3865f")
## On a guard sheet, each direction is 24 pixels wide with the hero standing at (4, 4).
const GUARD_FRAME := 24
const GUARD_BODY := Vector2i(4, 4)
const LAYER_ORDER: Array[StringName] = [ItemCatalog.LEGS, ItemCatalog.TORSO, ItemCatalog.HANDS, ItemCatalog.HEAD]
const KEPT := 8

static var _kept: Dictionary[String, HeroLook] = {}

var walk: Texture2D
var hurt: Texture2D
var death: Texture2D
var attack: Texture2D
## Null without a shield.
var guard: Texture2D
## Ids of what makes this look (weapon, shield, pieces).
var key: String


## The look of a hero holding `weapon` (and `shield`, or null) and wearing `pieces` (equipment with
## a worn sheet; anything else is ignored).
static func of(weapon: ItemDef, shield: ItemDef, pieces: Array[ItemDef]) -> HeroLook:
	var worn := _ordered(pieces)
	var parts: Array[String] = [String(weapon.id) if weapon != null else "", String(shield.id) if shield != null else ""]
	for piece in worn:
		parts.append(String(piece.id))
	var key := "|".join(parts)
	if _kept.has(key):
		var found: HeroLook = _kept[key]
		_kept.erase(key)
		_kept[key] = found  # most recently used last
		return found
	var look := HeroLook.new()
	look.key = key
	look._compose(weapon, shield, worn)
	_kept[key] = look
	while _kept.size() > KEPT:
		_kept.erase(_kept.keys()[0])
	return look


## Forgets the looks kept (tests).
static func forget() -> void:
	_kept.clear()


static func _ordered(pieces: Array[ItemDef]) -> Array[ItemDef]:
	var worn: Array[ItemDef] = []
	for slot in LAYER_ORDER:
		for piece in pieces:
			if piece != null and piece.worn_sheet != null and piece.slot == slot and not worn.has(piece):
				worn.append(piece)
	return worn


func _compose(weapon: ItemDef, shield: ItemDef, worn: Array[ItemDef]) -> void:
	var base_attack: Texture2D = weapon.attack_sheet if weapon != null else null
	var base_guard: Texture2D = shield.guard_sheet if shield != null else null
	if worn.is_empty():
		walk = WALK
		hurt = HURT
		death = DEATH
		attack = base_attack
		guard = base_guard
		return
	var sheets: Array[Image] = []
	for piece in worn:
		sheets.append(_image(piece.worn_sheet))
	var walk_image := _layered(WALK, sheets, WALK_AT)
	walk = ImageTexture.create_from_image(walk_image)
	hurt = ImageTexture.create_from_image(_layered(HURT, sheets, HURT_AT))
	death = ImageTexture.create_from_image(_layered(DEATH, sheets, DEATH_AT))
	if base_attack != null:
		var image := _layered(base_attack, sheets, ATTACK_AT)
		if weapon.attack_layers != null:
			var layers := _image(weapon.attack_layers)
			var size := ATTACK_AT.size
			image.blend_rect(layers, Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
			var glove := _glove(worn, sheets)
			if not glove.is_empty():
				_cover_fist(image, _image(base_attack), layers.get_region(Rect2i(Vector2i(size.x, 0), size)), glove)
		attack = ImageTexture.create_from_image(image)
	if base_guard != null:
		var image := _image(base_guard)
		for i in 4:
			var frame := walk_image.get_region(Rect2i(i * 16, 0, 16, 16))
			image.blend_rect(frame, Rect2i(0, 0, 16, 16), Vector2i(i * GUARD_FRAME, 0) + GUARD_BODY)
		if shield.guard_front != null:
			var front := _image(shield.guard_front)
			image.blend_rect(front, Rect2i(Vector2i.ZERO, front.get_size()), Vector2i.ZERO)
		guard = ImageTexture.create_from_image(image)


## `texture` with the region `at` of every worn sheet over it.
static func _layered(texture: Texture2D, sheets: Array[Image], at: Rect2i) -> Image:
	var image := _image(texture)
	for sheet in sheets:
		image.blend_rect(sheet, at, Vector2i.ZERO)
	return image


## A copy of `texture`'s pixels to draw on: the image a texture hands out may be its own (it is
## without a GPU), and the hero's sheets must never change.
static func _image(texture: Texture2D) -> Image:
	var image := texture.get_image().duplicate() as Image
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	return image


## The fist colours of the first hands piece that covers the hand ([light, shade]), or empty.
static func _glove(worn: Array[ItemDef], sheets: Array[Image]) -> Array[Color]:
	for i in worn.size():
		if worn[i].slot == ItemCatalog.HANDS:
			var light := sheets[i].get_pixelv(GLOVE_AT)
			if light.a > 0.0:
				return [light, sheets[i].get_pixelv(GLOVE_AT + Vector2i.RIGHT)]
	return []


## Turns the skin of the fist on the weapon (where it shows, as in the weapon's own sheet) into the
## glove's colours.
static func _cover_fist(image: Image, base: Image, fist: Image, glove: Array[Color]) -> void:
	var used := fist.get_used_rect()
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			var pixel := fist.get_pixel(x, y)
			if pixel.a == 0.0 or base.get_pixel(x, y) != pixel or image.get_pixel(x, y) != pixel:
				continue
			if pixel.is_equal_approx(SKIN):
				image.set_pixel(x, y, glove[0])
			elif pixel.is_equal_approx(SKIN_SHADE):
				image.set_pixel(x, y, glove[1])
