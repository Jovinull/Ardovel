class_name DialogueLine
extends Resource
## One thing a character can say, depending on the adventure's flags. A blank line in `text`
## starts a new page of the dialogue box.

## Said only once this flag is set (empty: no requirement).
@export var requires: StringName
## Not said once this flag is set (empty: no restriction).
@export var unless: StringName
@export_multiline var text: String
## Flag set when this line is said (empty: none).
@export var sets: StringName


func applies(adventure: Adventure) -> bool:
	if adventure == null:
		return requires.is_empty()
	if not requires.is_empty() and not adventure.has_flag(requires):
		return false
	return unless.is_empty() or not adventure.has_flag(unless)
