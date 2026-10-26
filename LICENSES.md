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
| `Actor/Character/Shadow.png` | character shadows |
| `Ui/Receptacle/Heart.png` | health hearts |
| `Ui/Input/Keyboard/KeyE.png`, `KeyEnter.png` | key prompts |
| `Ui/Dialog/DialogueBoxSimple.png` | message box |
| `Ui/Font/font8x8.png` | basis of the UI font (see below) |
| `FX/Smoke/Smoke/SpriteSheet.png` | enemy death puff |
| `FX/Magic/Circle/SpriteSheetSpark.png` | shrine awakening spark |
| `Audio/Sounds/...` (`Slash`, `Hit1`, `Impact`, `Impact3`, `Spirit`) | sound effects |

## Ardovel original art — `assets/ardovel/`

Drawn pixel by pixel for this project, using the Ninja Adventure master palette. Source files and
production tools are kept outside this repository.

| File | Contents |
| --- | --- |
| `characters/hero_walk.png` | hero, 16×16: columns down/up/left/right, 4 walk frames |
| `characters/hero_attack.png` | hero, three-phase sword swing, 40×40 frames |
| `monsters/musgorico.png` | Musgorico, 16×16, same layout |
| `vegetation/oak.png`, `birch.png`, `fern.png` | oak, birch, fern |
| `props/shrine.png`, `shrine_awakened.png` | shrine (dormant / awakened) |
| `ui/fonts/ardovel_8.png`, `ardovel_8.fnt` | font derived from `Ui/Font/font8x8.png` (CC0): original glyphs kept, Portuguese accented glyphs added, proportional spacing |

## Third-party tools

| Component | License | Use |
| --- | --- | --- |
| GUT 9.7.1 (`addons/gut/`), Tom "Butch" Wesley | MIT (`addons/gut/LICENSE.md`) | automated tests (development only) |
