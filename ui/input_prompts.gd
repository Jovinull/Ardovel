class_name InputPrompts
extends RefCounted
## Human-readable labels generated from the active input map.


static func pause_label(gamepad: bool, joypad_name: String = "") -> String:
	return action_label(&"pause", gamepad, joypad_name)


static func cancel_label(gamepad: bool, joypad_name: String = "") -> String:
	return action_label(&"ui_cancel", gamepad, joypad_name)


static func dismiss_label(gamepad: bool, joypad_name: String) -> String:
	return action_label(&"interact", gamepad, joypad_name)


static func restart_label(gamepad: bool, joypad_name: String = "") -> String:
	return action_label(&"restart", gamepad, joypad_name)


static func action_label(action: StringName, gamepad: bool, joypad_name: String = "") -> String:
	var labels: Array[String] = []
	for event in InputMap.action_get_events(action):
		if gamepad and not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
			continue
		if not gamepad and not event is InputEventKey:
			continue
		var label := _event_label(event, joypad_name)
		if not label.is_empty() and not labels.has(label):
			labels.append(label)
	return " / ".join(labels)


static func _primary_action_label(action: StringName, gamepad: bool, joypad_name: String) -> String:
	var labels := action_label(action, gamepad, joypad_name).split(" / ", false)
	return labels[0] if not labels.is_empty() else ""


static func title_hint(gamepad: bool, joypad_name: String) -> String:
	var values: Array[String] = [
		_movement_label(gamepad, joypad_name),
		_primary_action_label(&"ui_accept", gamepad, joypad_name),
	]
	var key := "TITLE_INPUT_GAMEPAD" if gamepad else "TITLE_INPUT_KEYBOARD"
	return format_template(_tr(key), values)


static func controls_text(gamepad: bool, joypad_name: String) -> String:
	var movement := _movement_label(gamepad, joypad_name)
	var navigation := _navigation_label(gamepad, joypad_name)
	var menu_key := "CONTROL_MENU_GAMEPAD" if gamepad else "CONTROL_MENU_KEYBOARD"
	var rows: Array[String] = [
		format_template(_tr("CONTROL_MOVE_GAMEPAD" if gamepad else "CONTROL_MOVE_KEYBOARD"), [movement]),
		format_template(_tr("CONTROL_SWORD_GAMEPAD" if gamepad else "CONTROL_SWORD_KEYBOARD"),
			[action_label(&"attack", gamepad, joypad_name)]),
		format_template(_tr("CONTROL_INTERACT_GAMEPAD" if gamepad else "CONTROL_INTERACT_KEYBOARD"),
			[action_label(&"interact", gamepad, joypad_name)]),
		format_template(_tr("CONTROL_EQUIPMENT_GAMEPAD" if gamepad else "CONTROL_EQUIPMENT_KEYBOARD"),
			[action_label(&"equipment", gamepad, joypad_name)]),
		format_template(_tr(menu_key), [
			navigation,
			pause_label(gamepad, joypad_name),
			cancel_label(gamepad, joypad_name),
		]),
	]
	return "\n".join(rows)


## Formats only the placeholders present, keeping future hint text without placeholders safe.
static func format_template(template: String, values: Array[String]) -> String:
	var placeholder_count := template.count("%s")
	if placeholder_count == 0 or placeholder_count > values.size():
		return template
	var used_values: Array[String] = []
	for index in placeholder_count:
		used_values.append(values[index])
	return template % used_values


static func _movement_label(gamepad: bool, joypad_name: String, vertical_only: bool = false) -> String:
	var actions: Array[StringName] = [&"move_up", &"move_down"]
	if not vertical_only:
		actions.append_array([&"move_left", &"move_right"])
	if gamepad:
		return _combined_action_label(actions, true, joypad_name)
	var labels: Array[String] = []
	var symbols: Dictionary[StringName, String] = {
		&"move_up": "Up",
		&"move_down": "Down",
		&"move_left": "Left",
		&"move_right": "Right",
	}
	for action in actions:
		var bindings := action_label(action, false)
		if not bindings.is_empty():
			var key_labels := bindings.split(" / ", false)
			key_labels.erase(symbols[action])
			var alternate_keys := " / ".join(key_labels)
			labels.append(symbols[action] + ("/" + alternate_keys if not alternate_keys.is_empty() else ""))
	return " ".join(labels)


static func _navigation_label(gamepad: bool, joypad_name: String) -> String:
	return _movement_label(gamepad, joypad_name, true)


static func _combined_action_label(actions: Array[StringName], gamepad: bool, joypad_name: String) -> String:
	var labels: Array[String] = []
	for action in actions:
		for event in InputMap.action_get_events(action):
			if gamepad and not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
				continue
			if not gamepad and not event is InputEventKey:
				continue
			var label := _event_label(event, joypad_name)
			if not label.is_empty() and not labels.has(label):
				labels.append(label)
	return " / ".join(labels)


static func _event_label(event: InputEvent, joypad_name: String) -> String:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var key_code := key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
		var label := OS.get_keycode_string(key_code)
		if label.is_empty():
			return ""
		var modifiers: Array[String] = []
		if key_event.ctrl_pressed:
			modifiers.append("Ctrl")
		if key_event.alt_pressed:
			modifiers.append("Alt")
		if key_event.shift_pressed:
			modifiers.append("Shift")
		if key_event.meta_pressed:
			modifiers.append("Meta")
		modifiers.append(label)
		return "+".join(modifiers)
	if event is InputEventJoypadButton:
		return _joypad_button_label((event as InputEventJoypadButton).button_index, joypad_name)
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
			return _tr("CONTROL_LEFT_STICK")
		if motion.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
			return _tr("CONTROL_RIGHT_STICK")
	return ""


static func _joypad_button_label(button_index: int, joypad_name: String) -> String:
	match button_index:
		JOY_BUTTON_A: return _face_button_name(&"south", joypad_name)
		JOY_BUTTON_B: return _face_button_name(&"east", joypad_name)
		JOY_BUTTON_X: return _face_button_name(&"west", joypad_name)
		JOY_BUTTON_Y: return _face_button_name(&"north", joypad_name)
		JOY_BUTTON_BACK: return _tr("CONTROL_BUTTON_BACK")
		JOY_BUTTON_GUIDE: return _tr("CONTROL_BUTTON_GUIDE")
		JOY_BUTTON_START: return _tr("CONTROL_BUTTON_START")
		JOY_BUTTON_LEFT_STICK: return "L3"
		JOY_BUTTON_RIGHT_STICK: return "R3"
		JOY_BUTTON_LEFT_SHOULDER: return "L1"
		JOY_BUTTON_RIGHT_SHOULDER: return "R1"
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
			return _tr("CONTROL_DPAD")
	return _tr("CONTROL_BUTTON_OTHER") % str(button_index + 1)


static func _face_button_name(position: StringName, joypad_name: String) -> String:
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
