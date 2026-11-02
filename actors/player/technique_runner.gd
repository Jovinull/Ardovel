class_name TechniqueRunner
extends Node
## Performs the hero's techniques (active skills). The blow itself is an ordinary swing of the
## hero's MeleeAttack, built from the weapon in hand (TechniqueData.attack_for), so damage, power,
## its carried fraction, blocks and hit-stop work as with any swing; this node only adds what each
## technique does besides: a step forward stopped by anything solid (LUNGE), the blow carried across
## an arc (SWEEP), an answer only right after a clean block (COUNTER), the frames and the effect.
## While one runs the blow is never struck through a wall (Hitbox.sight_from).
##
## The hero asks it to start one (`try_start`) and steps it while in its TECHNIQUE state; a blow
## taken, a fall or leaving the area cancels it.

## Technique slots the hero has.
const SLOTS := 2

signal started(slot: int)
## A technique asked for could not start: &"empty", &"weapon" (not for the weapon or shield in
## hand), &"window" (a response with no block to answer), &"breath".
signal refused(slot: int, reason: StringName)
signal finished
## The moment to answer a block opened or closed.
signal response_changed(open: bool)

const EFFECTS: Dictionary[TechniqueData.Motion, PackedScene] = {
	TechniqueData.Motion.LUNGE: preload("res://fx/technique_pierce.tscn"),
	TechniqueData.Motion.STRIKE: preload("res://fx/technique_break.tscn"),
	TechniqueData.Motion.SWEEP: preload("res://fx/technique_sweep.tscn"),
	TechniqueData.Motion.COUNTER: preload("res://fx/technique_counter.tscn"),
}

var _hero: Player
var _melee: MeleeAttack
var _skills: Array[SkillDef] = [null, null]
var _weapon: StringName
var _current: SkillDef
var _slot := -1
var _direction := Vector2.DOWN
var _elapsed := 0.0
var _response_left := 0.0


func _ready() -> void:
	_hero = get_parent() as Player
	_melee = _hero.get_node(^"MeleeAttack") as MeleeAttack


func _physics_process(delta: float) -> void:
	if _response_left > 0.0:
		_response_left -= delta
		if _response_left <= 0.0:
			response_changed.emit(false)


## The techniques in the two slots (null where empty) and the weapon in hand (an ItemDef id).
func set_skills(skills: Array[SkillDef], weapon: StringName) -> void:
	_skills = skills.duplicate()
	_weapon = weapon


func skill(slot: int) -> SkillDef:
	return _skills[slot] if slot >= 0 and slot < _skills.size() else null


## Why the technique in `slot` cannot start now (empty: it can, breath aside).
func why_not(slot: int) -> StringName:
	var technique := skill(slot)
	if technique == null or technique.technique == null:
		return &"empty"
	if not technique.fits(_weapon, _hero.guard() != null):
		return &"weapon"
	if technique.technique.motion == TechniqueData.Motion.COUNTER and _response_left <= 0.0:
		return &"window"
	if _hero.stamina.current < technique.breath - 0.001:
		return &"breath"
	return &""


## Whether the technique in `slot` could be used with what is in hand (breath and timing aside).
func fits(slot: int) -> bool:
	var technique := skill(slot)
	return technique != null and technique.fits(_weapon, _hero.guard() != null)


func is_running() -> bool:
	return _current != null


func current() -> SkillDef:
	return _current


## Whether a clean block can be answered now.
func is_response_open() -> bool:
	return _response_left > 0.0


## A clean block: for a moment, an equipped response may answer it.
func open_response() -> void:
	for technique in _skills:
		if technique != null and technique.technique != null \
				and technique.technique.motion == TechniqueData.Motion.COUNTER:
			_response_left = technique.technique.window
			response_changed.emit(true)
			return


## Starts the technique in `slot` towards `toward` (a cardinal). False, with `refused`, if it cannot.
func try_start(slot: int, toward: Vector2) -> bool:
	var reason := why_not(slot)
	if not reason.is_empty() or not _hero.stamina.spend(skill(slot).breath):
		refused.emit(slot, reason if not reason.is_empty() else &"breath")
		return false
	_current = skill(slot)
	_slot = slot
	_direction = toward
	_elapsed = 0.0
	if _current.technique.motion == TechniqueData.Motion.COUNTER:
		_response_left = 0.0  # one answer per block
		response_changed.emit(false)
	_melee.cancel()
	_melee.data = _current.technique.attack_for(_hero.weapon_swing())
	_melee.hitbox.sight_from = _hero
	_melee.start(toward)
	_effect()
	started.emit(slot)
	return true


## One physics step of the technique running.
func step(delta: float) -> void:
	if _current == null:
		return
	_elapsed += delta
	var technique := _current.technique
	var in_blow := _melee.phase == AttackData.Phase.ACTIVE
	match technique.motion:
		TechniqueData.Motion.LUNGE:
			if in_blow:
				_hero.velocity = _direction * technique.lunge / technique.active
				_hero.move_and_slide()
				return
		TechniqueData.Motion.SWEEP:
			if in_blow:
				var t := clampf((_elapsed - technique.windup) / technique.active, 0.0, 1.0)
				var angle := deg_to_rad(lerpf(-technique.sweep / 2.0, technique.sweep / 2.0, t))
				var along := _direction.rotated(angle)
				_melee.hitbox.position = along * _melee.data.reach
				_melee.hitbox.rotation = along.angle() - Vector2.DOWN.angle()
	_hero.velocity = _hero.velocity.move_toward(Vector2.ZERO, _hero.friction * delta)
	_hero.move_and_slide()


## The blow ended on its own.
func finish() -> void:
	_release()
	finished.emit()


## A blow taken, a fall, leaving: the technique stops where it is.
func cancel() -> void:
	if _current == null:
		return
	_melee.cancel()
	_release()
	finished.emit()


func _release() -> void:
	_current = null
	_slot = -1
	_melee.hitbox.sight_from = null
	_melee.data = _hero.weapon_swing()


func _effect() -> void:
	var scene: PackedScene = EFFECTS.get(_current.technique.motion)
	if scene == null:
		return
	# In the world, where the hero stood: a lunge's streak stays behind, a crack stays on the ground.
	var effect: Node2D = scene.instantiate()
	effect.set(&"direction", _direction)
	effect.set(&"delay", _current.technique.windup)
	effect.set(&"reach", _melee.data.reach + _current.technique.lunge)
	_hero.get_parent().add_child(effect)
	effect.global_position = _hero.global_position
