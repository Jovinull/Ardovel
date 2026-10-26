# Ardovel

A top-down 2D action fantasy RPG made with Godot 4.7 (GDScript).

For now there is a single forest clearing: the hero explores, fights the Musgoricos and the
seed-spitting Cardosas, and can awaken the shrine.

## Running

Open `project.godot` in Godot 4.7.2 and press F5.

- Move: arrow keys or WASD
- Sword: Space or J
- Interact: E or K
- Try again: Enter

Gamepads work too. Bindings live in *Project Settings › Input Map*.

The in-game text is currently in Brazilian Portuguese.

## Tests

Tests use [GUT](https://github.com/bitwes/Gut) 9.7.1, bundled in `addons/gut`.

```
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd
```

## Art

The visual base is the Ninja Adventure asset pack (CC0), together with original art made for the
project. Where every file comes from is listed in `LICENSES.md`.
