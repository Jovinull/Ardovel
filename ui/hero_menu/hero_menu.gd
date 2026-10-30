class_name HeroMenu
extends CanvasLayer
## The hero's menu, over a frozen area: three pages, changed with the page keys.
##
## Equipment: the nine slots grouped by what they are for (weapons, protection, rings and the
## accessory); choosing a slot lists the pieces that fit it and compares each with what is worn
## (the hero's statistics now and after the change). Beside the weapons the hero turns slowly as
## they look now, or, while choosing, as they would look with the piece under the cursor (the same
## frames the hero is drawn with in play, HeroLook). Inventory: everything the hero has, by
## category, in a grid that scrolls, with quantities and what is worn marked; a piece is equipped
## or taken off, and food is put in the quick slot (it is eaten in the world, where eating takes
## time and a blow interrupts it, never here with the world held still). Status: the statistics
## that are real in play.
##
## It shows and changes only through the adventure and the rules (Equipment, Bag, HeroLoadout);
## nothing is computed here. While open it takes the keys that would close it before anything else
## sees them, so the pause key never also opens the pause menu.

signal closed

enum Page { EQUIPMENT, INVENTORY, STATUS }
enum Sort { FOUND, NAME, CATEGORY, WEIGHT }

const BOX := preload("res://assets/ninja_adventure/Ui/Dialog/DialogueBoxSimple.png")
const FRAME := preload("res://assets/ninja_adventure/Ui/Dialog/FacesetBox.png")
const CHOICE := preload("res://assets/ninja_adventure/Ui/Dialog/ChoiceBox.png")
const PAGE_KEYS: Array[String] = ["MENU_PAGE_EQUIPMENT", "MENU_PAGE_INVENTORY", "MENU_PAGE_STATUS"]
## Equipment page: the slot groups, top to bottom.
const GROUPS: Array = [
	["MENU_GROUP_WEAPONS", [ItemCatalog.MAIN_HAND, ItemCatalog.OFF_HAND]],
	["MENU_GROUP_ARMOR", [ItemCatalog.HEAD, ItemCatalog.TORSO, ItemCatalog.HANDS, ItemCatalog.LEGS]],
	["MENU_GROUP_RINGS", [ItemCatalog.RING_1, ItemCatalog.RING_2, ItemCatalog.ACCESSORY]],
]
## Inventory tabs: key and the categories each shows (empty: all).
const TABS: Array = [
	["MENU_TAB_ALL", []],
	["MENU_TAB_WEAPONS", [ItemCatalog.WEAPON, ItemCatalog.SHIELD]],
	["MENU_TAB_ARMOR", [ItemCatalog.ARMOR]],
	["MENU_TAB_RINGS", [ItemCatalog.RING, ItemCatalog.TRINKET]],
	["MENU_TAB_CONSUMABLES", [ItemCatalog.CONSUMABLE]],
	["MENU_TAB_MATERIALS", [ItemCatalog.MATERIAL]],
]
const SORT_KEYS: Array[String] = ["MENU_SORT_FOUND", "MENU_SORT_NAME", "MENU_SORT_CATEGORY", "MENU_SORT_WEIGHT"]
const SLOT_NAMES: Dictionary[StringName, String] = {
	ItemCatalog.MAIN_HAND: "SLOT_MAIN_HAND", ItemCatalog.OFF_HAND: "SLOT_OFF_HAND", ItemCatalog.HEAD: "SLOT_HEAD",
	ItemCatalog.TORSO: "SLOT_TORSO", ItemCatalog.HANDS: "SLOT_HANDS", ItemCatalog.LEGS: "SLOT_LEGS",
	ItemCatalog.RING_1: "SLOT_RING_1", ItemCatalog.RING_2: "SLOT_RING_2", ItemCatalog.ACCESSORY: "SLOT_ACCESSORY",
}
const CATEGORY_NAMES: Dictionary[StringName, String] = {
	ItemCatalog.WEAPON: "CATEGORY_WEAPON", ItemCatalog.SHIELD: "CATEGORY_SHIELD", ItemCatalog.ARMOR: "CATEGORY_ARMOR",
	ItemCatalog.RING: "CATEGORY_RING", ItemCatalog.TRINKET: "CATEGORY_ACCESSORY",
	ItemCatalog.CONSUMABLE: "CATEGORY_CONSUMABLE", ItemCatalog.MATERIAL: "CATEGORY_MATERIAL",
}
const STAT_NAMES: Dictionary[StringName, String] = {
	HeroStats.MAX_HEALTH: "STAT_MAX_HEALTH", HeroStats.ATTACK: "STAT_ATTACK", HeroStats.KNOCKBACK: "STAT_KNOCKBACK",
	HeroStats.REACH: "STAT_REACH", HeroStats.SWING: "STAT_SWING", HeroStats.DEFENSE: "STAT_DEFENSE",
	HeroStats.POISE: "STAT_POISE", HeroStats.LOAD: "STAT_LOAD", HeroStats.SPEED: "STAT_SPEED",
	HeroStats.HEALING: "STAT_HEALING",
}
const BAND_NAMES: Dictionary[StringName, String] = {
	HeroStats.LIGHT: "BAND_LIGHT", HeroStats.NORMAL: "BAND_NORMAL", HeroStats.HEAVY: "BAND_HEAVY",
	HeroStats.OVERLOADED: "BAND_OVERLOADED",
}
const GRID_COLUMNS := 7
const GRID_ROWS := 5
const CELL := 20
const LIST_ROWS := 4
## The preview turns to the next side this often (seconds); down, left, up, right.
const PREVIEW_TURN := 1.2
const PREVIEW_SIDES: Array[int] = [0, 2, 1, 3]
const LIGHT := Color("f2eaf1")
const DARK := Color("3b3643")
const DIM := Color("948a9c")
const GOLD := Color("f1c471")
const TEAL := Color("2d697b")
const WINE := Color("8f3e56")
const BETTER := Color("2d697b")
const WORSE := Color("e0394c")

var page: Page = Page.EQUIPMENT
## Equipment page: the slot under the cursor (group, index in it) and, while choosing, the list.
var _group := 0
var _slot_index := 0
var _choosing := false
var _choices: Array[StringName] = []
var _choice := 0
## Inventory page.
var _tab := 0
var _sort: Sort = Sort.FOUND
var _cell := 0
var _scroll := 0
var _adventure: Adventure
var _base_health := 12
var _health: Health
var _notice := ""
var _gamepad_active := false
var _joypad_name := ""

var _root: Control
var _pages: Array[Control] = []
var _tab_row: Control
var _hint: Label
var _slot_cells: Dictionary[StringName, Control] = {}
var _info: Control
var _summary: Control
var _list: Control
var _inv_tabs: Control
var _grid: Control
var _inv_info: Control
var _bag: Label
var _status: Control
var _preview: TextureRect
var _preview_look: HeroLook
var _preview_side := 0
var _preview_time := 0.0
@onready var _accept: AudioStreamPlayer = $Accept
@onready var _cancel: AudioStreamPlayer = $Cancel
@onready var _move: AudioStreamPlayer = $Move


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(false)


func _process(delta: float) -> void:
	if not is_open() or page != Page.EQUIPMENT:
		return
	_preview_time += delta
	if _preview_time >= PREVIEW_TURN:
		_preview_time = 0.0
		_preview_side = (_preview_side + 1) % PREVIEW_SIDES.size()
		_show_preview(_preview_look)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and is_open():
		_refresh()


## Opens on `start` for `adventure`, whose hero has `base_health` quarters before equipment and
## `health` now.
func open(adventure: Adventure, base_health: int, health: Health, start: Page = Page.EQUIPMENT) -> void:
	if _root == null:
		_build()  # on first use: a few hundred controls nobody needs before
	_adventure = adventure
	_base_health = base_health
	_health = health
	_choosing = false
	_notice = ""
	page = start
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


func is_choosing() -> bool:
	return _choosing


func set_input_mode(gamepad: bool, joypad_name: String) -> void:
	_gamepad_active = gamepad
	_joypad_name = joypad_name
	if is_node_ready() and is_open():
		_refresh()


## The slot under the cursor on the equipment page.
func selected_slot() -> StringName:
	return GROUPS[_group][1][_slot_index]


## The id under the cursor in the list of pieces for a slot (empty: "take it off").
func selected_choice() -> StringName:
	return _choices[_choice] if _choice < _choices.size() else &""


## The ids the inventory shows now, in order.
func shown_items() -> Array[StringName]:
	var categories: Array = TABS[_tab][1]
	var ids: Array[StringName] = []
	for id in _adventure.items():
		var item := ItemCatalog.find(id)
		if item != null and (categories.is_empty() or categories.has(item.category)):
			ids.append(id)
	match _sort:
		Sort.NAME:
			ids.sort_custom(func(a: StringName, b: StringName) -> bool: return _name(a) < _name(b))
		Sort.CATEGORY:
			ids.sort_custom(func(a: StringName, b: StringName) -> bool:
				var ca := ItemCatalog.CATEGORIES.find(ItemCatalog.find(a).category)
				var cb := ItemCatalog.CATEGORIES.find(ItemCatalog.find(b).category)
				return ca < cb if ca != cb else _name(a) < _name(b))
		Sort.WEIGHT:
			ids.sort_custom(func(a: StringName, b: StringName) -> bool:
				var wa := ItemCatalog.find(a).weight
				var wb := ItemCatalog.find(b).weight
				return wa > wb if wa != wb else _name(a) < _name(b))
	return ids


## The id under the cursor in the inventory, or empty.
func selected_item() -> StringName:
	var ids := shown_items()
	return ids[_cell] if _cell < ids.size() else &""


func tab() -> int:
	return _tab


func sort_mode() -> Sort:
	return _sort


func notice() -> String:
	return _notice


## How the preview shows the hero now.
func preview_look() -> HeroLook:
	return _preview_look


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not is_open() or event.is_echo():
		return
	var handled := true
	if event.is_action_pressed(&"equipment") or event.is_action_pressed(&"pause"):
		close()
		_cancel.play()
	elif event.is_action_pressed(&"ui_cancel"):
		if _choosing:
			_choosing = false
			_cancel.play()
			_refresh()
		else:
			close()
			_cancel.play()
	elif event.is_action_pressed(&"menu_prev"):
		_turn_page(-1)
	elif event.is_action_pressed(&"menu_next"):
		_turn_page(1)
	elif event.is_action_pressed(&"category_prev") and page == Page.INVENTORY:
		_set_tab(_tab - 1)
	elif event.is_action_pressed(&"category_next") and page == Page.INVENTORY:
		_set_tab(_tab + 1)
	elif event.is_action_pressed(&"menu_sort") and page == Page.INVENTORY:
		_sort = ((_sort + 1) % Sort.size()) as Sort
		_cell = 0
		_scroll = 0
		_move.play()
		_refresh()
	elif event.is_action_pressed(&"interact"):
		_confirm()
	elif event.is_action_pressed(&"move_up"):
		_step(Vector2i.UP)
	elif event.is_action_pressed(&"move_down"):
		_step(Vector2i.DOWN)
	elif event.is_action_pressed(&"move_left"):
		_step(Vector2i.LEFT)
	elif event.is_action_pressed(&"move_right"):
		_step(Vector2i.RIGHT)
	elif event.is_action_pressed(&"attack"):
		pass  # never a swing behind the menu
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _turn_page(by: int) -> void:
	page = posmod(page + by, Page.size()) as Page
	_choosing = false
	_notice = ""
	_move.play()
	_refresh()


func _set_tab(index: int) -> void:
	_tab = posmod(index, TABS.size())
	_cell = 0
	_scroll = 0
	_notice = ""
	_move.play()
	_refresh()


func _step(direction: Vector2i) -> void:
	_notice = ""
	match page:
		Page.EQUIPMENT:
			if _choosing:
				if direction.y != 0 and not _choices.is_empty():
					_choice = posmod(_choice + direction.y, _choices.size())
			elif direction.y != 0:
				_group = posmod(_group + direction.y, GROUPS.size())
				_slot_index = mini(_slot_index, GROUPS[_group][1].size() - 1)
			else:
				_slot_index = posmod(_slot_index + direction.x, GROUPS[_group][1].size())
		Page.INVENTORY:
			var count := shown_items().size()
			if count == 0:
				return
			var next := _cell + direction.x + direction.y * GRID_COLUMNS
			if next < 0 or next >= count:
				return
			_cell = next
			var row := _cell / GRID_COLUMNS
			if row < _scroll:
				_scroll = row
			elif row >= _scroll + GRID_ROWS:
				_scroll = row - GRID_ROWS + 1
		Page.STATUS:
			return
	_move.play()
	_refresh()


func _confirm() -> void:
	_notice = ""
	match page:
		Page.EQUIPMENT:
			if not _choosing:
				_choices = _choices_for(selected_slot())
				_choice = maxi(_choices.find(_adventure.equipped(selected_slot())), 0)
				_choosing = true
				_accept.play()
			else:
				_apply_choice()
		Page.INVENTORY:
			_use_selected()
	_refresh()


## Pieces for `slot`: "take it off" first when that is allowed, then every piece that fits.
func _choices_for(slot: StringName) -> Array[StringName]:
	var choices: Array[StringName] = []
	if not _adventure.equipped(slot).is_empty() and slot != ItemCatalog.MAIN_HAND:
		choices.append(&"")
	choices.append_array(Equipment.candidates(_adventure, slot))
	return choices


func _apply_choice() -> void:
	var slot := selected_slot()
	var id := selected_choice()
	var done := false
	if id.is_empty():
		done = Equipment.unequip(_adventure, slot)
		if not done:
			_notice = "MENU_BAG_FULL"
	elif _adventure.equipped(slot) == id:
		done = true
	else:
		done = Equipment.equip(_adventure, slot, id)
		if not done:
			_notice = "MENU_WORN_ELSEWHERE"
	if done:
		_choosing = false
		_accept.play()
	else:
		_cancel.play()


func _use_selected() -> void:
	var id := selected_item()
	var item := ItemCatalog.find(id)
	if item == null:
		return
	if item.is_usable():
		_adventure.set_quick_item(id)
		_notice = "MENU_QUICK_SET"
		_accept.play()
	elif item.is_equippable():
		var worn_in := _slot_holding(id)
		var done := false
		if not worn_in.is_empty():
			done = Equipment.unequip(_adventure, worn_in)
			_notice = "" if done else ("MENU_MAIN_HAND" if worn_in == ItemCatalog.MAIN_HAND else "MENU_BAG_FULL")
		else:
			done = Equipment.equip(_adventure, Equipment.slot_for(_adventure, item), id)
		if done:
			_accept.play()
		else:
			_cancel.play()
	else:
		_notice = "MENU_NO_USE_YET"
		_cancel.play()


## The first slot holding `id`, or empty.
func _slot_holding(id: StringName) -> StringName:
	for slot in ItemCatalog.SLOTS:
		if _adventure.equipped(slot) == id:
			return slot
	return &""


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
	_tab_row = _control(_root, "Pages", Rect2(0, 0, 320, 20))
	for i in 3:
		var tab := _control(_tab_row, "Page%d" % i, Rect2())
		_patch(tab, "Chosen", CHOICE, Rect2(), 4)
		_label(tab, "Label", Rect2(), DIM)
	_label(_tab_row, "Keys", Rect2(250, 7, 62, 10), DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_hint = _label(_root, "Hint", Rect2(4, 166, 312, 10), DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_build_equipment()
	_build_inventory()
	_build_status()


func _build_equipment() -> void:
	var equipment := _control(_root, "Equipment", Rect2(0, 0, 320, 180))
	_pages.append(equipment)
	var y := 22
	for g in GROUPS.size():
		_label(equipment, "Group%d" % g, Rect2(10, y, 110, 10), GOLD)
		var slots: Array = GROUPS[g][1]
		for i in slots.size():
			_slot_cells[slots[i]] = _cell_node(equipment, String(slots[i]), Vector2(10 + i * 26, y + 11), 22)
		y += 44
	_info = _patch(equipment, "Info", BOX, Rect2(124, 22, 188, 76), 6)
	_label(_info, "Slot", Rect2(8, 6, 172, 10), TEAL, 0, false)
	_label(_info, "Name", Rect2(8, 16, 172, 10), WINE, 0, false)
	_label(_info, "Effect", Rect2(8, 28, 172, 40), DARK, 0, false, true)
	_list = _patch(equipment, "List", BOX, Rect2(124, 22, 188, 76), 6)
	for r in LIST_ROWS:
		var row := _control(_list, "Row%d" % r, Rect2(4, 4 + r * 17, 180, 17))
		_patch(row, "Chosen", CHOICE, Rect2(0, 0, 180, 17), 4)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.position = Vector2(3, 0)
		icon.size = Vector2(16, 16)
		row.add_child(icon)
		_label(row, "Label", Rect2(22, 4, 154, 10), DARK, 0, false)
	_label(_list, "More", Rect2(130, 62, 50, 10), DIM, HORIZONTAL_ALIGNMENT_RIGHT, false)
	var preview := _patch(equipment, "Preview", FRAME, Rect2(80, 25, 38, 38), 5)
	_preview = TextureRect.new()
	_preview.name = "Hero"
	_preview.position = Vector2(3, 3)
	_preview.size = Vector2(32, 32)
	_preview.stretch_mode = TextureRect.STRETCH_SCALE
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(_preview)
	_summary = _patch(equipment, "Summary", BOX, Rect2(124, 102, 188, 60), 6)
	for r in 5:
		_label(_summary, "Line%d" % r, Rect2(8, 5 + r * 10, 174, 10), DARK, 0, false)


func _build_inventory() -> void:
	var inventory := _control(_root, "Inventory", Rect2(0, 0, 320, 180))
	_pages.append(inventory)
	_inv_tabs = _control(inventory, "Tabs", Rect2(0, 21, 320, 14))
	for i in TABS.size():
		var tab := _control(_inv_tabs, "Tab%d" % i, Rect2())
		_patch(tab, "Chosen", CHOICE, Rect2(), 4)
		_label(tab, "Label", Rect2(), DIM)
	_grid = _control(inventory, "Grid", Rect2(8, 38, GRID_COLUMNS * CELL, GRID_ROWS * CELL))
	for i in GRID_COLUMNS * GRID_ROWS:
		var cell := _cell_node(_grid, "Cell%d" % i, Vector2((i % GRID_COLUMNS) * CELL, (i / GRID_COLUMNS) * CELL), CELL)
		_label(cell, "Count", Rect2(0, 10, CELL - 1, 10), LIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
		_pip(cell)
	_label(inventory, "Scroll", Rect2(8, 140, 40, 10), DIM)
	_label(inventory, "Sort", Rect2(48, 140, 100, 10), DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_bag = _label(inventory, "Bag", Rect2(8, 152, 140, 10), LIGHT)
	_inv_info = _patch(inventory, "Info", BOX, Rect2(152, 38, 160, 124), 6)
	_label(_inv_info, "Name", Rect2(8, 6, 144, 10), WINE, 0, false)
	_label(_inv_info, "Kind", Rect2(8, 16, 144, 10), TEAL, 0, false)
	_label(_inv_info, "Description", Rect2(8, 28, 144, 40), DARK, 0, false, true)
	_label(_inv_info, "Effect", Rect2(8, 70, 144, 30), TEAL, 0, false, true)
	_label(_inv_info, "Notice", Rect2(8, 104, 144, 10), WORSE, 0, false)


func _build_status() -> void:
	_status = _control(_root, "Status", Rect2(0, 0, 320, 180))
	_pages.append(_status)
	var panels := [["MENU_STATUS_LIFE", Rect2(8, 24, 148, 64), 4], ["MENU_STATUS_COMBAT", Rect2(164, 24, 148, 64), 4],
			["MENU_STATUS_LOAD", Rect2(8, 94, 304, 64), 4]]
	for p in panels.size():
		var box := _patch(_status, "Panel%d" % p, BOX, panels[p][1], 6)
		_label(box, "Title", Rect2(8, 5, 140, 10), TEAL, 0, false)
		for r in panels[p][2]:
			var width: float = panels[p][1].size.x - 16
			_label(box, "Name%d" % r, Rect2(8, 17 + r * 10, width, 10), DARK, 0, false)
			_label(box, "Value%d" % r, Rect2(8, 17 + r * 10, width, 10), DARK, HORIZONTAL_ALIGNMENT_RIGHT, false)


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


func _label(parent: Node, node_name: String, rect: Rect2, colour: Color, align: int = 0, shadow: bool = true,
		wrap: bool = false) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = align
	label.add_theme_color_override(&"font_color", colour)
	if not shadow:
		label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0))
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


## A small gold mark in a cell's corner: this one is worn.
func _pip(cell: Control) -> void:
	var edge := ColorRect.new()
	edge.name = "Worn"
	edge.color = Color("141b1b")
	edge.position = Vector2(1, 1)
	edge.size = Vector2(5, 5)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(edge)
	var pip := ColorRect.new()
	pip.color = GOLD
	pip.position = Vector2(1, 1)
	pip.size = Vector2(3, 3)
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.add_child(pip)


## A framed cell for one item: frame, chosen frame, icon.
func _cell_node(parent: Node, node_name: String, at: Vector2, size: int) -> Control:
	var cell := _control(parent, node_name, Rect2(at, Vector2(size, size)))
	_patch(cell, "Frame", FRAME, Rect2(0, 0, size, size), 5)
	_patch(cell, "Chosen", CHOICE, Rect2(0, 0, size, size), 5)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2((size - 16) / 2, (size - 16) / 2)
	icon.size = Vector2(16, 16)
	cell.add_child(icon)
	return cell


# ---------------------------------------------------------------- showing

func _refresh() -> void:
	if _adventure == null:
		return
	for i in _pages.size():
		_pages[i].visible = i == page
	_refresh_page_tabs()
	match page:
		Page.EQUIPMENT:
			_refresh_equipment()
		Page.INVENTORY:
			_refresh_inventory()
		Page.STATUS:
			_refresh_status()


func _refresh_page_tabs() -> void:
	var x := 8.0
	for i in 3:
		var tab := _tab_row.get_node("Page%d" % i) as Control
		var label := tab.get_node(^"Label") as Label
		label.text = tr(PAGE_KEYS[i])
		var width := label.get_minimum_size().x + 12
		tab.position = Vector2(x, 4)
		tab.size = Vector2(width, 14)
		(tab.get_node(^"Chosen") as NinePatchRect).size = tab.size
		(tab.get_node(^"Chosen") as CanvasItem).visible = i == page
		label.position = Vector2(6, 3)
		label.size = Vector2(width - 12, 10)
		_colour(label, DARK if i == page else DIM, i != page)
		x += width + 2
	(_tab_row.get_node(^"Keys") as Label).text = "%s/%s" % [_key(&"menu_prev"), _key(&"menu_next")]


func _refresh_equipment() -> void:
	var profile := _profile()
	for g in GROUPS.size():
		(_pages[0].get_node("Group%d" % g) as Label).text = tr(GROUPS[g][0])
	for slot in _slot_cells:
		var item := ItemCatalog.find(_adventure.equipped(slot))
		var cell := _slot_cells[slot]
		(cell.get_node(^"Icon") as TextureRect).texture = item.icon if item != null else null
		(cell.get_node(^"Chosen") as CanvasItem).visible = slot == selected_slot()
	var slot := selected_slot()
	_info.visible = not _choosing
	_list.visible = _choosing
	if not _choosing:
		var worn := ItemCatalog.find(_adventure.equipped(slot))
		(_info.get_node(^"Slot") as Label).text = tr(SLOT_NAMES[slot])
		(_info.get_node(^"Name") as Label).text = tr(worn.name_key) if worn != null else tr("MENU_EMPTY")
		var lines := effect_lines(worn)
		if worn != null:
			lines.append(tr("MENU_WEIGHT") % _number(worn.weight, 1))
		(_info.get_node(^"Effect") as Label).text = "\n".join(lines)
		_summary_lines(_stat_summary(profile))
		_show_preview(profile.look())
		_hint.text = _hints([["MENU_HINT_CHOOSE", [&"interact"]], ["MENU_HINT_CLOSE", [&"equipment"]]])
	else:
		_choice = clampi(_choice, 0, maxi(_choices.size() - 1, 0))
		var first := clampi(_choice - LIST_ROWS + 1, 0, maxi(_choices.size() - LIST_ROWS, 0))
		first = mini(first, _choice)
		for r in LIST_ROWS:
			var row := _list.get_node("Row%d" % r) as Control
			var index := first + r
			row.visible = index < _choices.size()
			if not row.visible:
				continue
			var id := _choices[index]
			var item := ItemCatalog.find(id)
			(row.get_node(^"Chosen") as CanvasItem).visible = index == _choice
			(row.get_node(^"Icon") as TextureRect).texture = item.icon if item != null else null
			var text := tr("MENU_TAKE_OFF") if id.is_empty() else tr(item.name_key)
			if not id.is_empty() and _adventure.equipped_copies(id) > 0:
				text += " " + tr("MENU_WORN_MARK")
			(row.get_node(^"Label") as Label).text = text
		(_list.get_node(^"More") as Label).text = "%d/%d" % [_choice + 1, _choices.size()] if _choices.size() > LIST_ROWS else ""
		var choice := selected_choice()
		var after := HeroLoadout.profile_if(_adventure, _base_health, slot, choice)
		_summary_lines(compare_lines(profile, after))
		_show_preview(after.look())
		_hint.text = _hints([["MENU_HINT_EQUIP" if not choice.is_empty() else "MENU_HINT_TAKE_OFF", [&"interact"]],
				["MENU_HINT_BACK", [&"ui_cancel"]]])
	if not _notice.is_empty():
		_hint.text = tr(_notice)


## The hero standing as `look` draws them, on the side the preview has turned to.
func _show_preview(look: HeroLook) -> void:
	_preview_look = look
	if look == null:
		return
	var frame := _preview.texture as AtlasTexture
	if frame == null:
		frame = AtlasTexture.new()
		_preview.texture = frame
	frame.atlas = look.walk
	frame.region = Rect2(PREVIEW_SIDES[_preview_side] * 16, 0, 16, 16)


func _summary_lines(lines: Array) -> void:
	for r in 5:
		var label := _summary.get_node("Line%d" % r) as Label
		if r < lines.size():
			label.text = lines[r][0]
			_colour(label, lines[r][1], false)
		else:
			label.text = ""


func _refresh_inventory() -> void:
	var x := 8.0
	for i in TABS.size():
		var tab := _inv_tabs.get_node("Tab%d" % i) as Control
		var label := tab.get_node(^"Label") as Label
		label.text = tr(TABS[i][0])
		var width := label.get_minimum_size().x + 8
		tab.position = Vector2(x, 0)
		tab.size = Vector2(width, 14)
		(tab.get_node(^"Chosen") as NinePatchRect).size = tab.size
		(tab.get_node(^"Chosen") as CanvasItem).visible = i == _tab
		label.position = Vector2(4, 3)
		label.size = Vector2(width - 8, 10)
		_colour(label, DARK if i == _tab else DIM, i != _tab)
		x += width + 1
	var ids := shown_items()
	_cell = clampi(_cell, 0, maxi(ids.size() - 1, 0))
	for i in GRID_COLUMNS * GRID_ROWS:
		var cell := _grid.get_node("Cell%d" % i) as Control
		var index := _scroll * GRID_COLUMNS + i
		var id: StringName = ids[index] if index < ids.size() else &""
		var item := ItemCatalog.find(id)
		(cell.get_node(^"Icon") as TextureRect).texture = item.icon if item != null else null
		(cell.get_node(^"Chosen") as CanvasItem).visible = index == _cell and item != null
		var count := _adventure.count(id)
		(cell.get_node(^"Count") as Label).text = str(count) if count > 1 else ""
		(cell.get_node(^"Worn") as CanvasItem).visible = item != null and _adventure.equipped_copies(id) > 0
	var rows := ceili(float(ids.size()) / GRID_COLUMNS)
	(_pages[1].get_node(^"Scroll") as Label).text = tr("MENU_ROWS") % [mini(_scroll + GRID_ROWS, maxi(rows, 1)), maxi(rows, 1)] if rows > GRID_ROWS else ""
	_bag.text = tr("MENU_BAG") % [Bag.spaces_used(_adventure), Bag.CAPACITY]
	(_pages[1].get_node(^"Sort") as Label).text = "%s %s" % [_key(&"menu_sort"), tr(SORT_KEYS[_sort])]
	var id := selected_item()
	var item := ItemCatalog.find(id)
	(_inv_info.get_node(^"Name") as Label).text = tr(item.name_key) if item != null else tr("MENU_NOTHING")
	var kind := ""
	if item != null:
		kind = tr(CATEGORY_NAMES.get(item.category, ""))
		if _adventure.count(id) > 1:
			kind += "  x%d" % _adventure.count(id)
		if item.is_usable() and _adventure.quick_item == id:
			kind += "  " + tr("MENU_QUICK_MARK")
		if item.is_equippable():
			kind += "  " + tr("MENU_WEIGHT") % _number(item.weight, 1)
	(_inv_info.get_node(^"Kind") as Label).text = kind
	(_inv_info.get_node(^"Description") as Label).text = tr(item.description_key) if item != null else ""
	(_inv_info.get_node(^"Effect") as Label).text = "\n".join(effect_lines(item)) if item != null else ""
	(_inv_info.get_node(^"Notice") as Label).text = tr(_notice) if not _notice.is_empty() else ""
	var action := ""
	if item != null:
		if item.is_usable():
			action = "MENU_HINT_QUICK"
		elif item.is_equippable() and _slot_holding(id) != ItemCatalog.MAIN_HAND:
			action = "MENU_HINT_TAKE_OFF" if _adventure.equipped_copies(id) > 0 else "MENU_HINT_EQUIP"
	var hints: Array = []
	if not action.is_empty():
		hints.append([action, [&"interact"]])
	hints.append(["MENU_HINT_TABS", [&"category_prev", &"category_next"]])
	hints.append(["MENU_HINT_CLOSE", [&"equipment"]])
	_hint.text = _hints(hints)


func _refresh_status() -> void:
	var profile := _profile()
	var panels := [
		["MENU_STATUS_LIFE", [
			["STAT_MAX_HEALTH", _hearts(profile.max_health())],
			["STAT_HEALTH_NOW", _hearts(_health.current if _health != null else profile.max_health())],
			["STAT_DEFENSE", "%d%%" % roundi(profile.value(HeroStats.DEFENSE))],
			["STAT_POISE", "%d%%" % roundi(profile.value(HeroStats.POISE))]]],
		["MENU_STATUS_COMBAT", [
			["STAT_ATTACK", str(profile.attack.damage)],
			["STAT_KNOCKBACK", str(roundi(profile.attack.knockback))],
			["STAT_REACH", str(roundi(profile.attack.reach))],
			["STAT_SWING", tr("MENU_SECONDS") % _number(profile.swing_seconds(), 2)]]],
		["MENU_STATUS_LOAD", [
			["STAT_LOAD", "%s / %s  (%d%%)" % [_number(profile.carried, 1), _number(profile.value(HeroStats.LOAD), 1),
					roundi(profile.load_ratio() * 100.0)]],
			["STAT_MOBILITY", "%s  %d%%" % [tr(BAND_NAMES[profile.band]), roundi(profile.speed_factor() * 100.0)]],
			["STAT_HEALING", "+%d%%" % roundi(profile.value(HeroStats.HEALING))],
			["STAT_BAG", "%d / %d" % [Bag.spaces_used(_adventure), Bag.CAPACITY]]]],
	]
	for p in panels.size():
		var box := _status.get_node("Panel%d" % p) as Control
		(box.get_node(^"Title") as Label).text = tr(panels[p][0])
		for r in 4:
			(box.get_node("Name%d" % r) as Label).text = tr(panels[p][1][r][0])
			(box.get_node("Value%d" % r) as Label).text = panels[p][1][r][1]
	_hint.text = _hints([["MENU_HINT_PAGES", [&"menu_prev", &"menu_next"]], ["MENU_HINT_CLOSE", [&"equipment"]]])


# ---------------------------------------------------------------- texts

## What an item does, line by line, read from its data (so it never promises what it does not do).
func effect_lines(item: ItemDef) -> Array[String]:
	var lines: Array[String] = []
	if item == null:
		return lines
	if item.attack != null:
		lines.append("%s %d   %s %d" % [tr("STAT_ATTACK"), item.attack.damage, tr("STAT_KNOCKBACK"), roundi(item.attack.knockback)])
		lines.append("%s %d   %s %s" % [tr("STAT_REACH"), roundi(item.attack.reach), tr("STAT_SWING"),
				tr("MENU_SECONDS") % _number(item.attack.duration(), 2)])
	for modifier in item.modifiers:
		lines.append(_modifier_text(modifier))
	if item.heal > 0:
		lines.append(tr("MENU_HEALS") % _hearts(item.heal))
	if item.category == ItemCatalog.MATERIAL:
		lines.append(tr("MENU_NO_USE_YET"))
	return lines


func _modifier_text(modifier: StatModifier) -> String:
	var name := tr(STAT_NAMES.get(modifier.stat, ""))
	var value := modifier.value
	var sign := "+" if value >= 0 else "-"
	if modifier.stat == HeroStats.MAX_HEALTH and modifier.kind == StatModifier.Kind.ADD:
		return "%s %s%s" % [name, sign, _hearts(absi(roundi(value)))]
	var percent_stats := [HeroStats.DEFENSE, HeroStats.POISE, HeroStats.SPEED, HeroStats.HEALING, HeroStats.SWING]
	var suffix := "%" if modifier.kind == StatModifier.Kind.PERCENT or percent_stats.has(modifier.stat) else ""
	return "%s %s%s%s" % [name, sign, _number(absf(value), 0), suffix]


## The hero's main numbers, for the equipment page.
func _stat_summary(profile: HeroLoadout.Profile) -> Array:
	return [
		["%s %d   %s %d%%" % [tr("STAT_ATTACK"), profile.attack.damage, tr("STAT_DEFENSE"), roundi(profile.value(HeroStats.DEFENSE))], DARK],
		["%s %d   %s %d%%" % [tr("STAT_KNOCKBACK"), roundi(profile.attack.knockback), tr("STAT_POISE"), roundi(profile.value(HeroStats.POISE))], DARK],
		["%s %s/%s  %s" % [tr("STAT_LOAD"), _number(profile.carried, 1), _number(profile.value(HeroStats.LOAD), 1),
				tr(BAND_NAMES[profile.band])], DARK],
	]


## What would change: "name before -> after (+)" for every statistic that moves, then the load.
func compare_lines(before: HeroLoadout.Profile, after: HeroLoadout.Profile) -> Array:
	# name, before, after, how to show it, whether more is better
	var rows := [
		["STAT_ATTACK", before.attack.damage, after.attack.damage, "", true],
		["STAT_KNOCKBACK", before.attack.knockback, after.attack.knockback, "", true],
		["STAT_REACH", before.attack.reach, after.attack.reach, "", true],
		["STAT_SWING", before.swing_seconds(), after.swing_seconds(), "s", false],
		["STAT_MAX_HEALTH", before.max_health(), after.max_health(), "hearts", true],
		["STAT_DEFENSE", before.value(HeroStats.DEFENSE), after.value(HeroStats.DEFENSE), "%", true],
		["STAT_POISE", before.value(HeroStats.POISE), after.value(HeroStats.POISE), "%", true],
		["STAT_MOBILITY", before.speed_factor() * 100.0, after.speed_factor() * 100.0, "%", true],
		["STAT_HEALING", before.value(HeroStats.HEALING), after.value(HeroStats.HEALING), "%", true],
	]
	var lines: Array = []
	for row in rows:
		var a: float = row[1]
		var b: float = row[2]
		if is_equal_approx(a, b):
			continue
		var better: bool = (b > a) == row[4]
		lines.append(["%s %s > %s (%s)" % [tr(row[0]), _shown(a, row[3]), _shown(b, row[3]), "+" if better else "-"],
				BETTER if better else WORSE])
	var band_line := "%s %d%% > %d%% %s" % [tr("STAT_LOAD"), roundi(before.load_ratio() * 100.0), roundi(after.load_ratio() * 100.0),
			tr(BAND_NAMES[after.band])]
	var heavier := after.load_ratio() > before.load_ratio() + 0.001
	lines = lines.slice(0, 4)
	lines.append([band_line, WORSE if heavier and after.band != before.band else DARK])
	if lines.size() == 1:
		lines.push_front([tr("MENU_NO_CHANGE"), DIM])
	return lines


## A compared value as the menu shows it: hearts, seconds, a percentage or a whole number.
func _shown(value: float, unit: String) -> String:
	match unit:
		"hearts":
			return _hearts(roundi(value))
		"s":
			return tr("MENU_SECONDS") % _number(value, 2)
		"%":
			return "%d%%" % roundi(value)
	return str(roundi(value))


func _profile() -> HeroLoadout.Profile:
	return HeroLoadout.profile(_adventure, _base_health)


func _name(id: StringName) -> String:
	var item := ItemCatalog.find(id)
	return tr(item.name_key) if item != null else String(id)


func _hearts(quarters: int) -> String:
	return _number(quarters / 4.0, 0 if quarters % 4 == 0 else 2)


## A number with `decimals` decimals, with the language's decimal mark.
func _number(value: float, decimals: int) -> String:
	var text := ("%." + str(decimals) + "f") % value if decimals > 0 else str(roundi(value))
	return text.replace(".", ",") if TranslationServer.get_locale().begins_with("pt") else text


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


func _colour(label: Label, colour: Color, shadow: bool) -> void:
	label.add_theme_color_override(&"font_color", colour)
	label.add_theme_color_override(&"font_shadow_color", Color(0.0784314, 0.105882, 0.105882, 1) if shadow else Color(0, 0, 0, 0))
