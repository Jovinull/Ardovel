class_name InputPrompts
extends RefCounted
## Human-readable labels for the actions in the current input map.


static func pause_label(gamepad: bool) -> String:
	return "Start" if gamepad else "Esc"


static func dismiss_label(gamepad: bool, joypad_name: String) -> String:
	return _button_name(&"south", joypad_name) if gamepad else "E"


static func restart_label(gamepad: bool) -> String:
	return "Start" if gamepad else "Enter"


static func title_hint(gamepad: bool, joypad_name: String) -> String:
	if gamepad:
		return _tr("TITLE_INPUT_GAMEPAD") % _button_name(&"south", joypad_name)
	return _tr("TITLE_INPUT_KEYBOARD")


static func controls_text(gamepad: bool, joypad_name: String) -> String:
	if not gamepad:
		return "\n".join([
			_tr("CONTROL_MOVE_KEYBOARD"),
			_tr("CONTROL_SWORD_KEYBOARD"),
			_tr("CONTROL_INTERACT_KEYBOARD"),
			_tr("CONTROL_MENU_KEYBOARD"),
		])
	return "\n".join([
		_tr("CONTROL_MOVE_GAMEPAD"),
		_tr("CONTROL_SWORD_GAMEPAD") % _button_name(&"west", joypad_name),
		_tr("CONTROL_INTERACT_GAMEPAD") % _button_name(&"south", joypad_name),
		_tr("CONTROL_MENU_GAMEPAD"),
	])


static func _button_name(position: StringName, joypad_name: String) -> String:
	var device := joypad_name.to_lower()
	var family := "generic"
	if device.contains("playstation") or device.contains("sony") \
			or device.contains("dualshock") or device.contains("dualsense") \
			or device.contains("ps4") or device.contains("ps5"):
		family = "playstation"
	elif device.contains("nintendo") or device.contains("switch"):
		family = "nintendo"
	elif device.contains("xbox") or device.contains("xinput"):
		family = "xbox"

	match position:
		&"south":
			match family:
				"xbox": return "A"
				"playstation": return "Cross"
				"nintendo": return "B"
				_: return _tr("CONTROL_BUTTON_SOUTH")
		&"east":
			match family:
				"xbox": return "B"
				"playstation": return "Circle"
				"nintendo": return "A"
				_: return _tr("CONTROL_BUTTON_EAST")
		&"west":
			match family:
				"xbox": return "X"
				"playstation": return "Square"
				"nintendo": return "Y"
				_: return _tr("CONTROL_BUTTON_WEST")
		&"north":
			match family:
				"xbox": return "Y"
				"playstation": return "Triangle"
				"nintendo": return "X"
				_: return _tr("CONTROL_BUTTON_NORTH")
	return ""


static func _tr(key: String) -> String:
	return TranslationServer.translate(key)
