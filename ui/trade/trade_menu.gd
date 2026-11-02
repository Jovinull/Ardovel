class_name TradeMenu
extends CanvasLayer
## A merchant's goods, over a frozen area: what they sell on the left, what the hero could sell them
## on the right, the purse above. The interact key picks the good under the cursor; for more than
## one, the amount is chosen first (left and right by one, up and down by ten), then every trade is
## confirmed before it happens, so nothing is bought or sold by a stray key. What a piece of
## equipment would change on the hero is shown before buying it.
##
## It shows and changes only through the adventure and the rules (Commerce, Bag). While open it
## takes every key the hero would act on, so nothing is swung or used behind it.

signal closed

enum Column { GOODS, OFFERS }
enum Step { BROWSE, AMOUNT, CONFIRM }

const BOX := preload("res://assets/ninja_adventure/Ui/Dialog/DialogueBoxSimple.png")
const CHOICE := preload("res://assets/ninja_adventure/Ui/Dialog/ChoiceBox.png")
const COIN := preload("res://assets/ardovel/ui/copper.png")
const ROWS := 6
const ROW := 16
const AMOUNT_STEP := 10
const LIGHT := Color("f2eaf1")
const DARK := Color("3b3643")
const DIM := Color("948a9c")
const GOLD := Color("f1c471")
const TEAL := Color("2d697b")
const WORSE := Color("e0394c")
const UP := Color("79b8ce")
## Keys of the hero's own actions, swallowed while open.
const HERO_ACTIONS: Array[StringName] = [&"attack", &"dodge", &"block", &"quick_item", &"technique_1",
		&"technique_2", &"menu_sort", &"category_prev", &"category_next"]
const REFUSALS: Dictionary[Commerce.Result, String] = {
	Commerce.Result.SOLD_OUT: "TRADE_SOLD_OUT",
	Commerce.Result.MONEY: "TRADE_NO_MONEY",
	Commerce.Result.BAG_FULL: "TRADE_BAG_FULL",
	Commerce.Result.NOT_WANTED: "TRADE_NOT_WANTED",
	Commerce.Result.KEEPSAKE: "TRADE_KEEPSAKE",
	Commerce.Result.WORN: "TRADE_WORN",
	Commerce.Result.PURSE_FULL: "TRADE_PURSE_FULL",
}

var column: Column = Column.GOODS
var step: Step = Step.BROWSE
var merchant: StringName
var _cursor: Array[int] = [0, 0]
var _first: Array[int] = [0, 0]
var _amount := 1
var _notice := ""
var _notice_bad := false
var _adventure: Adventure
var _base_health := 0
var _texts: HeroMenu
var _gamepad_active := false
var _joypad_name := ""

var _root: Control
var _panels: Array[Control] = []
var _purse: Label
var _info: Array[Label] = []
var _hint: Label
@onready var _accept: AudioStreamPlayer = $Accept
@onready var _cancel: AudioStreamPlayer = $Cancel
@onready var _move: AudioStreamPlayer = $Move
@onready var _coins: AudioStreamPlayer = $Coins


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and is_open():
		_refresh()


## Opens `merchant_id`'s goods. `texts` lends the hero's menu's way of describing items and what
## they change; `base_health` is the hero's health before equipment (for that comparison).
func open(adventure: Adventure, merchant_id: StringName, base_health: int, texts: HeroMenu) -> void:
	if _root == null:
		_build()
	_adventure = adventure
	merchant = merchant_id
	_base_health = base_health
	_texts = texts
	column = Column.GOODS
	step = Step.BROWSE
	_cursor = [0, 0]
	_first = [0, 0]
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


## The ids one column lists: the goods on offer, or what the hero carries that this merchant takes.
func shown(on: Column) -> Array[StringName]:
	if _adventure == null:
		return []
	return Commerce.goods(_adventure, merchant) if on == Column.GOODS else Commerce.offers(_adventure, merchant)


## The id under the cursor on the column in use, or empty.
func selected() -> StringName:
	var ids := shown(column)
	var index := _cursor[column]
	return ids[index] if index < ids.size() else &""


func amount() -> int:
	return _amount


## The last thing said (already translated), or empty.
func notice() -> String:
	return _notice


## The two info lines as shown now (for tests).
func info_lines() -> Array[String]:
	return [_info[0].text, _info[1].text]


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not is_open() or event.is_echo():
		return
	var handled := true
	if event.is_action_pressed(&"equipment") or event.is_action_pressed(&"pause"):
		close()
		_cancel.play()
	elif event.is_action_pressed(&"ui_cancel"):
		_back()
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
	elif event.is_action_pressed(&"menu_prev") and step == Step.BROWSE:
		_turn(-1)
	elif event.is_action_pressed(&"menu_next") and step == Step.BROWSE:
		_turn(1)
	else:
		handled = false
		for action in HERO_ACTIONS:
			if event.is_action(action):
				handled = true  # never a swing, a dodge or a technique behind the merchant
	if handled:
		get_viewport().set_input_as_handled()


func _back() -> void:
	_cancel.play()
	match step:
		Step.CONFIRM:
			step = Step.AMOUNT if _available(selected()) > 1 and _most(selected()) > 1 else Step.BROWSE
			_refresh()
		Step.AMOUNT:
			step = Step.BROWSE
			_refresh()
		_:
			close()


## Up and down: the next good, or the amount by ten.
func _step(by_row: int, by_amount: int) -> void:
	if step == Step.AMOUNT:
		_set_amount(_amount - by_amount)  # up raises the amount
		return
	if step != Step.BROWSE:
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
	if step == Step.AMOUNT:
		_set_amount(_amount + by)
		return
	if step != Step.BROWSE:
		return
	column = Column.OFFERS if column == Column.GOODS else Column.GOODS
	_notice = ""
	_move.play()
	_refresh()


func _set_amount(value: int) -> void:
	var clamped := clampi(value, 1, maxi(_most(selected()), 1))
	if clamped == _amount:
		return
	_amount = clamped
	_move.play()
	_refresh()


func _confirm() -> void:
	var id := selected()
	if id.is_empty():
		return
	match step:
		Step.CONFIRM:
			_trade(id, _amount)
			return
		Step.AMOUNT:
			step = Step.CONFIRM
			_accept.play()
			_refresh()
			return
	var most := _most(id)
	if most == 0:
		_say(tr(REFUSALS.get(_check(id, 1), "")), true)
		_cancel.play()
		_refresh()
		return
	_amount = 1
	_notice = ""
	step = Step.AMOUNT if _available(id) > 1 and most > 1 else Step.CONFIRM
	_accept.play()
	_refresh()


## How many of `id` there are to trade on the column in use (-1: the merchant's never run out).
func _available(id: StringName) -> int:
	if column == Column.GOODS:
		var left := Commerce.remaining(_adventure, merchant, id)
		return Commerce.MOST_AT_ONCE if left < 0 else left
	return Storage.loose(_adventure, id)


func _check(id: StringName, count: int) -> Commerce.Result:
	return Commerce.check_buy(_adventure, merchant, id, count) if column == Column.GOODS \
			else Commerce.check_sell(_adventure, merchant, id, count)


## The most of `id` that can be traded from the column in use now.
func _most(id: StringName) -> int:
	if id.is_empty():
		return 0
	return Commerce.most_to_buy(_adventure, merchant, id) if column == Column.GOODS \
			else Commerce.most_to_sell(_adventure, merchant, id)


func _trade(id: StringName, count: int) -> void:
	var result := Commerce.buy(_adventure, merchant, id, count) if column == Column.GOODS \
			else Commerce.sell(_adventure, merchant, id, count)
	step = Step.BROWSE
	if result == Commerce.Result.DONE:
		var key := "TRADE_BOUGHT" if column == Column.GOODS else "TRADE_SOLD"
		_say(tr(key) % [_name(id), count, _total(id, count)], false)
		_coins.play()
		for on in [Column.GOODS, Column.OFFERS]:
			_keep_cursor(on, id)
	else:
		_say(tr(REFUSALS.get(result, "")), true)
		_cancel.play()
	_refresh()


## Coppers `count` of `id` cost (goods) or bring (offers).
func _total(id: StringName, count: int) -> int:
	return (Commerce.price(merchant, id) if column == Column.GOODS else Commerce.sell_price(id)) * count


## After a trade the cursor stays on `id` if the column still lists it; otherwise on the same row,
## or the last one.
func _keep_cursor(on: Column, id: StringName) -> void:
	var ids := shown(on)
	if on == column and ids.has(id):
		_cursor[on] = ids.find(id)
	_cursor[on] = clampi(_cursor[on], 0, maxi(ids.size() - 1, 0))


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
	_label(_root, "Title", Rect2(8, 4, 220, 10), GOLD)
	_purse = _label(_root, "Purse", Rect2(228, 4, 72, 10), LIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
	_coin(_root, Vector2(302, 5))
	for s in 2:
		var panel := _patch(_root, "Goods" if s == Column.GOODS else "Offers", BOX, Rect2(8 + s * 156, 18, 148, 116), 6)
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
			_label(row, "Name", Rect2(20, 3, 90, 10), DARK, 0, false)
			_label(row, "Price", Rect2(112, 3, 16, 10), DARK, HORIZONTAL_ALIGNMENT_RIGHT, false)
			_coin(row, Vector2(130, 4)).name = "Coin"
	_info.append(_label(_root, "Info", Rect2(8, 137, 304, 10), LIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	_info.append(_label(_root, "Detail", Rect2(8, 149, 304, 10), LIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	_hint = _label(_root, "Hint", Rect2(4, 166, 312, 10), DIM, HORIZONTAL_ALIGNMENT_CENTER)


## The copper mark beside a price (7x7, drawn for the game).
func _coin(parent: Node, at: Vector2) -> TextureRect:
	var coin := TextureRect.new()
	coin.texture = COIN
	coin.position = at
	coin.size = Vector2(7, 7)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(coin)
	return coin


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
	(_root.get_node(^"Title") as Label).text = tr(Commerce.name_of(merchant))
	_purse.text = tr("TRADE_PURSE") % _adventure.money
	var headers := [tr("TRADE_GOODS"), tr("TRADE_OFFERS") % [Bag.spaces_used(_adventure), Bag.CAPACITY]]
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
			var price_label := row.get_node(^"Price") as Label
			(row.get_node(^"Chosen") as CanvasItem).visible = s == column and index == _cursor[s]
			if index >= ids.size():
				(row.get_node(^"Icon") as TextureRect).texture = null
				name_label.text = tr("TRADE_NOTHING" if s == Column.GOODS else "TRADE_NOTHING_TO_SELL") \
						if r == 0 and ids.is_empty() else ""
				_colour(name_label, DIM)
				price_label.text = ""
				(row.get_node(^"Coin") as CanvasItem).visible = false
				continue
			var id := ids[index]
			var item := ItemCatalog.find(id)
			(row.get_node(^"Icon") as TextureRect).texture = item.icon if item != null else null
			(row.get_node(^"Coin") as CanvasItem).visible = true
			var dim := false
			if s == Column.GOODS:
				name_label.text = _name(id)
				price_label.text = str(Commerce.price(merchant, id))
				dim = Commerce.remaining(_adventure, merchant, id) == 0
			else:
				var loose := Storage.loose(_adventure, id)
				name_label.text = "%s x%d" % [_name(id), loose] if loose > 1 else _name(id)
				price_label.text = str(Commerce.sell_price(id))
				dim = loose == 0
			_colour(name_label, DIM if dim else DARK)
			_colour(price_label, DIM if dim else DARK)
	_refresh_info()


func _refresh_info() -> void:
	var id := selected()
	var hints: Array = []
	match step:
		Step.AMOUNT:
			_info[0].text = tr("TRADE_AMOUNT") % [_amount, _most(id), _total(id, _amount)]
			_info[1].text = _name(id)
			_colour(_info[0], LIGHT)
			_colour(_info[1], DIM)
			hints = [["MENU_HINT_CHOOSE", [&"interact"]], ["STORAGE_HINT_AMOUNT", [&"move_left", &"move_right"]],
					["MENU_HINT_BACK", [&"ui_cancel"]]]
		Step.CONFIRM:
			var key := "TRADE_CONFIRM_BUY" if column == Column.GOODS else "TRADE_CONFIRM_SELL"
			_info[0].text = tr(key) % [_name(id), _amount, _total(id, _amount)]
			_info[1].text = tr("TRADE_PURSE_AFTER") % (_adventure.money + (-1 if column == Column.GOODS else 1) * _total(id, _amount))
			_colour(_info[0], GOLD)
			_colour(_info[1], LIGHT)
			hints = [["TRADE_HINT_YES", [&"interact"]], ["MENU_HINT_BACK", [&"ui_cancel"]]]
		_:
			var lines := _about(id)
			_info[0].text = _notice if not _notice.is_empty() else lines[0][0]
			_colour(_info[0], WORSE if _notice_bad and not _notice.is_empty() else LIGHT)
			_info[1].text = lines[1][0]
			_colour(_info[1], lines[1][1])
			if not id.is_empty():
				hints.append(["TRADE_HINT_BUY" if column == Column.GOODS else "TRADE_HINT_SELL", [&"interact"]])
			hints.append(["TRADE_HINT_SIDE", [&"move_left", &"move_right"]])
			hints.append(["MENU_HINT_CLOSE", [&"ui_cancel"]])
	_hint.text = _hints(hints)


## Two lines about `id`: its name with the price and what is left (or what the hero has), and what
## it does: for equipment, what it would change on the hero.
func _about(id: StringName) -> Array:
	if id.is_empty():
		return [["", LIGHT], ["", LIGHT]]
	var item := ItemCatalog.find(id)
	var first := ""
	if column == Column.GOODS:
		var left := Commerce.remaining(_adventure, merchant, id)
		var stock := tr("TRADE_SOLD_OUT_MARK") if left == 0 else (tr("TRADE_LEFT") % left if left > 0 else "")
		first = "%s  %s  %s" % [_name(id), tr("TRADE_PRICE") % Commerce.price(merchant, id), stock]
	else:
		first = "%s  %s  %s" % [_name(id), tr("TRADE_PAYS") % Commerce.sell_price(id), tr("TRADE_YOU_HAVE") % _adventure.count(id)]
	return [[first.strip_edges(), LIGHT], _effect(item)]


## What `item` does, in one line: what wearing it would change (equipment the hero could still get),
## or what it is for.
func _effect(item: ItemDef) -> Array:
	if item == null or _texts == null:
		return ["", LIGHT]
	if item.is_equippable() and column == Column.GOODS:
		var before := HeroLoadout.profile(_adventure, _base_health)
		var trial := Adventure.from_dict(_adventure.to_dict())
		trial.add_item(item.id)
		trial.equip(Equipment.slot_for(trial, item), item.id)
		var lines := _texts.compare_lines(before, HeroLoadout.profile(trial, _base_health))
		var parts: PackedStringArray = []
		for line: Array in lines.slice(0, 2):
			parts.append(line[0])
		# the menu's colours are for its light panels; over the dark backdrop, lighter ones
		var colour: Color = lines[0][1]
		var shown := UP if colour == HeroMenu.BETTER else (WORSE if colour == HeroMenu.WORSE else
				(DIM if colour == HeroMenu.DIM else LIGHT))
		return ["   ".join(parts), shown]
	var effects := _texts.effect_lines(item)
	return ["   ".join(effects.slice(0, 2)), LIGHT]


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
		var text := InputPrompts.format_template(tr(part[0]), keys)
		if keys.size() == 2 and keys[0] == keys[1]:
			text = text.replace("%s/%s" % keys, keys[0])  # one D-pad, not "D-pad/D-pad"
		texts.append(text)
	return "   ".join(texts)


func _colour(label: Label, colour: Color) -> void:
	label.add_theme_color_override(&"font_color", colour)
