class_name CreatureParts
extends RefCounted
## Builds the usual parts of a creature in code (the vein's creatures assemble themselves with these
## instead of a hand-edited scene): health, a hurtbox, hitboxes, a detection area, sounds, and
## sprite frames cut from a hand-drawn sheet. Layers by name: world 1, player 2, enemies 4,
## player_hurtbox 8, enemy_hurtbox 16.

const SOUNDS := "res://assets/ninja_adventure/Audio/Sounds/"


static func health(owner: Node, maximum: int, invulnerable: float) -> Health:
	var h := Health.new()
	h.name = "Health"
	h.max_health = maximum
	h.invulnerability_time = invulnerable
	owner.add_child(h)
	return h


static func circle(radius: float, at: Vector2) -> CollisionShape2D:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var col := CollisionShape2D.new()
	col.name = "Shape"
	col.shape = shape
	col.position = at
	return col


static func box(size: Vector2, at: Vector2) -> CollisionShape2D:
	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.name = "Shape"
	col.shape = shape
	col.position = at
	return col


static func hurtbox(owner: Node, h: Health, shape: CollisionShape2D) -> Hurtbox:
	var area := Hurtbox.new()
	area.name = "Hurtbox"
	area.collision_layer = 16
	area.collision_mask = 0
	area.health = h
	area.add_child(shape)
	owner.add_child(area)
	return area


## A hitbox against the hero; `contact` keeps hitting while active (relying on the hero's
## invulnerability), otherwise once per activation.
static func hitbox(owner: Node, node_name: String, damage: int, knockback: float, blockable: bool,
		contact: bool, shape: CollisionShape2D) -> Hitbox:
	var area := Hitbox.new()
	area.name = node_name
	area.collision_layer = 0
	area.collision_mask = 8
	area.damage = damage
	area.knockback = knockback
	area.blockable = blockable
	area.hit_once_per_activation = not contact
	area.add_child(shape)
	owner.add_child(area)
	return area


static func detection(owner: Node, radius: float) -> Area2D:
	var area := Area2D.new()
	area.name = "Detection"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitorable = false
	area.add_child(circle(radius, Vector2(0, -6)))
	owner.add_child(area)
	return area


static func sound(owner: Node, node_name: String, path: String, volume: float = -4.0) -> AudioStreamPlayer2D:
	var player := AudioStreamPlayer2D.new()
	player.name = node_name
	player.stream = load(SOUNDS + path)
	player.volume_db = volume
	owner.add_child(player)
	return player


static func flash(owner: Node, target: CanvasItem) -> HitFlash:
	var f := HitFlash.new()
	f.name = "HitFlash"
	f.target = target
	owner.add_child(f)
	return f


## Sprite frames cut from `sheet` (frames of `size`, counted left to right, top to bottom):
## animation -> [frame indices, frames per second, loops].
static func frames(sheet: Texture2D, size: Vector2i, animations: Dictionary) -> SpriteFrames:
	var result := SpriteFrames.new()
	result.remove_animation(&"default")
	var columns := sheet.get_width() / size.x
	for anim: StringName in animations:
		var spec: Array = animations[anim]
		result.add_animation(anim)
		result.set_animation_speed(anim, spec[1])
		result.set_animation_loop(anim, spec[2])
		for index: int in spec[0]:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(Vector2(index % columns, index / columns) * Vector2(size), Vector2(size))
			result.add_frame(anim, atlas)
	return result
