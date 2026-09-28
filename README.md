<div align="center">

# Separate Shortcut Palettes (Keyboard & Gamepad)

Gives **Monster Hunter Wilds** a separate set of shortcut palettes for the keyboard and for the gamepad, instead of one set shared by both. Built on [REFramework](https://github.com/praydog/REFramework).

[![Platform](https://img.shields.io/badge/platform-Windows-0078D6?style=flat-square&logo=windows&logoColor=white)]()
[![REFramework](https://img.shields.io/badge/REFramework-lua-5865F2?style=flat-square)](https://github.com/praydog/REFramework)
[![Nexus Mods](https://img.shields.io/badge/Nexus%20Mods-download-D98F40?style=flat-square)](https://www.nexusmods.com/monsterhunterwilds/mods/4991)
[![License: MIT](https://img.shields.io/badge/license-MIT-4c1?style=flat-square)](LICENSE)
![language](https://img.shields.io/badge/docs-EN%20%7C%20KR-blue?style=flat-square)

*[한글 설명 보기](README.ko.md) · [Nexus Mods page](https://www.nexusmods.com/monsterhunterwilds/mods/4991)*

</div>

## The problem

Wilds keeps **one** set of shortcut palettes, shared by the keyboard and the gamepad. Rearrange a palette with the gamepad and the keyboard gets the change too, and the other way around. If you switch between the two, you keep undoing your own layout.

---

## What this does

It keeps two copies, one for the gamepad and one for the keyboard, and swaps them into the game as you switch between devices. Press a gamepad button and the gamepad palettes are loaded; press a keyboard key and the keyboard palettes are loaded. Edits made on one device never affect the other.

Everything a palette holds is kept separate: the items, the palette names and their icons. Each hunter has their own two sets.

---

## Install

Grab a release from [Nexus Mods](https://www.nexusmods.com/monsterhunterwilds/mods/4991) or the [GitHub releases](../../releases) and extract it into your Monster Hunter Wilds folder so you end up with:

```
MonsterHunterWilds/
└─ reframework/
   └─ autorun/
      └─ SeparateShortcutPalettes.lua
```

> [!NOTE]
> Requires [REFramework](https://github.com/praydog/REFramework). Nothing to run and no runtime to install: the file loads automatically when the game starts.

---

## How to use (in game)

Start the game and load a character. Press **Insert** to open the REFramework menu, then open **Script Generated UI → Separate Shortcut Palettes**. The status line should turn green: `Active: Gamepad palettes`.

On the first run both devices start with your current palettes. Change the palettes with one device, press a button on the other, and its palettes are the ones you had before.

---

## How it works

The game holds the palettes in the save data object in memory:

```
save._Item._ShortcutPallet
 ├─ _ShortcutData[8]        eight palettes
 │   ├─ Name, _Symbol       name and icon
 │   └─ _Items[12]          { Type, Value } per slot
 └─ CurrentIndex
```

**`lua/SeparateShortcutPalettes.lua`** reads that object, keeps a gamepad copy and a keyboard copy in `reframework/data/SeparateShortcutPalettes.json`, and watches which device you last used. When it changes, the script stores the palettes currently in the game into the device you just left and writes the other device's copy in. Edits made in the game are picked up within a second and stored in the active copy.

**Device detection** looks for a *new press*, not for something being held. The gamepad is read through the engine's merged `via.hid.GamePad` device (its button state), the keyboard through `reframework:is_key_down`. A stuck button or a held key can therefore never lock the mod to one device. Modifier keys, Insert, Home, End, Delete, PageUp/Down and anything pressed while Alt is held are ignored, so overlay hotkeys (REFramework, ReShade, Steam) do not count, and the mouse is not used at all — a click in a menu is not a keyboard press.

<details>
<summary>🧩 <b>Details worth knowing</b></summary>

**Nothing is written blindly.** A stored copy is validated before the first byte is written to the game. If the game refuses a write halfway, the palettes are rolled back and the error is shown in the menu.

**A blank save never overwrites your copies.** A save that is still loading looks like all palettes empty, so that state is never stored and the mod waits until a character has been stable for a moment before it touches anything.

**Lua file IO is sandboxed to `reframework/data`.** That is why the data file is a bare name and where it ends up.

**One file is left behind.** `reframework/data/SeparateShortcutPalettes.json` holds the settings and the two copies per character. Delete it and the mod simply starts over from your current palettes.

</details>

---

## Settings

In the REFramework menu (Insert), under **Separate Shortcut Palettes**.

- **Enabled** — turns the mod on and off. Off freezes the palettes as they are.
- **Also separate the selected palette number (experimental)** — off keeps the selected palette (1, 2, 3…) shared and only separates the contents. Leave it off unless you need it; see the notes.
- **Gamepad palettes / Keyboard palettes** — switch by hand. Normally this happens on its own.
- **Advanced** — the last detected input, the gamepad API in use, the last error, and *Copy current palettes to both devices* (asks to confirm).

> [!TIP]
> If nothing switches when you use the gamepad, open **Advanced**, press a few gamepad buttons and watch **Last input**. It should say *Gamepad*. If it never changes, please open an issue with your controller model and whether you use Steam Input.

---

## Limitations

- Only the DualSense has been tested. Other controllers should work — detection goes through the engine's own gamepad interface, not a driver — but that is not verified.
- Going back from the keyboard to the gamepad needs a gamepad **button** press. Moving only the sticks or pulling only the triggers may not switch.
- Switching devices while the palette editing screen is open changes the palettes at that moment; the list on screen may only refresh when you reopen it.
- Keyboard detection uses global key state, so a new key press while the game is not focused can also switch to the keyboard palettes.
- Emptying **all** 96 slots makes the mod pause (it looks like an unloaded save) until you put one item back.
- Each time a character is loaded, the mod writes its stored copy into the game. If you restore an older save or sync from another PC, the mod's copy wins; use *Copy current palettes to both devices* to keep what you see instead.
- A game update that renames the save fields shows *Shortcut palettes not found* in the menu, and the mod does nothing.

---

## Uninstall

Delete `reframework/autorun/SeparateShortcutPalettes.lua` (and `reframework/data/SeparateShortcutPalettes.json` if you like). Your palettes stay as they were at that moment — the ones of the device you used last. To keep the other device's set, switch to it in the menu before uninstalling.

---

## Building a release

```powershell
./build.ps1
```

Produces `out/SeparateShortcutPalettes.zip` containing the lua and a plain-text readme. There is nothing to compile.

## License

[MIT](LICENSE)
