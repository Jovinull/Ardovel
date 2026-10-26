class_name Settings
extends RefCounted
## Player preferences that belong to the machine, not to an adventure (for now only the
## language), kept in a small ConfigFile apart from the save slot.

## Languages the game is written in, the authoring one first (also the fallback).
const LOCALES: Array[String] = ["pt_BR", "en"]
const SECTION := "general"

## Where the preferences live. The test run points this elsewhere (tests/hooks/pre_run.gd).
static var default_path := "user://settings.cfg"

var path: String
## Chosen language, or empty when the player never chose one.
var locale: String = ""


func _init(file_path: String = "") -> void:
	path = file_path if not file_path.is_empty() else default_path


## Reads the file; a missing, unreadable or unknown value leaves the preference unset.
func load_settings() -> void:
	var file := ConfigFile.new()
	var chosen: Variant = file.get_value(SECTION, "locale", "") if file.load(path) == OK else ""
	locale = chosen if chosen is String and LOCALES.has(chosen) else ""


func save() -> Error:
	var file := ConfigFile.new()
	file.set_value(SECTION, "locale", locale)
	return file.save(path)


## The language to show: the chosen one, else the system's when the game has it, else the
## authoring language.
func effective_locale(system_locale: String = OS.get_locale()) -> String:
	if not locale.is_empty():
		return locale
	for candidate in LOCALES:
		if candidate == system_locale or candidate == system_locale.get_slice("_", 0):
			return candidate
	return LOCALES[0]


## The language after `current` in LOCALES, wrapping around.
static func next_locale(current: String) -> String:
	return LOCALES[(LOCALES.find(current) + 1) % LOCALES.size()]
