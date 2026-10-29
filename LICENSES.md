# Licenses and provenance

## Ardovel code

All code in `actors/`, `combat/`, `interaction/`, `world/`, `fx/`, `ui/`, `game/` and `tests/`
was written for this project.

## Ninja Adventure Asset Pack — `assets/ninja_adventure/`

- Authors: **Pixel-Boy** and **AAA**
- Source: https://pixel-boy.itch.io/ninja-adventure-asset-pack
- License: **CC0 1.0** (full text in `assets/ninja_adventure/LICENSE.txt`; the pack's original README
  is `assets/ninja_adventure/README.md`).
- Files are copied **unmodified**, keeping the pack's paths, and only the ones in use are included.

| File | Used for |
| --- | --- |
| `Backgrounds/Tilesets/TilesetFloor.png` | grass and dirt paths (terrain); the western slope uses its darker meadow set and its pale stony set |
| `Backgrounds/Tilesets/tileset_camp.png` | Iara's tent, fire pit, pot, lamp post, coil of rope, oil jars, stools and log bench; the road crew's torn shelter |
| `Backgrounds/Tilesets/TilesetWater.png` | the brook under the slab bridge on the road to Pedrabranca |
| `Items/Tool/Shovel.png`, `Pickaxe.png` | the road crew's tools left at their shelter |
| `Backgrounds/Tilesets/TilesetNature.png` | the pack's trees, bushes, flowers, rocks and stumps, and the grey crags, stacked stones and pebbles of the western slope |
| `Backgrounds/Tilesets/TilesetHouse.png` | village houses, shop, arch, stall, barrels, banner, fence, the guardian statue and the ruin's grey guardians |
| `Backgrounds/Tilesets/Interior/TilesetWallSimple.png` | the ruin's mossy walls |
| `Backgrounds/Tilesets/Interior/TilesetInteriorFloor.png` | the ruin's cobble, slabs and the medallion floor |
| `Backgrounds/Tilesets/TilesetDungeon.png` | the ruin's orbs on stands, pressure plate and push block |
| `Backgrounds/Tilesets/TilesetTowers.png` | the crystal of the ruin's heart, awake |
| `Backgrounds/Tilesets/TilesetVillageAbandoned.png` | the ruin's pillars, broken walls and fallen guardian |
| `Actor/Character/OldMan2/`, `Woman/`, `OldWoman/`, `Villager3/` (`SpriteSheet.png`, `Faceset.png`) | the villagers, Iara of the far bank, and their portraits |
| `Actor/Character/Shadow.png` | character shadows |
| `Actor/Animal/Chicken/SpriteSheetWhite.png`, `SpriteSheetBrown.png`, `SpriteSheetBlack.png` | Cida's three hens |
| `Ui/Receptacle/Heart.png` | health hearts |
| `Ui/Input/Keyboard/KeyE.png`, `KeyEnter.png` | key prompts |
| `Ui/Dialog/DialogueBoxSimple.png`, `FacesetBox.png` | dialogue box and portrait frame |
| `Ui/Arrow.png` | next-page marker |
| `Ui/Emote/emote14.png`, `emote20.png`, `emote21.png` | Iara's count at the big stone: a flat look, "...", "!" |
| `Ui/Font/font8x8.png` | basis of the UI font (see below) |
| `FX/Smoke/Smoke/SpriteSheet.png` | enemy death puff |
| `FX/Magic/Circle/SpriteSheetSpark.png` | shrine awakening spark |
| `FX/Smoke/SmokeCircular/SpriteSheet.png` | dust of the warden's slam |
| `FX/Magic/Spirit/SpriteSheetBlue.png` | the warden's light flying to the ruin's heart |
| `Audio/Sounds/...` (`Slash`, `Hit1`, `Impact`, `Impact2`, `Impact3`, `Impact4`, `Spirit`, `Launch`, `Magic1`, `Bonus`, `PowerUp1`, `Grass`, `Grass2`, `Explosion`, `Explosion2`, `Whoosh`, `Bounce`, `Water2`) | sound effects |
| `Audio/Musics/33 - Calm Village.ogg`, `11 - Clearing.ogg`, `30 - Ruins.ogg`, `17 - Fight.ogg`, `23 - Road.ogg` | village, forest, ruin, warden fight and far bank music |

## Ardovel original art — `assets/ardovel/`

Drawn pixel by pixel for this project, using the Ninja Adventure master palette. Source files and
production tools are kept outside this repository.

| File | Contents |
| --- | --- |
| `characters/hero_walk.png` | hero, 16×16: columns down/up/left/right, 4 walk frames |
| `characters/hero_attack.png` | hero, three-phase sword swing, 40×40 frames |
| `characters/hero_hurt.png` | hero hurt poses, 16×16, one per direction |
| `characters/hero_death.png` | hero death: stagger, kneel, fallen (32×32 frames) |
| `monsters/musgorico.png` | Musgorico, 16×16, same layout |
| `monsters/musgorico_combat.png` | Musgorico windup, lunge and hurt poses |
| `monsters/musgorico_death.png` | Musgorico curling up and going flat |
| `monsters/cardosa.png` | Cardosa, the seed-spitting plant: idle, windup, shot, hurt, wilt |
| `monsters/cardosa_seed.png` | Cardosa's seed, two spin frames |
| `fx/hit_spark.png` | sword impact spark, three frames |
| `vegetation/oak.png`, `birch.png`, `fern.png` | oak, birch, fern |
| `props/shrine.png`, `shrine_awakened.png` | shrine (dormant / awakened) |
| `monsters/root_warden.png` | the Root Warden, 48×48: idle, wind-up, slam, stuck (core bare), cast, crumbling |
| `ruin/root_seal.png`, `root_seal_vertical.png` | roots across a doorway, pulling back (4 frames) |
| `ruin/thin_roots.png` | thin hanging roots: whole, cut, falling, stubs |
| `ruin/wall_roots.png`, `floor_root.png` | roots grown over walls and floors |
| `ruin/spike_warning.png`, `root_spike.png` | the warden's root spike: cracks (warning) and eruption |
| `ruin/heart_vessel.png` | crystal heart (more health), two frames |
| `ruin/mural.png` | the heart chamber's carving, dark and lit |
| `ruin/tablet.png` | a child's scratches on a small slab |
| `ruin/heart_crystal_dormant.png` | **modified copy** of the moss-covered crystal of Ninja Adventure's `TilesetTowers.png` (CC0): same pixels, with the crystal's lit colours replaced by master-palette stone so it reads as unlit (the original file is unchanged) |
| `ruin/entrance.png` | the ruin's doorway among the great roots |
| `ruin/beacon.png` | the column of light over the village statue, three frames |
| `forest/thicket.png`, `forest/echo_stone.png`, `forest/light_traces.png`, `forest/distant_glint.png`, `forest/wood_stack.png`, `forest/wood_carried.png` | hand drawn roots, signal stone, light traces, distant glint and firewood for the forest revisiting prototype, and the two logs Anselmo carries from the pile |
| `west/lookout_floor.png`, `west/lookout_disc.png`, `west/gleam.png`, `west/fire_ring.png`, `west/footprints.png`, `west/fallen_bridge.png`, `west/gorge.png`, `west/pass_steps.png`, `west/keeper_cache.png` | hand drawn western lookout: its stone floor with parapet and steps, the polished disc on its pedestal (two positions), the reflected patch of daylight, a cold fire ring, footprints, the fallen rope bridge with its posts, boards and hanging ropes, the gorge's far bank, drop and near edge, the old steps of the pass and the cache in the pines |
| `west/bridge_deck.png`, `west/bridge_post.png`, `west/line_weight.png`, `west/footprints_dark.png`, `far_bank/oil_press.png`, `far_bank/seed_basket.png`, `far_bank/signpost.png` | hand drawn rope bridge deck and post, the stone of the messenger line, footprints pressed into trodden earth, and Iara's oil press, basket of Cardosa seeds and the road's signpost |
| `road/ditch.png`, `road/dam_log.png`, `road/dam_debris.png`, `road/log_aside.png`, `road/runoff.png`, `road/runoff_far_bank.png`, `road/ditch_fall.png`, `road/rolling_stone.png`, `road/tally_board.png`, `road/pry_bar.png` | hand drawn drainage ditch (dry and running), the fallen trunk and debris that choke it, the trunk levered aside, the runoff down the slope and onto the road, the ditch pouring into the gorge, a rolling stone, the road crew's tally board and Iara's pry bar |
| `spring/road_ditch.png`, `spring/bridge.png`, `spring/stake.png`, `spring/milestone.png`, `spring/bar_ready.png`, `spring/bar_heave.png`, `spring/wedge.png`, `spring/drag.png`, `spring/load.png`, `spring/load_side.png`, `spring/note.png` | hand drawn roadside ditch (cleared, from the slope's ditch, and choked), the slab bridge, the crew's section-end stake, a milestone, the crew's long bar (ready and borne down), a wedge, the furrows of the walked stone, Iara's carrying frame with her oil (standing and side on) and her note |
| `blank/board.png`, `blank/board_note.png`, `blank/map_ground.png`, `blank/map_blank.png`, `blank/map_drawn.png`, `blank/breu_perch.png` | hand drawn travellers' board at the halt, the witch's note on it, her map on the ground and up close (blank and drawn), and Breu perched |
| `characters/bruxa_walk.png`, `characters/bruxa_idle.png`, `characters/bruxa_faceset.png`, `characters/morcego_fly.png` | hand drawn travelling witch (walk in 16x20 frames, idle, portrait) and her bat Breu in flight; original art made for Ardovel, an affectionate homage to the little witch shown by the Brazilian creator Gemaplys on his development streams; no asset, name or code of that project is used |
| `village/coop.png` | **modified copy** of the wooden hut of Ninja Adventure's `TilesetHouse.png` (CC0, region 3,120 to 45,159): two frames, one with two roof boards missing (a dark slot with its batten) and one with new, lighter boards in their place (the original file is unchanged) |
| `village/coop_gate.png`, `village/egg_basket.png`, `village/grain.png` | hand drawn yard gate (nailed shut, open, new), basket of eggs and scattered grain, in the pack's idiom for wooden frames |
| `ui/fonts/ardovel_8.png`, `ardovel_8.fnt` | font derived from `Ui/Font/font8x8.png` (CC0): original glyphs kept except the lowercase i (its broken foot redrawn), Portuguese accented glyphs added with capital accents raised one row, proportional spacing |

## Third-party tools

| Component | License | Use |
| --- | --- | --- |
| GUT 9.7.1 (`addons/gut/`), Tom "Butch" Wesley | MIT (`addons/gut/LICENSE.md`) | automated tests (development only) |
