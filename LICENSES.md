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
| `Backgrounds/Tilesets/TilesetFloor.png` | grass and dirt paths (terrain) |
| `Backgrounds/Tilesets/TilesetNature.png` | the pack's trees, bushes, flowers, rocks and stumps |
| `Backgrounds/Tilesets/TilesetHouse.png` | village houses, shop, arch, stall, barrels, banner, fence, the guardian statue and the ruin's grey guardians |
| `Backgrounds/Tilesets/Interior/TilesetWallSimple.png` | the ruin's mossy walls |
| `Backgrounds/Tilesets/Interior/TilesetInteriorFloor.png` | the ruin's cobble, slabs and the medallion floor |
| `Backgrounds/Tilesets/TilesetDungeon.png` | the ruin's orbs on stands, pressure plate and push block |
| `Backgrounds/Tilesets/TilesetTowers.png` | the crystal of the ruin's heart (dormant and awake) |
| `Actor/Character/OldMan2/`, `Woman/`, `OldWoman/` (`SpriteSheet.png`, `Faceset.png`) | the villagers and their portraits |
| `Actor/Character/Shadow.png` | character shadows |
| `Ui/Receptacle/Heart.png` | health hearts |
| `Ui/Input/Keyboard/KeyE.png`, `KeyEnter.png` | key prompts |
| `Ui/Dialog/DialogueBoxSimple.png`, `FacesetBox.png` | dialogue box and portrait frame |
| `Ui/Arrow.png` | next-page marker |
| `Ui/Font/font8x8.png` | basis of the UI font (see below) |
| `FX/Smoke/Smoke/SpriteSheet.png` | enemy death puff |
| `FX/Magic/Circle/SpriteSheetSpark.png` | shrine awakening spark |
| `FX/Smoke/SmokeCircular/SpriteSheet.png` | dust of the warden's slam |
| `FX/Magic/Spirit/SpriteSheetBlue.png` | the warden's light flying to the ruin's heart |
| `Audio/Sounds/...` (`Slash`, `Hit1`, `Impact`, `Impact2`, `Impact3`, `Impact4`, `Spirit`, `Launch`, `Magic1`, `Bonus`, `PowerUp1`, `Grass`, `Grass2`, `Explosion`, `Explosion2`) | sound effects |
| `Audio/Musics/33 - Calm Village.ogg`, `11 - Clearing.ogg`, `30 - Ruins.ogg`, `17 - Fight.ogg` | village, forest, ruin and warden fight music |

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
| `ruin/tablet.png` | a child's scratches on a small stone |
| `ruin/entrance.png` | the ruin's doorway among the great roots |
| `ruin/beacon.png` | the column of light over the village statue, three frames |
| `ui/fonts/ardovel_8.png`, `ardovel_8.fnt` | font derived from `Ui/Font/font8x8.png` (CC0): original glyphs kept except the lowercase i (its broken foot redrawn), Portuguese accented glyphs added with capital accents raised one row, proportional spacing |

## Third-party tools

| Component | License | Use |
| --- | --- | --- |
| GUT 9.7.1 (`addons/gut/`), Tom "Butch" Wesley | MIT (`addons/gut/LICENSE.md`) | automated tests (development only) |
