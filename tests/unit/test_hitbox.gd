extends GutTest

var hitbox: Hitbox
var hurtbox: Hurtbox
var health: Health


func before_each() -> void:
	health = Health.new()
	health.max_health = 10
	hurtbox = Hurtbox.new()
	hurtbox.health = health
	hitbox = Hitbox.new()
	hitbox.damage = 3
	add_child_autofree(health)
	add_child_autofree(hurtbox)
	add_child_autofree(hitbox)


func test_inactive_hitbox_does_nothing() -> void:
	assert_false(hitbox.strike(hurtbox))
	assert_eq(health.current, 10)


func test_swing_hits_each_target_once_per_activation() -> void:
	hitbox.active = true
	assert_true(hitbox.strike(hurtbox))
	assert_false(hitbox.strike(hurtbox))
	assert_eq(health.current, 7)


func test_reactivation_allows_a_new_hit() -> void:
	hitbox.active = true
	hitbox.strike(hurtbox)
	hitbox.active = false
	hitbox.active = true
	assert_true(hitbox.strike(hurtbox))
	assert_eq(health.current, 4)


func test_contact_damage_is_limited_by_target_invulnerability() -> void:
	health.invulnerability_time = 1.0
	hitbox.hit_once_per_activation = false
	hitbox.active = true
	assert_true(hitbox.strike(hurtbox))
	assert_false(hitbox.strike(hurtbox), "invulnerable target must reject contact damage")
	health._physics_process(1.0)
	assert_true(hitbox.strike(hurtbox))
	assert_eq(health.current, 4)


func test_hurtbox_reports_only_landed_hits() -> void:
	watch_signals(hurtbox)
	health.invulnerability_time = 1.0
	hitbox.hit_once_per_activation = false
	hitbox.active = true
	hitbox.strike(hurtbox)
	hitbox.strike(hurtbox)
	assert_signal_emit_count(hurtbox, "hit_received", 1)


func test_hit_knockback_points_away_from_source() -> void:
	var hit := Hit.new(1, 100.0, Vector2.ZERO)
	assert_eq(hit.knockback_velocity(Vector2(10, 0)), Vector2(100, 0))
	assert_eq(hit.knockback_velocity(Vector2.ZERO), Vector2(0, 100), "degenerate case falls back to down")
