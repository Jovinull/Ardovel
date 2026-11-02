# Ardovel

A top-down 2D action fantasy RPG made with Godot 4.7 (GDScript).

It begins with *O Santuário Esquecido*: the hero sets out from a small village, crosses a forest of
Musgoricos and seed-spitting Cardosas to awaken an old shrine, and goes down into a first ruin,
*Ecos Sob as Raízes*, guarded by the Root Warden. The road then leads west past a fallen bridge, a
blocked road and a travellers' halt to Pedrabranca, a quarry town, and under it into *O Filão Oco*,
the old mine's drainage galleries and the Old Gnawer's den. Along the way the hero gathers
equipment, grows in level and technique, and trades in coppers.

## Running

Open `project.godot` in Godot 4.7.2 and press F5.

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| move | WASD or arrows | D-pad or left stick |
| attack | Space or J | X |
| interact, talk, advance dialogue | E or K | A |
| dodge | L or Shift | B |
| shield | U or Ctrl | LB |
| eat (quick slot) | F | Y |
| techniques | O and P | RB and RT |
| hero menu (equipment, inventory, status, techniques) | I | Back |
| pause | Esc | Start |
| try again after a fall | Enter | Start |

The adventure is saved automatically (one slot) whenever the hero reaches an area or makes
progress; the title menu offers to continue it. After a fall the hero returns to the last shrine
awakened (in the Hollow Vein, to its mouth, or to the miners' lamp once lit). Saves live in Godot's
user data folder (`user://save.json`, with a `.bak` copy of the previous save); saves from earlier
versions of the game are upgraded when loaded.

Bindings live in *Project Settings › Input Map*.

The game is written in Brazilian Portuguese and translated into English; the title menu switches
language (remembered in `user://settings.cfg`). Texts live in `locale/text.csv` under stable keys.

## Tests

Tests use [GUT](https://github.com/bitwes/Gut) 9.7.1, bundled in `addons/gut`.

```
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd
```

GitHub Actions runs the same two commands on every push (`.github/workflows/tests.yml`).

## Art

The visual base is the Ninja Adventure asset pack (CC0), together with original art made for the
project. Where every file comes from is listed in `LICENSES.md`.
