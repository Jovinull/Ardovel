# Ardovel

A top-down 2D action fantasy RPG made with Godot 4.7 (GDScript).

For now it holds one short adventure, *O Santuário Esquecido*: the hero sets out from a small
village, crosses a forest of Musgoricos and seed-spitting Cardosas to awaken an old shrine, and
finds the village changed on returning.

## Running

Open `project.godot` in Godot 4.7.2 and press F5.

- Move: arrow keys or WASD
- Sword: Space or J
- Interact, talk and advance dialogue: E or K
- Try again: Enter

The adventure is saved automatically (one slot) whenever the hero reaches an area or makes
progress; the title menu offers to continue it. Saves live in Godot's user data folder
(`user://save.json`, with a `.bak` copy of the previous save).

Gamepads work too. Bindings live in *Project Settings › Input Map*.

The in-game text is currently in Brazilian Portuguese.

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
