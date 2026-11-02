class_name DialogueLine
extends Resource
## One thing a character can say, depending on the adventure's flags. `text` is a translation
## key; a blank line in the translated text starts a new page of the dialogue box.

## Said only once this flag is set (empty: no requirement).
@export var requires: StringName
## A second flag that must be set as well (empty: none), for lines that depend on two events.
@export var also_requires: StringName
## Not said once this flag is set (empty: no restriction).
@export var unless: StringName
## A second flag that also silences it (empty: none): for a gift, the old pickup that gave the same.
@export var also_unless: StringName
@export var text: String
## Flag set when this line is said (empty: none). A gift's flag is set only once it is given.
@export var sets: StringName
## A gift handed over with the line (an ItemCatalog id; empty: none), and how many.
@export var gives: StringName
@export var gives_count: int = 1


## The first of `lines` that applies, or null: lists put the most specific line first.
static func first_that_applies(lines: Array[DialogueLine], adventure: Adventure) -> DialogueLine:
	for line in lines:
		if line.applies(adventure):
			return line
	return null


func applies(adventure: Adventure) -> bool:
	if adventure == null:
		return requires.is_empty() and also_requires.is_empty()
	if not requires.is_empty() and not adventure.has_flag(requires):
		return false
	if not also_requires.is_empty() and not adventure.has_flag(also_requires):
		return false
	if not also_unless.is_empty() and adventure.has_flag(also_unless):
		return false
	return unless.is_empty() or not adventure.has_flag(unless)
