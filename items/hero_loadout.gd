class_name HeroLoadout
extends RefCounted
## Where the saved equipment meets the hero: the statistics of what is worn on top of the hero's
## own values (a Profile), handing them to the hero, and using a consumable. The equipment menu
## reads the same Profiles to show and compare, so nothing is computed in two places.


## A dodge as the weight carried allows it.
class Dodge:
	extends RefCounted
	var distance: float = 40.0
	var duration: float = HeroStats.DODGE_TIME
	var untouchable: float = 0.12
	var recovery: float = 0.14


## Everything derived from one adventure's equipment.
class Profile:
	extends RefCounted
	## HeroStats id -> value.
	var stats: Dictionary[StringName, float] = {}
	var weapon: ItemDef
	## The weapon's swing as worn (damage, knockback, reach and timing derived).
	var attack: AttackData
	## Weight of everything worn.
	var carried: float = 0.0
	## A HeroStats band.
	var band: StringName = HeroStats.LIGHT
	## The shield's guard (null without a shield) and its frames.
	var guard: GuardData
	var guard_sheet: Texture2D
	var dodge := Dodge.new()

	func value(stat: StringName) -> float:
		return stats.get(stat, 0.0)

	func max_health() -> int:
		return roundi(value(HeroStats.MAX_HEALTH))

	## Worn weight over load (1.0 is the edge of overloaded).
	func load_ratio() -> float:
		return carried / maxf(value(HeroStats.LOAD), 0.001)

	## Top speed as a fraction of the hero's own: the band, then speed bonuses.
	func speed_factor() -> float:
		return HeroStats.BAND_SPEED[band] * (1.0 + value(HeroStats.SPEED) / 100.0)

	func acceleration_factor() -> float:
		return HeroStats.BAND_ACCELERATION[band]

	## Seconds one swing takes, start to end.
	func swing_seconds() -> float:
		return attack.duration()


## The profile of `adventure`'s hero, whose health before equipment is `base_health` quarters.
static func profile(adventure: Adventure, base_health: int) -> Profile:
	var worn := Equipment.worn(adventure)
	var result := Profile.new()
	result.weapon = Equipment.weapon(adventure)
	var sword := result.weapon.attack
	var base: Dictionary[StringName, float] = {
		HeroStats.MAX_HEALTH: float(base_health), HeroStats.ATTACK: float(sword.damage),
		HeroStats.KNOCKBACK: sword.knockback, HeroStats.REACH: sword.reach, HeroStats.SWING: 100.0,
		HeroStats.DEFENSE: 0.0, HeroStats.POISE: 0.0, HeroStats.LOAD: HeroStats.BASE_LOAD,
		HeroStats.SPEED: 0.0, HeroStats.HEALING: 0.0,
	}
	result.stats = HeroStats.derive(base, worn)
	result.carried = HeroStats.weight(worn)
	result.band = HeroStats.band(result.carried, result.stats[HeroStats.LOAD])
	var attack := sword.duplicate() as AttackData
	var swing := result.stats[HeroStats.SWING] / 100.0
	attack.damage = roundi(result.stats[HeroStats.ATTACK])
	attack.knockback = result.stats[HeroStats.KNOCKBACK]
	attack.reach = result.stats[HeroStats.REACH]
	attack.windup = sword.windup * swing
	attack.recovery = sword.recovery * swing
	result.attack = attack
	var shield := ItemCatalog.find(adventure.equipped(ItemCatalog.OFF_HAND))
	if ItemCatalog.fits(shield, ItemCatalog.OFF_HAND) and shield.guard != null:
		result.guard = shield.guard
		result.guard_sheet = shield.guard_sheet
	result.dodge.distance = HeroStats.DODGE_DISTANCE[result.band]
	result.dodge.untouchable = HeroStats.DODGE_UNTOUCHABLE[result.band]
	result.dodge.recovery = HeroStats.DODGE_RECOVERY[result.band]
	return result


## What the profile would be after putting `id` in `slot` (empty `id`: taking the piece off),
## without touching `adventure`.
static func profile_if(adventure: Adventure, base_health: int, slot: StringName, id: StringName) -> Profile:
	var trial := Adventure.from_dict(adventure.to_dict())
	if id.is_empty():
		trial.unequip(slot)
	else:
		trial.equip(slot, id)
	return profile(trial, base_health)


## Gives the hero what `profile` says: the weapon and its swing, health, defence, firmness and
## mobility.
static func apply(profile: Profile, player: Player) -> void:
	player.set_weapon(profile.attack, profile.weapon.attack_sheet)
	player.set_guard(profile.guard, profile.guard_sheet)
	player.set_dodge(profile.dodge)
	player.stamina.regen_factor = HeroStats.BAND_BREATH[profile.band]
	if player.health.max_health != profile.max_health():
		player.health.set_maximum(profile.max_health())
	player.health.defense_percent = profile.value(HeroStats.DEFENSE)
	player.poise_percent = profile.value(HeroStats.POISE)
	player.set_mobility(profile.speed_factor(), profile.acceleration_factor())


## Quarters `item` gives back with `profile`'s healing bonus.
static func heal_amount(profile: Profile, item: ItemDef) -> int:
	return roundi(item.heal * (1.0 + profile.value(HeroStats.HEALING) / 100.0))


## Uses one `id` on `health`: heals and takes one from the bag. False (nothing spent) if it is not
## something to use, there is none left, or health is already full.
static func use(adventure: Adventure, profile: Profile, health: Health, id: StringName) -> bool:
	var item := ItemCatalog.find(id)
	if item == null or not item.is_usable() or adventure.count(id) <= 0:
		return false
	if health.is_dead() or health.current >= health.max_health:
		return false
	health.heal(heal_amount(profile, item))
	return adventure.remove_item(id)
