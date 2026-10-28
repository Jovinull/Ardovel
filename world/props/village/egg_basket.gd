class_name EggBasket
extends Node2D
## Eggs Cida leaves at Anselmo's door once her hens sleep in his coop. Only found on a later
## visit, never appearing in front of the hero.

const SETTLED_FLAG := &"village_hens_settled"


func _ready() -> void:
	add_to_group(&"adventure")
	visible = false
	$Interactable.enabled = false
	$Interactable.action = func(_actor: Node2D) -> String: return "EGG_BASKET"


func bind_adventure(adventure: Adventure) -> void:
	visible = adventure.has_flag(SETTLED_FLAG)
	$Interactable.enabled = visible
