extends GutTest
## The UI bitmap font: glyph shapes that once read wrong, and coverage of every translation.

const FNT := "res://assets/ardovel/ui/fonts/ardovel_8.fnt"

# The imported font, as the game draws it: its glyph sheet and the size it was built at.
var _font: FontFile
var _size: Vector2i
var _sheet: Image


func before_all() -> void:
	_font = load(FNT)
	_size = _font.get_size_cache_list(0)[0]
	_sheet = _font.get_texture_image(0, _size, 0)


## Ink pixels of `ch`, in glyph coordinates.
func _ink(ch: String) -> Array[Vector2i]:
	var code := ch.unicode_at(0)
	assert_eq(_font.get_glyph_texture_idx(0, _size, code), 0, "%s is on the first glyph sheet" % ch)
	var rect := Rect2i(_font.get_glyph_uv_rect(0, _size, code))
	var pixels: Array[Vector2i] = []
	for y in rect.size.y:
		for x in rect.size.x:
			if _sheet.get_pixel(rect.position.x + x, rect.position.y + y).a > 0.0:
				pixels.append(Vector2i(x, y))
	return pixels


## Number of 8-connected pieces of ink.
func _pieces(pixels: Array[Vector2i]) -> int:
	var left := pixels.duplicate()
	var count := 0
	while not left.is_empty():
		count += 1
		var stack: Array[Vector2i] = [left.pop_back()]
		while not stack.is_empty():
			var p: Vector2i = stack.pop_back()
			for n in left.duplicate():
				if absi(n.x - p.x) <= 1 and absi(n.y - p.y) <= 1:
					left.erase(n)
					stack.append(n)
	return count


func test_lowercase_i_is_a_dot_over_a_stem() -> void:
	# The pack's original 'i' had two loose pixels on the baseline: "caiu" read as "ca.iu".
	assert_eq(_pieces(_ink("i")), 2)
	assert_eq(_pieces(_ink("í")), 2, "accent over the stem")


func test_capital_accents_float_above_their_letter() -> void:
	for ch in "ÁÀÂÃÉÊÍÓÔÕÚ":
		var rows := {}
		for p in _ink(ch):
			rows[p.y] = true
		var top: int = rows.keys().min()
		assert_true(rows.has(top) and not rows.has(top + 1), "%s: a blank row between mark and letter" % ch)


func test_every_character_of_every_translation_has_a_glyph() -> void:
	var missing := {}
	for locale in Settings.LOCALES:
		var translation := TranslationServer.get_translation_object(locale)
		assert_eq(translation.locale, locale, "%s is loaded" % locale)
		for message in translation.get_translated_message_list():
			for ch in message:
				var code := ch.unicode_at(0)
				if code > 126 and not _font.has_char(code):
					missing[ch] = locale
	assert_eq(missing, {}, "characters without a glyph (and the language using them)")
