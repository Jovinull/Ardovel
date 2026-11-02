class_name HoistWeight
extends Node2D
## The old hoist's counterweight, hanging over the drain chamber's floor on its rope, tied off at a
## latch post. Striking the latch (or working it by hand) lets it go: its shadow grows on the floor
## (the warning), then it drops. Whatever is under it is crushed: the Old Gnawer takes a heavy blow
## that goes through her shell and leaves her dazed; the hero, if careless, is hurt (a blow no shield
## stops). It falls once per visit (nothing is saved): coming back finds it hanging again.

const TELL := 0.7
const DROP := 0.12
const CRUSH_RADIUS := 22.0
const HERO_RADIUS := 12.0
const BOSS_DAMAGE := 5
const HERO_DAMAGE := 3

## How high above its landing spot the weight hangs.
@export var height: float = 56.0

var _state := 0  # 0 hanging, 1 falling, 2 down
var _left := 0.0

@onready var _weight: Sprite2D = $Weight
@onready var _shadow: Sprite2D = $Shadow
@onready var _latch: Interactable = $Latch/Interactable
@onready var _latch_hurtbox: Hurtbox = $Latch/Hurtbox
@onready var _creak: AudioStreamPlayer2D = $Creak
@onready var _crash: AudioStreamPlayer2D = $Crash


func _ready() -> void:
	_latch.action = func(_actor: Node2D) -> String: return "VEIN_LATCH_FREED" if release() else ""
	_latch_hurtbox.hit_received.connect(func(_hit: Hit) -> void: release())
	_weight.position.y = -height
	_weight.frame = 0
	_shadow.frame = 0
	set_physics_process(false)


func is_hanging() -> bool:
	return _state == 0


func release() -> bool:
	if _state != 0:
		return false
	_state = 1
	_left = TELL
	_latch.enabled = false
	_latch_hurtbox.set_deferred(&"monitorable", false)
	_creak.play()
	set_physics_process(true)
	return true


func _physics_process(delta: float) -> void:
	_left -= delta
	if _left > 0.0:
		_shadow.frame = 0 if _left > TELL * 0.5 else 1
		return
	if _left > -DROP:
		_weight.position.y = -height * (1.0 + _left / DROP)
		return
	set_physics_process(false)
	_state = 2
	_weight.position.y = 0.0
	_weight.frame = 1
	_shadow.visible = false
	_crash.play()
	_crush()


func _crush() -> void:
	var level := Level.containing(self)
	if level != null and level.player.global_position.distance_to(global_position) <= HERO_RADIUS:
		var hit := Hit.new(HERO_DAMAGE, 160.0, global_position)
		hit.blockable = false
		(level.player.get_node(^"Hurtbox") as Hurtbox).receive_hit(hit)
	for node in get_tree().get_nodes_in_group(&"old_gnawer"):
		var gnawer := node as Node2D
		if gnawer.global_position.distance_to(global_position) <= CRUSH_RADIUS:
			gnawer.call(&"crush", BOSS_DAMAGE)
