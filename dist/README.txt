Separate Shortcut Palettes (Keyboard & Gamepad) v1.0 - Monster Hunter Wilds
==================================================================

Keeps your keyboard and gamepad shortcut palettes SEPARATE.

In the base game both input methods share one set of shortcut palettes, so editing
a palette with the gamepad also changes it for the keyboard (and vice versa).
This mod stores one set per device and swaps automatically when you switch between
gamepad and keyboard.

FEATURES
- Separate palette contents (items, names, icons) for gamepad and keyboard
- Automatic switching: press a gamepad button -> gamepad palettes, press a keyboard
  key -> keyboard palettes
- Per-character: every hunter has their own two sets
- Optional: also remember the selected palette number (1/2/3...) per device

REQUIREMENTS
- REFramework (Monster Hunter Wilds build)

INSTALLATION
1. Copy the "reframework" folder into your game folder
   (steamapps\common\MonsterHunterWilds), merging with the existing one.
   The result should be: MonsterHunterWilds\reframework\autorun\SeparateShortcutPalettes.lua
2. Start the game and load a character.
3. Press Insert (REFramework menu) -> Script Generated UI -> "Separate Shortcut Palettes".
   The status line should turn green: "Active: Gamepad palettes".

FIRST RUN
Both devices start with your current palettes. Edit the palettes with one device,
then press a button on the other device - its palettes will be the ones you had
before, and edits there no longer touch the first device.

MENU
- Enabled: turn the mod on/off. Off freezes the palettes as they are.
- Also separate the selected palette number (experimental): off = only contents are
  separate; on = each device also remembers which palette (1/2/3...) was selected.
  Leave it off unless you need it.
- Gamepad palettes / Keyboard palettes: switch manually (normally automatic).
- Advanced:
  * Copy current palettes to both devices - makes both sets identical (asks to confirm)
  * Shows detected input and the last error, if any

FILE CREATED (in MonsterHunterWilds\reframework\data)
- SeparateShortcutPalettes.json   your two palette sets per character + settings

UNINSTALL
Delete reframework\autorun\SeparateShortcutPalettes.lua (and SeparateShortcutPalettes.json if you like).
Your palettes stay as they were at that moment, i.e. the ones of the device you used last.
Only one set remains in the game afterwards, so if you want the other set, switch to that
device first (menu: Gamepad palettes / Keyboard palettes) and then uninstall.

TROUBLESHOOTING - THE MOD DOES NOT SWITCH WHEN I USE MY GAMEPAD
Open the REFramework menu -> "Separate Shortcut Palettes" -> Advanced, then press a few gamepad
buttons (face buttons, D-pad, bumpers) and look at the "Last input" line:
- It says "Gamepad": detection works. Try the manual buttons "Gamepad palettes" /
  "Keyboard palettes" and report anything odd.
- It never changes, or "Gamepad API" says "unavailable": your controller is not seen through
  the game's gamepad interface. Please report your controller model, whether you use Steam
  Input, and whether it is wired/Bluetooth. Until then use the manual buttons.
Only buttons and D-pad are used for detection. Moving only the analog sticks or pulling only
the triggers may not switch; press any button once.

KNOWN LIMITATIONS
- If you deliberately empty ALL 96 palette slots, the mod treats that as "save not loaded yet"
  and pauses until you put at least one item back.
- Going back from keyboard to gamepad needs a gamepad BUTTON press; moving only the
  stick does not switch.
- If you switch device while the palette editing screen is open, the palettes change
  at that moment; the on-screen list may only refresh when you reopen it.
- Keyboard detection uses global key state, so a new key press while the game window is
  not focused (e.g. typing in another app) can also switch to the keyboard palettes.
- The mouse is not used for detection; only keyboard keys switch to the keyboard palettes.
  Modifier keys (Shift/Ctrl/Alt), Insert, Home, End, Delete, PageUp/Down and any key pressed
  while Alt is held are ignored, so overlay hotkeys (REFramework, ReShade, Steam) do not count.
- Each time a character is loaded, the mod writes its stored copy for the last used device into
  the game. If you restore an older save or sync palettes from another PC, the mod's copy wins;
  use "Copy current palettes to both devices" (Advanced) to adopt the palettes you see instead.
- A game update that renames the save data fields will show
  "Shortcut palettes not found" in the menu; the mod does nothing in that case.

NOTES
Palette data is read and written through the game's save data object in memory, and
gets saved by the game's normal saving. Back up your save before trying any mod.
