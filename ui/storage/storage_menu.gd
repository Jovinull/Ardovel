class_name StorageMenu
extends CanvasLayer
## The chest at home, over a frozen area: what the hero carries on the left, what the chest keeps on
## the right. The interact key sends the piece or stack under the cursor across; for more than one,
## the amount is chosen first (left and right by one, up and down by ten), starting from all that
## fits. A piece being worn stays: it is taken off in the hero's menu first. The cursor stays on the
## same item after a move, or as near as it can.
##
## It shows and changes only through the adventure and the rules (Storage, Bag). While open it takes
## the keys that would close it before anything else sees them.

signal closed

enum Column { BAG, CHEST }

const BOX := preload("res://assets/ninja_adventure/Ui/Dialog/DialogueBoxSimple.png")
const CHOICE := preload("res://assets/ninja_adventure/Ui/Dialog/ChoiceBox.png")
const ROWS := 7
const ROW := 16
const AMOUNT_STEP := 10
const LIGHT := Color("f2eaf1")
const DARK := Color("3b3643")
const DIM := Color("948a9c")
const GOLD := Color("f1c471")
const TEAL := Color("2d697b")
const WORSE := Color("e0394c")

var column: Column = Column.BAG
var _cursor: Array[int] = [0, 0]
var _first: Array[int] = [0, 0]
var _choosing_amount := false
var _amount := 1
var _notice := ""
var _notice_bad := false
var _adventure: Adventure
var _gamepad_active := false
var _joypad_name := ""

var _root: Control
var _panels: Array[Control] = []
var _info: Label
var _hint: Label
@onready var _accept: AudioStreamPlayer = $Accept
@onready var _cancel: AudioStreamPlayer = $Cancel
@onready var _move: AudioStreamPlayer = $Move


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and is_open():
		_refresh()


func open(adventure: Adventure) -> void:
	if _root == null:
		_build()
	_adventure = adventure
	column = Column.BAG
	_cursor = [0, 0]
	_first = [0, 0]
	_choosing_amount = false
	_notice = ""
	_root.show()
	set_process_input(true)
	_refresh()


func close() -> void:
	if not is_open():
		return
	_root.hide()
	set_process_input(false)
	closed.emit()


func is_open() -> bool:
	return _root != null and _root.visible


func set_input_mode(gamepad: bool, joypad_name: String) -> void:
	_gamepad_active = gamepad
	_joypad_name = joypad_name
	if is_node_ready() and is_open():
		_refresh()


## The ids one column lists, in the order they were first found (bag) or first put away (chest).
func shown(on: Column) -> Array[StringName]:
	if _adventure == null:
		return []
	return _adventure.items() if on == Column.BAG else _adventure.stored_items()


## The id under the cursor on the column in use, or empty.
func selected() -> StringName:
	var ids := shown(column)
	var index := _cursor[column]
	return ids[index] if index < ids.size() else &""


func is_choosing_amount() -> bool:
	return _choosing_amount


func amount() -> int:
	return _amount


## The last thing said (already translated), or empty.
func notice() -> String:
	return _notice


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not is_open() or event.is_echo():
		return
	var handled := true
	if event.is_action_pressed(&"equipment") or event.is_action_pressed(&"pause"):
		close()
		_cancel.play()
	elif event.is_action_pressed(&"ui_cancel"):
		if _choosing_amount:
			_choosing_amount = false
			_cancel.play()
			_refresh()
		else:
			close()
			_cancel.play()
	elif event.is_action_pressed(&"interact"):
		_confirm()
	elif event.is_action_pressed(&"move_up"):
		_step(-1, -AMOUNT_STEP)
	elif event.is_action_pressed(&"move_down"):
		_step(1, AMOUNT_STEP)
	elif event.is_action_pressed(&"move_left"):
		_turn(-1)
	elif event.is_action_pressed(&"move_right"):
		_turn(1)
	elif event.is_action_pressed(&"menu_prev") and not _choosing_amount:
		_turn(-1)
	elif event.is_action_pressed(&"menu_next") and not _choosing_amount:
		_turn(1)
	elif event.is_action_pressed(&"attack"):
		pass  # never a swing behind the chest
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


## Up and down: the next item, or the amount by ten.
func _step(by_row: int, by_amount: int) -> void:
	if _choosing_amount:
		_set_amount(_amount - by_amount)  # up raises the amount
		return
	var count := shown(column).size()
	if count == 0:
		return
	var next := clampi(_cursor[column] + by_row, 0, count - 1)
	if next == _cursor[column]:
		return
	_cursor[column] = next
	_notice = ""
	_move.play()
	_refresh()


## Left and right: the other column, or the amount by one.
func _turn(by: int) -> void:
	if _choosing_amount:
		_set_amount(_amount + by)
		return
	var next := Column.CHEST if column == Column.BAG else Column.BAG
	column = next
	_notice = ""
	_move.play()
	_refresh()


func _set_amount(value: int) -> void:
	var most := _most(selected())
	var clamped := clampi(value, 1, maxi(most, 1))
	if clamped == _amount:
		return
	_amount = clamped
	_move.play()
	_refresh()


func _confirm() -> void:
	var id := selected()
	if id.is_empty():
		return
	if _choosing_amount:
		_choosing_amount = false
		_send(id, _amount)
		return
	var most := _most(id)
	if most == 0:
		var why := Storage.check_store(_adventure, id, 1) if column == Column.BAG \
				else Storage.check_retrieve(_adventure, id, 1)
		_say(_why(why), true)
		_cancel.play()
		_refresh()
		return
	var available := Storage.loose(_adventure, id) if column == Column.BAG else _adventure.stored(id)
	if available > 1:
		_choosing_amount = true
		_amount = most
		_notice = ""
		_accept.play()
		_refresh()
		return
	_send(id, 1)


## The most of `id` that can cross from the column in use now.
func _most(id: StringName) -> int:
	if id.is_empty():
		return 0
	return Storage.most_to_store(_adventure, id) if column == Column.BAG else Storage.most_to_retrieve(_adventure, id)


func _send(id: StringName, count: int) -> void:
	var result := Storage.store(_adventure, id, count) if column == Column.BAG else Storage.retrieve(_adventure, id, count)
	if result == Storage.Result.MOVED:
		var key := "STORAGE_PUT_AWAY" if column == Column.BAG else "STORAGE_TAKEN"
		_say(tr(key) % [_name(id), count], false)
		_accept.play()
		for on in [Column.BAG, Column.CHEST]:
			_keep_cursor(on, id)
	else:
		_say(_why(result), true)
		_cancel.play()
	_refresh()


## After a move the cursor stays on `id` if the column still lists it; otherwise on the same row, or
## the last one.
func _keep_cursor(on: Column, id: StringName) -> void:
	var ids := shown(on)
	if on == column and ids.has(id):
		_cursor[on] = ids.find(id)
	_cursor[on] = clampi(_cursor[on], 0, maxi(ids.size() - 1, 0))


func _why(result: Storage.Result) -> String:
	match result:
		Storage.Result.WORN:
			return tr("STORAGE_WORN")
		Storage.Result.CHEST_FULL:
			return tr("STORAGE_CHEST_FULL")
		Storage.Result.BAG_FULL:
			return tr("STORAGE_BAG_FULL")
	return ""


func _say(text: String, bad: bool) -> void:
	_notice = text
	_notice_bad = bad


# ---------------------------------------------------------------- building

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.theme = load("res://ui/theme.tres")
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0784314, 0.105882, 0.105882, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	_label(_root, "Title", Rect2(8, 4, 304, 10), GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	for s in 2:
		var panel := _patch(_root, "Bag" if s == Column.BAG else "Chest", BOX, Rect2(8 + s * 156, 18, 148, 132), 6)
		_panels.append(panel)
		_label(panel, "Header", Rect2(8, 5, 92, 10), TEAL, 0, false)
		_label(panel, "More", Rect2(100, 5, 40, 10), DIM, HORIZONTAL_ALIGNMENT_RIGHT, false)
		for r in ROWS:
			var row := _control(panel, "Row%d" % r, Rect2(4, 16 + r * ROW, 140, ROW))
			_patch(row, "Chosen", CHOICE, Rect2(0, 0, 140, ROW), 4)
			var icon := TextureRect.new()
			icon.name = "Icon"
			icon.position = Vector2(2, 0)
			icon.size = Vector2(16, 16)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(icon)
			_label(row, "Name", Rect2(20, 3, 100, 10), DARK, 0, false)
			_label(row, "Count", Rect2(118, 3, 20, 10), DARK, HORIZONTAL_ALIGNMENT_RIGHT, false)
			_pip(row)
	_info = _label(_root, "Info", Rect2(8, 153, 304, 10), LIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	_hint = _label(_root, "Hint", Rect2(4, 166, 312, 10), DIM, HORIZONTAL_ALIGNMENT_CENTER)


## A small gold mark in the icon's corner: worn (as in the hero's menu).
func _pip(row: Control) -> void:
	var edge := ColorRect.new()
	edge.name = "Worn"
	edge.color = Color("141b1b")
	edge.position = Vector2(1, 1)
	edge.size = Vector2(5, 5)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(edge)
	var pip := ColorRect.new()
	pip.color = GOLD
	pip.position = Vector2(1, 1)
	pip.size = Vector2(3, 3)
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.add_child(pip)


func _control(parent: Node, node_name: String, rect: Rect2) -> Control:
	var control := Control.new()
	control.name = node_name
	control.position = rect.position
	control.size = rect.size
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(control)
	return control


func _patch(parent: Node, node_name: String, texture: Texture2D, rect: Rect2, margin: int) -> NinePatchRect:
	var patch := NinePatchRect.new()
	patch.name = node_name
	patch.texture = texture
	patch.position = rect.position
	patch.size = rect.size
	patch.patch_margin_left = margin
	patch.patch_margin_top = margin
	patch.patch_margin_right = margin
	patch.patch_margin_bottom = margin
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(patch)
	return patch


func _label(parent: Node, node_name: String, rect: Rect2, colour: Color, align: int = 0, shadow: bool = true) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = align
	label.clip_text = true
	label.add_theme_color_override(&"font_color", colour)
	if not shadow:
		label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


# ---------------------------------------------------------------- showing

func _refresh() -> void:
	if _adventure == null:
		return
	(_root.get_node(^"Title") as Label).text = tr("STORAGE_TITLE")
	var headers := [tr("STORAGE_BAG") % [Bag.spaces_used(_adventure), Bag.CAPACITY],
			tr("STORAGE_CHEST") % [Storage.spaces_used(_adventure), Storage.CAPACITY]]
	for s in 2:
		var panel := _panels[s]
		var header := panel.get_node(^"Header") as Label
		header.text = headers[s]
		_colour(header, TEAL if s == column else DIM)
		var ids := shown(s)
		_cursor[s] = clampi(_cursor[s], 0, maxi(ids.size() - 1, 0))
		_first[s] = clampi(_first[s], maxi(_cursor[s] - ROWS + 1, 0), _cursor[s])
		(panel.get_node(^"More") as Label).text = "%d/%d" % [_cursor[s] + 1, ids.size()] if ids.size() > ROWS else ""
		for r in ROWS:
			var row := panel.get_node("Row%d" % r) as Control
			var index := _first[s] + r
			var name_label := row.get_node(^"Name") as Label
			var count_label := row.get_node(^"Count") as Label
			# on an empty side the cursor rests on "empty", so the side in use is always shown
			(row.get_node(^"Chosen") as CanvasItem).visible = s == column and index == _cursor[s]
			(row.get_node(^"Worn") as CanvasItem).visible = false
			if index >= ids.size():
				(row.get_node(^"Icon") as TextureRect).texture = null
				name_label.text = tr("STORAGE_EMPTY") if r == 0 and ids.is_empty() else ""
				_colour(name_label, DIM)
				count_label.text = ""
				continue
			var id := ids[index]
			var item := ItemCatalog.find(id)
			(row.get_node(^"Icon") as TextureRect).texture = item.icon if item != null else null
			name_label.text = _name(id)
			var count := Storage.loose(_adventure, id) if s == Column.BAG else _adventure.stored(id)
			var worn := s == Column.BAG and _adventure.equipped_copies(id) > 0
			(row.get_node(^"Worn") as CanvasItem).visible = worn
			count_label.text = "x%d" % count if count > 1 or (worn and count > 0) else ""
			_colour(name_label, DIM if worn and count == 0 else DARK)
	if _choosing_amount:
		_info.text = tr("STORAGE_AMOUNT") % [_amount, _most(selected())]
		_colour(_info, LIGHT)
		_hint.text = _hints([["STORAGE_HINT_STORE" if column == Column.BAG else "STORAGE_HINT_TAKE", [&"interact"]],
				["STORAGE_HINT_AMOUNT", [&"move_left", &"move_right"]], ["MENU_HINT_BACK", [&"ui_cancel"]]])
		return
	_info.text = _notice if not _notice.is_empty() else _about(selected())
	_colour(_info, WORSE if _notice_bad and not _notice.is_empty() else LIGHT)
	var hints: Array = []
	if not selected().is_empty():
		hints.append(["STORAGE_HINT_STORE" if column == Column.BAG else "STORAGE_HINT_TAKE", [&"interact"]])
	hints.append(["STORAGE_HINT_SIDE", [&"move_left", &"move_right"]])
	hints.append(["MENU_HINT_CLOSE", [&"ui_cancel"]])
	_hint.text = _hints(hints)


## The whole name of `id` (the lists cut long ones) and how many there are, or whether it is worn.
func _about(id: StringName) -> String:
	if id.is_empty():
		return ""
	var count := Storage.loose(_adventure, id) if column == Column.BAG else _adventure.stored(id)
	if column == Column.BAG and count == 0:
		return "%s  %s" % [_name(id), tr("MENU_WORN_MARK")]
	return "%s  x%d" % [_name(id), count] if count > 1 else _name(id)


func _name(id: StringName) -> String:
	var item := ItemCatalog.find(id)
	return tr(item.name_key) if item != null else String(id)


func _key(action: StringName) -> String:
	var labels := InputPrompts.action_label(action, _gamepad_active, _joypad_name).split(" / ", false)
	return labels[0] if not labels.is_empty() else ""


func _hints(parts: Array) -> String:
	var texts: PackedStringArray = []
	for part in parts:
		var keys: Array[String] = []
		for action: StringName in part[1]:
			keys.append(_key(action))
		texts.append(InputPrompts.format_template(tr(part[0]), keys))
	return "   ".join(texts)


func _colour(label: Label, colour: Color) -> void:
	label.add_theme_color_override(&"font_color", colour)
