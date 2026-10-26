extends GutTest

const Phase := AttackData.Phase

var data: AttackData
var attack: MeleeAttack
var hitbox: Hitbox


func before_each() -> void:
	data = AttackData.new()
	data.windup = 0.1
	data.active = 0.1
	data.recovery = 0.1
	data.damage = 2
	data.knockback = 50.0
	data.reach = 12.0
	hitbox = Hitbox.new()
	attack = MeleeAttack.new()
	attack.data = data
	attack.hitbox = hitbox
	add_child_autofree(hitbox)
	add_child_autofree(attack)


func test_phase_boundaries() -> void:
	assert_eq(data.phase_at(-0.01), Phase.IDLE)
	assert_eq(data.phase_at(0.0), Phase.WINDUP)
	assert_eq(data.phase_at(0.099), Phase.WINDUP)
	assert_eq(data.phase_at(0.1), Phase.ACTIVE)
	assert_eq(data.phase_at(0.2), Phase.RECOVERY)
	assert_eq(data.phase_at(0.3), Phase.IDLE)


func test_start_aims_and_configures_hitbox() -> void:
	assert_true(attack.start(Vector2.LEFT))
	assert_eq(attack.phase, Phase.WINDUP)
	assert_eq(hitbox.position, Vector2(-12, 0))
	assert_almost_eq(hitbox.rotation, PI / 2.0, 0.0001)
	assert_eq(hitbox.damage, 2)
	assert_false(hitbox.active, "hitbox must stay off during wind-up")


func test_cannot_start_while_attacking_or_without_direction() -> void:
	assert_false(attack.start(Vector2.ZERO))
	attack.start(Vector2.DOWN)
	assert_false(attack.start(Vector2.UP))


func test_hitbox_is_active_only_during_active_phase() -> void:
	attack.start(Vector2.DOWN)
	attack.advance(0.11)
	assert_eq(attack.phase, Phase.ACTIVE)
	assert_true(hitbox.active)
	attack.advance(0.1)
	assert_eq(attack.phase, Phase.RECOVERY)
	assert_false(hitbox.active)


func test_finishes_and_can_attack_again() -> void:
	watch_signals(attack)
	attack.start(Vector2.DOWN)
	for i in 20:
		attack.advance(1.0 / 60.0)
	assert_eq(attack.phase, Phase.IDLE)
	assert_signal_emit_count(attack, "finished", 1)
	assert_true(attack.start(Vector2.UP))


func test_long_frame_never_skips_the_active_window() -> void:
	attack.start(Vector2.DOWN)
	attack.advance(1.0)
	assert_eq(attack.phase, Phase.ACTIVE)
	assert_true(hitbox.active)


func test_cancel_turns_hitbox_off() -> void:
	attack.start(Vector2.DOWN)
	attack.advance(0.15)
	attack.cancel()
	assert_eq(attack.phase, Phase.IDLE)
	assert_false(hitbox.active)


func test_phase_changes_on_the_expected_physics_tick() -> void:
	# 0.1 s of wind-up at 60 Hz is six ticks; float accumulation must not delay it to a seventh.
	attack.start(Vector2.DOWN)
	for i in 5:
		attack.advance(1.0 / 60.0)
	assert_eq(attack.phase, Phase.WINDUP)
	attack.advance(1.0 / 60.0)
	assert_eq(attack.phase, Phase.ACTIVE)


func test_remaining_time_counts_down_to_zero() -> void:
	assert_eq(attack.remaining(), 0.0)
	attack.start(Vector2.DOWN)
	assert_almost_eq(attack.remaining(), 0.3, 0.0001)
	for i in 5:
		attack.advance(0.05)
	assert_almost_eq(attack.remaining(), 0.05, 0.0001)
