extends GutTest

var health: Health


func before_each() -> void:
	health = Health.new()
	health.max_health = 12
	add_child_autofree(health)


func test_starts_full() -> void:
	assert_eq(health.current, 12)
	assert_false(health.is_dead())


func test_damage_reduces_and_clamps_at_zero() -> void:
	assert_true(health.take_damage(5))
	assert_eq(health.current, 7)
	health.take_damage(50)
	assert_eq(health.current, 0)
	assert_true(health.is_dead())


func test_non_positive_damage_is_rejected() -> void:
	assert_false(health.take_damage(0))
	assert_false(health.take_damage(-3))
	assert_eq(health.current, 12)


func test_died_is_emitted_exactly_once() -> void:
	watch_signals(health)
	health.take_damage(12)
	health.take_damage(1)
	assert_signal_emit_count(health, "died", 1)


func test_dead_actor_ignores_damage_and_healing() -> void:
	health.take_damage(12)
	assert_false(health.take_damage(1))
	health.heal(5)
	assert_eq(health.current, 0)


func test_heal_clamps_to_max_and_only_signals_on_change() -> void:
	health.take_damage(2)
	watch_signals(health)
	health.heal(10)
	assert_eq(health.current, 12)
	health.heal(1)
	assert_signal_emit_count(health, "changed", 1)


func test_invulnerability_blocks_damage_until_it_expires() -> void:
	health.invulnerability_time = 0.5
	assert_true(health.take_damage(1))
	assert_true(health.is_invulnerable())
	assert_false(health.take_damage(1), "second hit inside the window must be ignored")
	health._physics_process(0.3)
	assert_false(health.take_damage(1))
	health._physics_process(0.21)
	assert_false(health.is_invulnerable())
	assert_true(health.take_damage(1))
	assert_eq(health.current, 10)


func test_lethal_hit_does_not_start_invulnerability() -> void:
	health.invulnerability_time = 1.0
	health.take_damage(12)
	assert_false(health.is_invulnerable())


func test_restore_full() -> void:
	health.take_damage(9)
	health.restore_full()
	assert_eq(health.current, 12)
