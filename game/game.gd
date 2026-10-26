extends Node
## Root of a play session: connects the level, the HUD and the death screen, and owns the
## brief hit-stop that freezes the world when the sword connects.

## Seconds the world freezes when the sword connects. Real time, unaffected by the freeze itself.
@export var hit_stop_time: float = 0.06

var _hit_stop_token: int = 0

@onready var _level: Level = $Level
@onready var _hud: Hud = $HUD
@onready var _death_screen: DeathScreen = $DeathScreen


func _ready() -> void:
	_hud.bind_player(_level.player)
	_level.player.died.connect(_death_screen.open)
	_level.player.hit_landed.connect(hit_stop)
	_death_screen.restart_requested.connect(restart)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


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


func restart() -> void:
	get_tree().reload_current_scene()
