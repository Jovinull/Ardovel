extends Node
## Root of a play session: connects the level, the HUD and the death screen.

@onready var _level: Level = $Level
@onready var _hud: Hud = $HUD
@onready var _death_screen: DeathScreen = $DeathScreen


func _ready() -> void:
	_hud.bind_player(_level.player)
	_level.player.died.connect(_death_screen.open)
	_death_screen.restart_requested.connect(restart)


func restart() -> void:
	get_tree().reload_current_scene()
