class_name StatModifier
extends Resource
## One change an item makes to one of the hero's statistics while it is equipped (see HeroStats
## for how changes combine).

enum Kind { ADD, PERCENT }

## A HeroStats id (unknown ids change nothing).
@export var stat: StringName
@export var kind: Kind = Kind.ADD
## Added to the base (ADD), or percent of the base after the adds (PERCENT: 50 is +50%).
@export var value: float = 0.0
