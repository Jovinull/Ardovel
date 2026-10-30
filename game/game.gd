class_name Game
extends Node
## Root of a play session. Owns the adventure state, its save slot, the player's settings and
## the current area: shows the title (and applies the chosen language), loads areas (one at a
## time, swapped behind a fade), sends the hero back to the checkpoint after a fall, and
## freezes the area while a dialogue, the equipment screen or the chest at home is open. Applies what the hero has
## earned to the hero (heart vessels, equipment). Also owns the brief hit-stop when the sword
## connects.

## Stable area ids (as written in saves and passages) and their scenes.
const AREAS: Dictionary[StringName, String] = {
	&"village": "res://world/village/village.tscn",
	&"forest": "res://world/forest/forest.tscn",
	&"ruin": "res://world/ruin/ruin.tscn",
	&"west": "res://world/west/west.tscn",
	&"far_bank": "res://world/far_bank/far_bank.tscn",
	&"road_slope": "res://world/road/road_slope.tscn",
	&"road_west": "res://world/spring/road_west.tscn",
	&"waystop": "res://world/blank/waystop.tscn",
	&"pedrabranca": "res://world/town/pedrabranca.tscn",
}
const FADE_TIME := 0.35
## How long an interlude's text stays on the black between two areas.
const INTERLUDE_TIME := 2.2
## Health a heart vessel adds: one whole heart (four quarters).
const HEART_VESSEL_HEALTH := 4
## The wayfarer sword's own hit-stop: `hit_stop_time` is what it freezes for.
const SWORD_HIT_STOP := 0.06
## Set the first time the equipment screen is opened (until then, a hint says how).
const EQUIPMENT_SEEN_FLAG := &"equipment_seen"
const MUSIC_VOLUME_DB := -8.0
const MUSIC_SILENT_DB := -40.0

## Seconds the world freezes when the sword connects. Real time, unaffected by the freeze itself.
@export var hit_stop_time: float = 0.06
## Save slot path; empty uses SaveFile.default_path.
@export var save_path: String = ""
## Settings file path; empty uses Settings.default_path.
@export var settings_path: String = ""
## Opens the title menu on start. Tests and tools turn this off and start adventures directly.
@export var show_title: bool = true

var adventure: Adventure
var level: Level
var save_slot: SaveFile
var settings: Settings
var _travelling: bool = false
var _save_queued: bool = false
var _hit_stop_token: int = 0
var _gamepad_active: bool = false
var _active_joypad: int = -1
var _joypad_name: String = ""
## The hero's maximum health before heart vessels (as set in the player scene).
var _base_max_health: int = 0
## What the hero's equipment and heart vessels make of them (see HeroLoadout).
var _profile: HeroLoadout.Profile
## What the profile was last built from, so unrelated changes (a flag) do not rebuild it.
var _profile_source: String = ""

@onready var _hud: Hud = $HUD
@onready var _death_screen: DeathScreen = $DeathScreen
@onready var _title: TitleScreen = $TitleScreen
@onready var _pause: PauseScreen = $PauseScreen
@onready var _equipment: HeroMenu = $HeroMenu
@onready var _storage: StorageMenu = $StorageMenu
@onready var _fade: ColorRect = %Fade
@onready var _interlude: Label = %Interlude
@onready var _music: AudioStreamPlayer = $Music


func _ready() -> void:
	save_slot = SaveFile.new(save_path)
	settings = Settings.new(settings_path)
	settings.load_settings()
	TranslationServer.set_locale(settings.effective_locale())
	_death_screen.restart_requested.connect(respawn)
	_hud.dialogue_started.connect(_set_area_frozen.bind(true))
	_hud.dialogue_finished.connect(_set_area_frozen.bind(false))
	_title.continue_requested.connect(continue_saved)
	_title.new_requested.connect(start_new)
	_title.language_requested.connect(switch_language)
	_title.quit_requested.connect(get_tree().quit)
	_pause.resume_requested.connect(_resume_from_pause)
	_pause.language_requested.connect(switch_language)
	_pause.title_requested.connect(_return_to_title)
	_pause.quit_requested.connect(_quit_safely)
	_equipment.closed.connect(_set_area_frozen.bind(false))
	_storage.closed.connect(_set_area_frozen.bind(false))
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	var connected_joypads := Input.get_connected_joypads()
	if not connected_joypads.is_empty():
		_active_joypad = connected_joypads[0]
		_gamepad_active = true
		_joypad_name = Input.get_joy_name(_active_joypad)
	_update_input_prompts()
	if show_title:
		open_title()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		_set_active_joypad(event.device)
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) >= 0.5:
		_set_active_joypad(event.device)
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		_set_keyboard_active()


func _exit_tree() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	HeroLook.forget()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"equipment") and can_open_equipment():
		open_equipment()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed(&"pause") or _title.is_open() or _pause.is_open():
		return
	if level == null or _travelling or _death_screen.is_open() or _hud.is_message_visible():
		return
	_pause.open()
	_set_paused(true)
	get_viewport().set_input_as_handled()


## The hero's menu (equipment, inventory, status) opens only while the hero is free to move: not during a trip, a
## dialogue, the witch's map, a pause, a swing, a stagger or a fall.
func can_open_equipment() -> bool:
	if level == null or adventure == null or _travelling or _title.is_open() or _pause.is_open():
		return false
	if _equipment.is_open() or _storage.is_open() or _death_screen.is_open() or _hud.is_message_visible():
		return false
	return level.process_mode != Node.PROCESS_MODE_DISABLED and level.player.state == Player.State.MOVE


func open_equipment() -> void:
	if not can_open_equipment():
		return
	_set_area_frozen(true)
	_equipment.open(adventure, base_health(), level.player.health)
	adventure.set_flag(EQUIPMENT_SEEN_FLAG)


func is_equipment_open() -> bool:
	return _equipment.is_open()


func hero_menu() -> HeroMenu:
	return _equipment


## Opens the chest at home (asked for by the chest), on the same terms as the hero's menu.
func open_storage() -> void:
	if not can_open_equipment():
		return
	_set_area_frozen(true)
	_storage.open(adventure)


func is_storage_open() -> bool:
	return _storage.is_open()


func storage_menu() -> StorageMenu:
	return _storage


func open_title() -> void:
	var saved := save_slot.load_adventure()
	var notice := ""
	match save_slot.status:
		SaveFile.Status.RECOVERED:
			notice = "SAVE_RECOVERED"
		SaveFile.Status.CORRUPT, SaveFile.Status.INCOMPATIBLE:
			notice = "SAVE_UNREADABLE"
	_title.open(saved != null and AREAS.has(saved.area), save_slot.exists(), notice)


## Shows the game in the next language and remembers the choice.
func switch_language() -> void:
	settings.locale = Settings.next_locale(settings.effective_locale())
	var error := settings.save()
	if error != OK:
		push_warning("Could not save the settings: %s" % error_string(error))
	TranslationServer.set_locale(settings.locale)


## Starts a fresh adventure in the village and saves it right away.
func start_new() -> void:
	_begin(Adventure.new())
	save_now()


## Resumes the saved adventure where it was left (its resume point). False if there is nothing
## usable.
func continue_saved() -> bool:
	var saved := save_slot.load_adventure()
	if saved == null or not AREAS.has(saved.area):
		return false
	_begin(saved)
	return true


## Travels to `entry` of `area` behind a fade. Ignored while travelling or after the hero fell.
func travel(area: StringName, entry: StringName) -> void:
	if _travelling or not AREAS.has(area) or level.player.health.is_dead():
		return
	_travelling = true
	adventure.health = level.player.health.current
	level.process_mode = Node.PROCESS_MODE_DISABLED
	var interlude := level.interlude
	await _fade_to(1.0)
	if not interlude.is_empty():
		await _show_interlude(interlude)
	_load_area(area, entry)
	adventure.enter(area, entry)
	await _fade_to(0.0)
	_travelling = false


func is_showing_interlude() -> bool:
	return _interlude.visible


## Text on the black between two areas: something that happened on the road.
func _show_interlude(text: String) -> void:
	_interlude.text = text
	_interlude.visible = true
	await get_tree().create_timer(INTERLUDE_TIME).timeout
	_interlude.visible = false


## Back to safety with full health, everything earned kept: to the checkpoint (the last shrine
## awakened, wherever it is), or before any shrine to the entry the hero last arrived through.
func respawn() -> void:
	if _travelling:
		return
	_travelling = true
	await _fade_to(1.0)
	_death_screen.close()
	var area := adventure.area
	var entry := adventure.entry
	if adventure.has_checkpoint() and AREAS.has(adventure.checkpoint_area):
		area = adventure.checkpoint_area
		entry = adventure.checkpoint_entry
	elif adventure.has_checkpoint():
		push_warning("Checkpoint area %s is unknown; returning to %s." % [adventure.checkpoint_area, area])
	adventure.health = Adventure.FULL_HEALTH
	_load_area(area, entry)
	adventure.enter(area, entry)
	save_now()
	await _fade_to(0.0)
	_travelling = false


func save_now() -> Error:
	_save_queued = false
	if adventure == null:
		return OK
	if level != null and not level.player.health.is_dead():
		adventure.health = level.player.health.current
	var error := save_slot.save(adventure)
	if error != OK:
		push_warning("Could not save the adventure: %s" % error_string(error))
	return error


func is_travelling() -> bool:
	return _travelling


## Freezes the world briefly when the hero's blow lands: `hit_stop_time` for the wayfarer sword,
## and in proportion for other weapons (a maul holds twice as long, a machete less).
func hit_stop() -> void:
	if hit_stop_time <= 0.0:
		return
	var seconds := hit_stop_time
	if level != null and level.player.weapon_attack() != null:
		seconds *= level.player.weapon_attack().hit_stop / SWORD_HIT_STOP
	_hit_stop_token += 1
	var token := _hit_stop_token
	Engine.time_scale = 0.0
	await get_tree().create_timer(seconds, true, false, true).timeout
	# A later hit may have extended the freeze; only the latest one releases it.
	if token == _hit_stop_token:
		Engine.time_scale = 1.0


func _begin(state: Adventure) -> void:
	_set_paused(false)
	_pause.close()
	_equipment.close()
	_storage.close()
	Engine.time_scale = 1.0
	adventure = state
	for id in adventure.items():
		if not ItemCatalog.knows(id):
			push_warning("The save has an item this game does not know (%s); it is kept but unused." % id)
	adventure.changed.connect(_queue_save)
	adventure.changed.connect(_apply_equipment)
	adventure.changed.connect(_refresh_quick_slot)
	adventure.changed.connect(_refresh_first_step_guidance)
	_title.close()
	_fade.modulate.a = 1.0
	_load_area(adventure.area, adventure.entry)
	_fade_to(0.0)


func _load_area(area: StringName, entry: StringName) -> void:
	if level != null:
		remove_child(level)
		level.queue_free()
	level = (load(AREAS[area]) as PackedScene).instantiate()
	level.name = "Level"
	add_child(level)
	move_child(level, 0)
	level.bind_adventure(adventure)
	if not level.place_player(entry):
		push_warning("Area %s has no entry %s; using the scene's start." % [area, entry])
	var player := level.player
	_base_max_health = player.health.max_health
	_profile_source = ""
	_apply_equipment()
	if adventure.health == Adventure.FULL_HEALTH:
		player.health.restore_full()
	else:
		player.health.current = clampi(adventure.health, 1, player.health.max_health)
	player.died.connect(_death_screen.open)
	player.hit_landed.connect(hit_stop)
	player.can_quick_use = can_quick_use
	player.quick_use_finished.connect(_finish_quick_use)
	_refresh_quick_slot()
	level.exit_requested.connect(travel)
	_hud.bind_player(player)
	_refresh_first_step_guidance()
	_hud.hide_boss()
	for node in level.find_children("*", "", true, false):
		if node is BossArena:
			var arena := node as BossArena
			arena.fight_started.connect(_on_boss_fight_started.bind(arena))
			arena.fight_won.connect(_on_boss_fight_won)
		elif node is ItemPickup and (node as ItemPickup).keeps_storage:
			(node as ItemPickup).storage_requested.connect(open_storage)
	_play_music(level.music)


func _on_boss_fight_started(arena: BossArena) -> void:
	_hud.show_boss(arena.boss_name, arena.warden.health)
	_play_music(arena.music)


func _on_boss_fight_won() -> void:
	_hud.hide_boss()
	_play_music(level.music)


func _resume_from_pause() -> void:
	_pause.close()
	_set_paused(false)


func _return_to_title() -> void:
	if adventure == null or level == null or _travelling:
		return
	if save_now() != OK:
		_pause.show_notice("PAUSE_SAVE_FAILED")
		return
	_set_paused(false)
	_pause.close()
	_equipment.close()
	_storage.close()
	_death_screen.close()
	_hud.hide_boss()
	_music.stop()
	_hud.set_guidance("")
	remove_child(level)
	level.queue_free()
	level = null
	adventure = null
	open_title()


func _quit_safely() -> void:
	if save_now() != OK:
		_pause.show_notice("PAUSE_SAVE_FAILED")
		return
	_pause.close()
	_set_paused(false)
	get_tree().quit()


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused


func _set_active_joypad(device: int) -> void:
	_gamepad_active = true
	_active_joypad = device
	_joypad_name = Input.get_joy_name(device) if device >= 0 else ""
	_update_input_prompts()


func _set_keyboard_active() -> void:
	_gamepad_active = false
	_active_joypad = -1
	_joypad_name = ""
	_update_input_prompts()


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	# A connection is not input: keep prompts for the device the player last used.
	if connected or device != _active_joypad:
		return
	var connected_joypads := Input.get_connected_joypads()
	if connected_joypads.is_empty():
		_gamepad_active = false
		_active_joypad = -1
		_joypad_name = ""
	else:
		_active_joypad = connected_joypads[0]
		_joypad_name = Input.get_joy_name(_active_joypad)
	_update_input_prompts()


func _update_input_prompts() -> void:
	_hud.set_input_mode(_gamepad_active, _joypad_name)
	_death_screen.set_input_mode(_gamepad_active)
	_title.set_input_mode(_gamepad_active, _joypad_name)
	_pause.set_input_mode(_gamepad_active, _joypad_name)
	_equipment.set_input_mode(_gamepad_active, _joypad_name)
	_storage.set_input_mode(_gamepad_active, _joypad_name)


func _refresh_first_step_guidance() -> void:
	if adventure == null:
		_hud.set_guidance("")
		return
	var needs_first_step := not adventure.has_flag(&"heard_of_shrine") \
			and not adventure.has_flag(&"forest_shrine_awakened")
	if needs_first_step:
		_hud.set_guidance("FIRST_STEP_GUIDANCE")
	elif adventure.items().size() > 1 and not adventure.has_flag(EQUIPMENT_SEEN_FLAG):
		_hud.set_guidance("EQUIPMENT_GUIDANCE", [&"equipment", &"interact"])
	else:
		_hud.set_guidance("")


## The hero's health before equipment: the player scene's plus the heart vessels found.
func base_health() -> int:
	var vessels := adventure.flags().filter(
			func(flag: StringName) -> bool: return String(flag).begins_with(HeartVessel.FLAG_PREFIX)).size()
	return _base_max_health + vessels * HEART_VESSEL_HEALTH


## What the hero's equipment and heart vessels make of them now.
func hero_profile() -> HeroLoadout.Profile:
	return _profile


## Rebuilds the hero's profile and gives it to the hero when what it depends on has changed (the
## equipment, or a heart vessel found).
func _apply_equipment() -> void:
	if level == null or adventure == null:
		return
	var source := "%s|%d" % [adventure.equipment(), base_health()]
	if source == _profile_source:
		return
	_profile_source = source
	_profile = HeroLoadout.profile(adventure, base_health())
	HeroLoadout.apply(_profile, level.player)


## Uses one `id` from the bag on the hero (a consumable). False if nothing happened.
func use_item(id: StringName) -> bool:
	if level == null or _profile == null:
		return false
	return HeroLoadout.use(adventure, _profile, level.player.health, id)


## The food the quick-use key eats: the one chosen in the menu while there is some left, else the
## first food the hero has (empty: none).
func quick_item() -> StringName:
	if adventure == null:
		return &""
	if adventure.count(adventure.quick_item) > 0 and ItemCatalog.find(adventure.quick_item) != null \
			and ItemCatalog.find(adventure.quick_item).is_usable():
		return adventure.quick_item
	for id in adventure.items():
		var item := ItemCatalog.find(id)
		if item != null and item.is_usable():
			return id
	return &""


## Eating takes time in the world: possible only with food in the quick slot and health missing.
func can_quick_use() -> bool:
	if level == null or quick_item().is_empty():
		return false
	var health := level.player.health
	return not health.is_dead() and health.current < health.max_health


func _finish_quick_use() -> void:
	use_item(quick_item())


func _refresh_quick_slot() -> void:
	if adventure == null or level == null:
		return
	var id := quick_item()
	var item := ItemCatalog.find(id)
	level.player.set_held_item(item.icon if item != null else null)
	_hud.show_quick_item(item.icon if item != null else null, adventure.count(id))


func _play_music(stream: AudioStream) -> void:
	if stream == _music.stream and _music.playing:
		return
	_music.stream = stream
	if stream != null:
		_music.play()


func _fade_to(alpha: float) -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(_fade, ^"modulate:a", alpha, FADE_TIME)
	var volume := MUSIC_SILENT_DB if alpha > 0.5 else MUSIC_VOLUME_DB
	tween.tween_property(_music, ^"volume_db", volume, FADE_TIME)
	await tween.finished


func _set_area_frozen(frozen: bool) -> void:
	if level == null:
		return
	# Unfrozen on the next frame: the key press that closed the dialogue must not also reach
	# the hero (and start the same conversation again).
	level.set_deferred(&"process_mode", Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_INHERIT)


func _queue_save() -> void:
	if not _save_queued:
		_save_queued = true
		_save_if_still_queued.call_deferred()


## A save_now() in between already wrote the change; writing again would only rotate the backup.
func _save_if_still_queued() -> void:
	if _save_queued:
		save_now()
