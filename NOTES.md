# Developer notes

The README is for people installing the mod. This is for whoever picks the code
back up — how the palettes were found, what is verified, and what is left.

## State

Works in the game on the author's setup: DualSense, REFramework, keyboard and mouse.
Switching in both directions and edits on one device staying off the other were checked
by hand. The hardening added afterwards (rollback, blank-save guard, edge detection,
the key exclusions) was only exercised through normal play, and the rollback and
damaged-data paths were never triggered for real. There is no automated test — the code
runs inside the game and there is no way to load it outside.

## Where the palettes live

`app.SaveDataManager.getCurrentUserSaveData()` returns the current character's
`app.savedata.cUserSaveParam`. The palettes are in `_Item._ShortcutPallet`
(`cShortcutPalletParam`):

- `_ShortcutData` — array of 8 `cCustomShortcutParam`: `Name`, `_Symbol`
  (`IconCategory`, `IconType`, `IconColorTypeValue`) and `_Items`, 12
  `cShortcutItemParam` with `Type` and `Value`. Empty slot is `Type = -1`.
- `CurrentIndex`.

Edits made in the palette screen show up in that object immediately, which is what
makes a poll-and-swap approach possible at all. The game keeps no per-device copy;
both devices read this one.

Palettes 1–3 hold 8 filled slots each of `Type 0` (items); "palette 4" is 12 filled slots
of `Type 6`/`7`; the rest are empty. The mod does not care what the types mean — it
copies them verbatim.

### Dead end: `_CustomShortcutMySet`

The obvious name, and the first place looked at. It is a 36-set × 12-slot store in
which every slot is `Type = -1` — an unused feature. Snapshots taken before and after
editing a palette did not differ in it. The real palettes are under `_Item`.

### `CurrentIndex` reads 256

At runtime the game reported `CurrentIndex` as `256`, not 0–7, and the saved value at
first launch was 0. The field is probably narrower than the int the reflection layer
reads, or carries flags in its upper bytes. Because of that the mod refuses to *write*
an index outside 0–7, and the "separate the selected palette number" option is marked
experimental: it may simply do nothing. It is off by default, and switching it on does
not risk the palette contents.

## Finding it without a type dump

REFramework's lua on the target build has no `sdk.get_tdb`, so types cannot be
enumerated. The layout above was found by a temporary probe script that walked the save
object through reflection (`get_type_definition():get_fields()` / `get_field`), wrote it
to a text file, and let two snapshots taken around one manual palette edit be diffed. The
edit changing exactly one `Value` in `_ShortcutPallet` is what settled it. The probe is
not part of the repo.

Two things learned the hard way:

- `io.open` paths are relative to `reframework/data`, not the game folder.
- REFramework's imgui cannot take Korean input and cannot draw Korean text, so the menu
  is English only and uses fixed buttons instead of text boxes.

## Device detection

The game's own "current input device" was not found (no type list to search). The mod
detects it itself:

- **Gamepad** — `via.hid.GamePad` native singleton, `get_MergedDevice` (with
  `getMergedDevice(0)` tried first). A new non-zero value of `get_Button` counts as
  input. `get_AnalogL/R` come back as plain numbers here rather than a vector, so they
  are read only when they arrive as userdata; in practice the sticks do not count. That
  is why returning to the gamepad needs a button press.
- **Keyboard** — `reframework:is_key_down` over a fixed list of keys.

### Why a new press, not a held state

The first version treated "any button held" as gamepad activity and "any key held" as
keyboard activity, and kept the current device when both were true. A single stuck
button bit would then lock it to the gamepad forever. Rising edges cannot lock, and
"the latest input wins" is the behaviour people expect.

### Why the keyboard list is narrow, and why no mouse

- Clicking in the REFramework menu is a mouse press. The first attempt suppressed all
  input while the menu was open, which also suppressed the keyboard and broke testing
  with the menu open. Dropping the mouse altogether was simpler and lost nothing: a
  keyboard-and-mouse player presses keys constantly.
- Insert (REFramework), Home (ReShade), Shift+Tab (Steam overlay) and Alt+Tab are
  pressed while playing on a gamepad. Modifiers, Insert/Home/End/Delete/PageUp/PageDown,
  Print, Pause, CapsLock and anything pressed while Alt is held are left out.

## Safety behaviour

- `apply` validates the whole stored profile and the game's array shapes before the first
  `set_field`; if a write still fails partway it re-applies the state captured just
  before, then reports the error.
- A capture where every slot is `-1` never replaces a non-empty copy. A save that is
  still loading looks exactly like that, and so would the title screen.
- A character must be visible for one second before its palettes are touched.
- After an error the script waits two seconds before trying again instead of failing on
  every frame.
- Two automatic switches are at least 0.4 s apart; the data file is written at most once
  a second.

## Open items

- **Other controllers are untested.** Detection uses the engine's merged device, so it
  should be fine for anything the game itself sees as a pad, but this is unverified.
  Trigger-only input may not register — it depends on whether L2/R2 appear in the
  button bitmask.
- **Window focus** — `reframework:is_key_down` is global, so a key pressed in another
  window counts. No focus check was found.
- **Palette screen open while switching** — whether the on-screen list refreshes, and
  whether the game writes a stale working copy back on close, was not investigated. The
  earlier finding that edits land in the save object immediately suggests it does not.
- If the game's own input-device value is ever located, use it instead of the
  polling above; it would also fix the sticks and triggers.
