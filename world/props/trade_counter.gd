class_name TradeCounter
extends Node2D
## Where a merchant's goods are kept: a stall or a counter. Using it says what it is (`closed_text`
## until `opens_with`, then `text`) and, once open, asks for the merchant's goods (Game opens them
## once the text is read). Talking to the merchant stays talking: their lines and their work are
## never interrupted by the trade.

## Asks for the trade with `merchant` (Game opens it once the text is read).
signal trade_requested(merchant: StringName)

## Commerce id of the goods kept here.
@export var merchant: StringName
## Open only once this flag is set (empty: always).
@export var opens_with: StringName
## What it says while open, and while not yet (translation keys).
@export var text: String
@export var closed_text: String

var _adventure: Adventure

@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	add_to_group(&"adventure")
	_interactable.action = _on_interact


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure


func is_open() -> bool:
	return _adventure != null and (opens_with.is_empty() or _adventure.has_flag(opens_with))


func _on_interact(_actor: Node2D) -> String:
	if not is_open():
		return closed_text
	trade_requested.emit(merchant)
	return text
