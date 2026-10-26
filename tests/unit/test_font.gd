extends GutTest
## The UI bitmap font: glyph shapes that once read wrong, and coverage of the game's text.

const FNT := "res://assets/ardovel/ui/fonts/ardovel_8.fnt"
const PNG := "res://assets/ardovel/ui/fonts/ardovel_8.png"
## Folders holding player-facing text (scripts and scenes).
const TEXT_DIRS: Array[String] = ["res://actors", "res://game", "res://interaction", "res://ui", "res://world"]

var _sheet: Image
var _glyphs: Dictionary[int, Rect2i] = {}


func before_all() -> void:
	_sheet = Image.load_from_file(PNG)
	var regex := RegEx.create_from_string("char id=(\\d+) x=(\\d+) y=(\\d+) width=(\\d+) height=(\\d+)")
	for found in regex.search_all(FileAccess.get_file_as_string(FNT)):
		_glyphs[found.get_string(1).to_int()] = Rect2i(found.get_string(2).to_int(), found.get_string(3).to_int(),
				found.get_string(4).to_int(), found.get_string(5).to_int())


## Ink pixels of `ch`, in glyph coordinates.
func _ink(ch: String) -> Array[Vector2i]:
	var rect := _glyphs[ch.unicode_at(0)]
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


func test_every_character_in_the_game_text_has_a_glyph() -> void:
	# Player-facing text lives in string literals (script constants, exported scene properties).
	var strings := RegEx.create_from_string("\"(?:[^\"\\\\]|\\\\.)*\"")
	var missing := {}
	for dir in TEXT_DIRS:
		for path in _text_files(dir):
			for literal in strings.search_all(FileAccess.get_file_as_string(path)):
				for ch in literal.get_string():
					var code := ch.unicode_at(0)
					if code > 126 and not _glyphs.has(code):
						missing[ch] = path
	assert_eq(missing, {}, "characters without a glyph (and where they appear)")


func _text_files(dir: String) -> Array[String]:
	var files: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() in ["gd", "tscn", "tres"]:
			files.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		files.append_array(_text_files(dir.path_join(sub)))
	return files
