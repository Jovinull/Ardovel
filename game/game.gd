class_name Game
extends Node
## Root of a play session. Owns the adventure state, its save slot, the player's settings and
## the current area: shows the title (and applies the chosen language), loads areas (one at a time, swapped behind a fade), sends the hero back to the
## return point after a fall, and freezes the area while a dialogue is open. Also owns the
## brief hit-stop when the sword connects.

## Stable area ids (as written in saves and passages) and their scenes.
const AREAS: Dictionary[StringName, String] = {
	&"village": "res://world/village/village.tscn",
	&"forest": "res://world/forest/forest.tscn",
}
const FADE_TIME := 0.35
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

@onready var _hud: Hud = $HUD
@onready var _death_screen: DeathScreen = $DeathScreen
@onready var _title: TitleScreen = $TitleScreen
@onready var _fade: ColorRect = %Fade
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
	if show_title:
		open_title()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


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


## Resumes the saved adventure at its return point. False if there is nothing usable.
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
	await _fade_to(1.0)
	_load_area(area, entry)
	adventure.enter(area, entry)
	await _fade_to(0.0)
	_travelling = false


## Back to the adventure's return point with full health; everything earned is kept.
func respawn() -> void:
	if _travelling:
		return
	_travelling = true
	await _fade_to(1.0)
	_death_screen.close()
	adventure.health = Adventure.FULL_HEALTH
	_load_area(adventure.area, adventure.entry)
	save_now()
	await _fade_to(0.0)
	_travelling = false


func save_now() -> void:
	_save_queued = false
	if adventure == null:
		return
	if level != null and not level.player.health.is_dead():
		adventure.health = level.player.health.current
	var error := save_slot.save(adventure)
	if error != OK:
		push_warning("Could not save the adventure: %s" % error_string(error))


func is_travelling() -> bool:
	return _travelling


func hit_stop() -> void:
	if hit_stop_time <= 0.0:
		return
	_hit_stop_token += 1
	var token := _hit_stop_token
	Engine.time_scale = 0.0
	await get_tree().create_timer(hit_stop_time, true, false, true).timeout
	# A later hit may have extended the freeze; only the latest one releases it.
	if token == _hit_stop_token:
		Engine.time_scale = 1.0


func _begin(state: Adventure) -> void:
	adventure = state
	adventure.changed.connect(_queue_save)
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
	if adventure.health != Adventure.FULL_HEALTH:
		player.health.current = clampi(adventure.health, 1, player.health.max_health)
	player.died.connect(_death_screen.open)
	player.hit_landed.connect(hit_stop)
	level.exit_requested.connect(travel)
	_hud.bind_player(player)
	_play_music(level.music)


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
		save_now.call_deferred()
