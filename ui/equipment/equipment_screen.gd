class_name EquipmentScreen
extends CanvasLayer
## The hero's equipment: the accessory slot, the items they have, and the chosen item's name,
## icon, description, effect and whether it is worn. It opens over a frozen area (the game decides
## when it may); equipping goes through the adventure, so the hero's statistics follow at once and
## the change is saved. While open it takes the keys that would close it before anything else sees
## them, so the pause key closes it without also opening the pause menu.

signal closed

## Item cells shown under the slot.
const CELLS := 3
const STATE_WORN_COLOR := Color("2d697b")
const STATE_IDLE_COLOR := Color("695953")

var _adventure: Adventure
var _items: Array[ItemDef] = []
var _selected: int = 0
var _gamepad_active: bool = false
var _joypad_name: String = ""

@onready var _root: Control = $Root
@onready var _slot_label: Label = %SlotLabel
@onready var _slot_icon: TextureRect = %SlotIcon
@onready var _slot_empty: Label = %SlotEmpty
@onready var _cells: Control = %Cells
@onready var _name: Label = %ItemName
@onready var _description: Label = %Description
@onready var _effect: Label = %Effect
@onready var _state: Label = %State
@onready var _hint: Label = %Hint


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.hide()
	set_process_input(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and is_open():
		_refresh()


func open(adventure: Adventure) -> void:
	_adventure = adventure
	_items.clear()
	for id in adventure.items():
		var item := ItemCatalog.find(id)
		if item != null:
			_items.append(item)
	_selected = 0
	for i in _items.size():
		if adventure.equipped(_items[i].slot) == _items[i].id:
			_selected = i
			break
	_refresh()
	_root.show()
	set_process_input(true)


func close() -> void:
	if not is_open():
		return
	_root.hide()
	set_process_input(false)
	closed.emit()


func is_open() -> bool:
	return _root.visible


func selected_item() -> ItemDef:
	return _items[_selected] if _selected < _items.size() else null


func set_input_mode(gamepad: bool, joypad_name: String) -> void:
	_gamepad_active = gamepad
	_joypad_name = joypad_name
	if is_node_ready() and is_open():
		_refresh()


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(&"equipment") or event.is_action_pressed(&"ui_cancel") \
			or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		_toggle_selected()
	elif event.is_action_pressed(&"move_left") or event.is_action_pressed(&"move_up"):
		get_viewport().set_input_as_handled()
		_select(_selected - 1)
	elif event.is_action_pressed(&"move_right") or event.is_action_pressed(&"move_down"):
		get_viewport().set_input_as_handled()
		_select(_selected + 1)
	elif event.is_action_pressed(&"attack"):
		get_viewport().set_input_as_handled()


func _select(index: int) -> void:
	if _items.is_empty():
		return
	_selected = clampi(index, 0, _items.size() - 1)
	_refresh()


## Puts the chosen item on, or takes it off if it is already worn.
func _toggle_selected() -> void:
	var item := selected_item()
	if item == null or not item.is_equippable():
		return
	if _adventure.equipped(item.slot) == item.id:
		_adventure.unequip(item.slot)
	else:
		_adventure.equip(item.slot, item.id)
	_refresh()


func _refresh() -> void:
	_slot_label.text = tr(ItemCatalog.slot_name_key(ItemCatalog.ACCESSORY))
	var worn := ItemCatalog.find(_adventure.equipped(ItemCatalog.ACCESSORY))
	_slot_icon.texture = worn.icon if worn != null else null
	_slot_empty.visible = worn == null
	for i in CELLS:
		var cell := _cells.get_child(i)
		(cell.get_node(^"Icon") as TextureRect).texture = _items[i].icon if i < _items.size() else null
		(cell.get_node(^"Selected") as CanvasItem).visible = i == _selected and i < _items.size()
	var item := selected_item()
	var close_label := InputPrompts.action_label(&"equipment", _gamepad_active, _joypad_name)
	if item == null:
		_name.text = tr("EQUIPMENT_NO_ITEMS")
		_description.text = ""
		_effect.text = ""
		_state.text = ""
		_hint.text = InputPrompts.format_template(tr("EQUIPMENT_HINT_CLOSE"), [close_label])
		return
	var is_worn := _adventure.equipped(item.slot) == item.id
	_name.text = tr(item.name_key)
	_description.text = tr(item.description_key)
	_effect.text = tr(item.effect_key)
	_state.text = tr("EQUIPMENT_WORN" if is_worn else "EQUIPMENT_NOT_WORN")
	_state.add_theme_color_override(&"font_color", STATE_WORN_COLOR if is_worn else STATE_IDLE_COLOR)
	var use_label := InputPrompts.action_label(&"interact", _gamepad_active, _joypad_name)
	var hint_key := "EQUIPMENT_HINT_REMOVE" if is_worn else "EQUIPMENT_HINT_EQUIP"
	_hint.text = InputPrompts.format_template(tr(hint_key), [use_label, close_label])
