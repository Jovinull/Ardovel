class_name GuardData
extends Resource
## How a shield guards when raised: how much of a blocked hit it stops, what holding it costs in
## breath, how quickly it comes up, how much it slows the hero, how wide in front it covers and how
## much of a blocked hit's push it takes.

## Fraction of a blocked hit's damage the shield stops (1: all of it).
@export_range(0.0, 1.0, 0.05) var absorb: float = 0.6
## Breath (Stamina) one quarter of blocked damage costs; with too little breath the guard breaks.
@export var breath_per_quarter: float = 10.0
## Seconds from raising the shield until it blocks.
@export_range(0.0, 0.5, 0.01) var raise_time: float = 0.08
## The hero's speed while guarding, as a fraction of their own.
@export_range(0.1, 1.0, 0.05) var move_factor: float = 0.6
## Degrees in front of the hero the shield covers (a hit from outside it is not blocked).
@export_range(30.0, 180.0, 5.0) var arc: float = 120.0
## Fraction of a blocked hit's knockback the shield stops.
@export_range(0.0, 1.0, 0.05) var stability: float = 0.6
