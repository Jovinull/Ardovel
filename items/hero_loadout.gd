class_name HeroLoadout
extends RefCounted
## Where the saved equipment meets the hero: the items worn (known ones, in their own slot), the
## statistics they give on top of the hero scene's own values, and handing those to the sword.


## The known items equipped in `adventure`, slot by slot. An unknown id, or an item in a slot it
## does not go in, is left out (and changes nothing).
static func worn(adventure: Adventure) -> Array[ItemDef]:
	var items: Array[ItemDef] = []
	for slot in ItemCatalog.SLOTS:
		var item := ItemCatalog.find(adventure.equipped(slot))
		if item != null and item.slot == slot:
			items.append(item)
	return items


static func stats(adventure: Adventure, sword: AttackData) -> Dictionary[StringName, float]:
	var base: Dictionary[StringName, float] = {
		HeroStats.SWORD_DAMAGE: float(sword.damage),
		HeroStats.SWORD_KNOCKBACK: sword.knockback,
	}
	return HeroStats.derive(base, worn(adventure))


static func apply(adventure: Adventure, player: Player) -> void:
	var derived := stats(adventure, player.base_sword())
	player.set_sword_power(roundi(derived[HeroStats.SWORD_DAMAGE]), derived[HeroStats.SWORD_KNOCKBACK])
