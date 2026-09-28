-- Separate Shortcut Palettes (Keyboard & Gamepad)  -  Monster Hunter Wilds, REFramework
-- Keeps the shortcut palettes of the keyboard and the gamepad separate.
--
-- Background: the game stores the shortcut palettes once
--   (save._Item._ShortcutPallet._ShortcutData: 8 palettes x 12 slots {Type, Value}),
-- and both the gamepad and the keyboard read/write that single copy, so editing one changes the other.
--
-- How this script works: it keeps two copies (gamepad / keyboard) in reframework/data/SeparateShortcutPalettes.json.
-- Whenever the device you last gave input with changes, it
--   1) stores the palettes currently in the game into the copy of the device you just left, and
--   2) writes the copy of the new device into the game.
-- Copies are kept per character. On first run both copies start out equal to your current palettes.
--
-- Uninstall: delete this file. Your palettes stay as they were at that moment.

local CFG_FILE    = "SeparateShortcutPalettes.json"
local PALLET_COUNT, ITEM_COUNT = 8, 12
local DEVICE_NAME = { pad = "Gamepad", kb = "Keyboard" }

local MIN_SWITCH_GAP   = 0.4   -- seconds between two automatic device switches (anti flapping)
local LOAD_SETTLE_TIME = 1.0   -- a character must be visible this long before we touch its palettes
local WRITE_INTERVAL   = 1.0   -- minimum seconds between two writes of the data file
local RETRY_DELAY      = 2.0   -- after an error, wait this long before trying again

local function sf(fn, ...)
    local ok, r = pcall(fn, ...)
    if ok then return r end
    return nil
end

-- ───────── settings / data file ─────────
local db = json.load_file(CFG_FILE)
if type(db) ~= "table" then db = {} end
if type(db.settings) ~= "table" then db.settings = {} end
if type(db.chars) ~= "table" then db.chars = {} end
if type(db.settings.enabled) ~= "boolean" then db.settings.enabled = true end
if type(db.settings.separate_index) ~= "boolean" then db.settings.separate_index = false end
db.version = 1

local status = "Waiting for a character to load..."
local last_error = ""
local dirty, last_write = false, -1000

local function write_db()
    json.dump_file(CFG_FILE, db)
    dirty = false
    last_write = os.clock()
end

-- ───────── save data access ─────────
local function get_save()
    local mgr = sdk.get_managed_singleton("app.SaveDataManager")
    if not mgr then return nil end
    local m = mgr:get_type_definition():get_method("getCurrentUserSaveData")
    if not m then return nil end
    local r = sf(m.call, m, mgr)
    if type(r) == "number" then r = r ~= 0 and sf(sdk.to_managed_object, sdk, r) or nil end
    return r
end

local function get_pallet(save)
    local item = sf(save.get_field, save, "_Item")
    return item and sf(item.get_field, item, "_ShortcutPallet") or nil
end

local function char_id(save)
    local id = sf(save.get_field, save, "HunterId")
    if id == nil then id = sf(save.get_field, save, "HunterShortId") end
    return id ~= nil and tostring(id) or "default"
end

-- An empty / all-zero id means the save is still being loaded (or is a placeholder).
local function is_real_id(id)
    return id ~= "" and not id:match("^[0%-]*$")
end

local function num(v)
    if type(v) ~= "number" then error("unexpected non-number palette value") end
    return math.floor(v)
end

local function is_int(v)
    return type(v) == "number" and v == math.floor(v)
end

local function elements_of(arr)
    return arr and sf(arr.get_elements, arr) or nil
end

-- Copy the game's current palettes into a plain Lua table.
local function capture(pal)
    local elems = elements_of(pal:get_field("_ShortcutData"))
    if not elems or #elems ~= PALLET_COUNT then error("palette count mismatch") end
    local out = { index = num(pal:get_field("CurrentIndex")), pallets = {} }
    for i, e in ipairs(elems) do
        local items = elements_of(e:get_field("_Items"))
        if not items or #items ~= ITEM_COUNT then error("item count mismatch") end
        local name = e:get_field("Name")
        local rec = { name = type(name) == "string" and name or "", items = {}, sym = {} }
        for j, it in ipairs(items) do
            rec.items[j] = { num(it:get_field("Type")), num(it:get_field("Value")) }
        end
        local s = e:get_field("_Symbol")
        if s then
            rec.sym = { num(s:get_field("IconCategory")), num(s:get_field("IconType")), num(s:get_field("IconColorTypeValue")) }
        end
        out.pallets[i] = rec
    end
    return out
end

-- Strict check of a stored copy (the data file may have been edited or damaged).
local function valid_profile(p)
    if type(p) ~= "table" or type(p.pallets) ~= "table" or #p.pallets ~= PALLET_COUNT then return false end
    for _, rec in ipairs(p.pallets) do
        if type(rec) ~= "table" or type(rec.name) ~= "string" then return false end
        if type(rec.items) ~= "table" or #rec.items ~= ITEM_COUNT then return false end
        for _, it in ipairs(rec.items) do
            if type(it) ~= "table" or not is_int(it[1]) or not is_int(it[2]) then return false end
        end
        if type(rec.sym) ~= "table" or (#rec.sym ~= 0 and #rec.sym ~= 3) then return false end
        for _, v in ipairs(rec.sym) do
            if not is_int(v) then return false end
        end
    end
    return true
end

-- True when every slot is empty. A freshly created / not yet loaded save looks like this,
-- so such a state is never allowed to overwrite a stored copy.
local function is_blank(p)
    for _, rec in ipairs(p.pallets) do
        for _, it in ipairs(rec.items) do
            if it[1] ~= -1 then return false end
        end
    end
    return true
end

-- Write a stored copy into the game. Everything is validated before the first write.
local function apply(pal, p)
    if not valid_profile(p) then error("invalid profile") end
    local elems = elements_of(pal:get_field("_ShortcutData"))
    if not elems or #elems ~= PALLET_COUNT then error("palette count mismatch") end
    for _, e in ipairs(elems) do
        local items = elements_of(e:get_field("_Items"))
        if not items or #items ~= ITEM_COUNT then error("item count mismatch") end
    end
    for i, e in ipairs(elems) do
        local rec = p.pallets[i]
        local items = elements_of(e:get_field("_Items"))
        for j, it in ipairs(items) do
            it:set_field("Type", math.floor(rec.items[j][1]))
            it:set_field("Value", math.floor(rec.items[j][2]))
        end
        local s = e:get_field("_Symbol")
        if s and #rec.sym == 3 then
            s:set_field("IconCategory", math.floor(rec.sym[1]))
            s:set_field("IconType", math.floor(rec.sym[2]))
            s:set_field("IconColorTypeValue", math.floor(rec.sym[3]))
        end
        if (e:get_field("Name") or "") ~= rec.name then
            local ms = sf(sdk.create_managed_string, rec.name)
            if ms then sf(e.set_field, e, "Name", ms) end
        end
    end
    -- Only write a selected-palette index that is a valid palette number.
    local idx = p.index
    if db.settings.separate_index and is_int(idx) and idx >= 0 and idx < PALLET_COUNT then
        pal:set_field("CurrentIndex", math.floor(idx))
    end
end

-- Cheap fingerprint used to notice edits made in the game.
local function sig(p)
    local t = {}
    for _, rec in ipairs(p.pallets) do
        t[#t + 1] = rec.name
        for _, it in ipairs(rec.items) do t[#t + 1] = it[1] .. ":" .. it[2] end
        for _, v in ipairs(rec.sym) do t[#t + 1] = v end
    end
    if db.settings.separate_index then t[#t + 1] = "idx" .. tostring(p.index) end
    return table.concat(t, "|")
end

-- ───────── input device detection ─────────
-- A device counts as "used" on a NEW press (rising edge), not while something is merely held down.
-- That way a stuck button or a key held in the background can never lock the mod to one device.
local pad_mgr = sf(sdk.get_native_singleton, "via.hid.GamePad")
local pad_td  = sf(sdk.find_type_definition, "via.hid.GamePad")
local pad_method = "?"
local kb_available = true

local function get_pad_device()
    if not pad_mgr or not pad_td then pad_method = "unavailable"; return nil end
    local dev = sf(sdk.call_native_func, pad_mgr, pad_td, "getMergedDevice", 0)
    if dev then pad_method = "getMergedDevice(0)"; return dev end
    dev = sf(sdk.call_native_func, pad_mgr, pad_td, "get_MergedDevice")
    if dev then pad_method = "get_MergedDevice"; return dev end
    pad_method = "unavailable"
    return nil
end

-- Keyboard keys only; the mouse is ignored on purpose (clicks in menus would count as keyboard input).
-- Modifiers and utility keys (Shift/Ctrl/Alt, Insert, Home, End, Delete, PageUp/Down, Print, Pause, CapsLock)
-- are left out: they are used by overlays and tools (REFramework, ReShade, Steam) even while playing on a gamepad.
local VK = {}
local function add_range(a, b) for k = a, b do VK[#VK + 1] = k end end
add_range(0x08, 0x0D)               -- Backspace, Tab, Enter
VK[#VK + 1] = 0x1B                  -- Esc
add_range(0x20, 0x20)               -- Space
add_range(0x25, 0x28)               -- arrow keys
add_range(0x30, 0x39); add_range(0x41, 0x5A)   -- 0-9, A-Z
add_range(0x60, 0x87)               -- numpad, F1-F24
add_range(0xBA, 0xC0); add_range(0xDB, 0xDF)   -- punctuation
local VK_ALT = 0x12                 -- Alt+key combos are system/overlay shortcuts (e.g. Alt+Tab), never game input

local prev_btn, prev_analog, prev_keys = 0, { false, false }, {}
local input_primed = false   -- the first poll only records the current state

-- Returns pad_event, kb_event for this frame.
local function poll_input()
    local pad_ev, kb_ev = false, false

    local dev = get_pad_device()
    if dev then
        local b = sf(dev.call, dev, "get_Button")
        b = type(b) == "number" and math.floor(b) or 0
        if b ~= 0 and b ~= prev_btn then pad_ev = true end
        prev_btn = b
        for i, n in ipairs({ "get_AnalogL", "get_AnalogR" }) do
            local v = sf(dev.call, dev, n)
            local active = false
            -- Struct returns sometimes arrive as a plain number; only read x/y from real userdata.
            if type(v) == "userdata" then
                local x, y = sf(function() return v.x end), sf(function() return v.y end)
                active = type(x) == "number" and type(y) == "number" and (math.abs(x) > 0.5 or math.abs(y) > 0.5)
            end
            if active and not prev_analog[i] then pad_ev = true end
            prev_analog[i] = active
        end
    else
        prev_btn, prev_analog[1], prev_analog[2] = 0, false, false
    end

    if kb_available then
        local ok = pcall(function()
            local alt = reframework:is_key_down(VK_ALT) and true or false
            for _, k in ipairs(VK) do
                local down = reframework:is_key_down(k) and true or false
                if down and not prev_keys[k] and not alt then kb_ev = true end
                prev_keys[k] = down
            end
        end)
        if not ok then kb_available = false; kb_ev = false end
    end

    if not input_primed then
        input_primed = true
        return false, false
    end
    return pad_ev, kb_ev
end

-- ───────── main logic ─────────
local cur_id, entry = nil, nil       -- current character id, db.chars[id]
local sync_t = 0
local last_dev, last_input_dev, last_input_t = nil, nil, 0
local last_switch_t = -1000
local seen_id, seen_since = nil, 0
local retry_at = 0

local function set_active_status()
    status = "Active: " .. DEVICE_NAME[entry.active] .. " palettes"
end

local function init_char(pal, id)
    local live = capture(pal)
    local e = db.chars[id]
    local usable = type(e) == "table" and (e.active == "pad" or e.active == "kb")
        and valid_profile(e.pad) and valid_profile(e.kb)
    if not usable then
        if is_blank(live) then
            status = "Waiting: this character has no palette items yet (set one to start)"
            return false
        end
        -- First run for this character: both copies start out equal to the current palettes.
        e = { active = "pad", pad = live, kb = capture(pal) }   -- two separate tables
        db.chars[id] = e
        write_db()
    else
        -- The copy of the device used last time is the source of truth.
        apply(pal, e[e.active])
    end
    cur_id, entry = id, e
    last_dev = e.active
    set_active_status()
    return true
end

-- Store the live palettes in the copy of the current device, then load the copy of `dev`.
-- Raises an error (after rolling back) if the game refuses the write.
local function switch_to(pal, dev, force)
    if not entry or entry.active == dev then return end
    local now = os.clock()
    if not force and now - last_switch_t < MIN_SWITCH_GAP then return end
    local live = capture(pal)
    if is_blank(live) and not is_blank(entry[entry.active]) then
        status = "Waiting for palettes to load..."
        return
    end
    entry[entry.active] = live
    local ok, err = pcall(apply, pal, entry[dev])
    if not ok then
        pcall(apply, pal, live)   -- roll back a half-written palette
        error(err)
    end
    entry.active = dev
    last_switch_t = now
    dirty = true
    set_active_status()
end

local function tick()
    local now = os.clock()
    local pad_ev, kb_ev = poll_input()
    if kb_ev and not pad_ev then
        last_dev, last_input_dev, last_input_t = "kb", "kb", now
    elseif pad_ev and not kb_ev then
        last_dev, last_input_dev, last_input_t = "pad", "pad", now
    end

    local save = get_save()
    local pal = save and get_pallet(save)
    if not save then
        entry, cur_id, seen_id = nil, nil, nil
        status = "Waiting for a character to load..."
        return
    end
    if not pal then
        entry, cur_id = nil, nil
        status = "Shortcut palettes not found (unsupported game version?)"
        return
    end

    local id = char_id(save)
    if not entry or cur_id ~= id then
        -- Wait until the character has been stable for a moment before touching anything.
        if not is_real_id(id) then seen_id = nil; entry, cur_id = nil, nil; return end
        if seen_id ~= id then seen_id, seen_since = id, now end
        if now - seen_since < LOAD_SETTLE_TIME then status = "Loading character..."; return end
        if dirty then write_db() end
        if not init_char(pal, id) then retry_at = now + 1.0 end
        return
    end

    -- Follow the device the player is using.
    if last_dev and last_dev ~= entry.active then
        switch_to(pal, last_dev, false)
    end

    -- Once per second: if the palettes were edited in-game, store the edit in the active copy.
    if now - sync_t >= 1.0 then
        sync_t = now
        local live = capture(pal)
        if not (is_blank(live) and not is_blank(entry[entry.active])) and sig(live) ~= sig(entry[entry.active]) then
            entry[entry.active] = live
            dirty = true
        end
    end
    if dirty and now - last_write >= WRITE_INTERVAL then write_db() end
end

re.on_frame(function()
    if not db.settings.enabled then return end
    local now = os.clock()
    if now < retry_at then return end
    local ok, e = pcall(tick)
    if ok then
        last_error = ""
    else
        last_error = tostring(e)
        status = "Error - see Advanced"
        retry_at = now + RETRY_DELAY
    end
end)

re.on_script_reset(function()
    if dirty then pcall(write_db) end
end)

-- ───────── menu ─────────
local confirm = nil   -- nil | "sync"

local function tip(text)
    if imgui.is_item_hovered() then imgui.set_tooltip(text) end
end

-- Runs fn(pal) with the live palettes; reports failures in the status line.
local function with_pallet(fn)
    local ok, e = pcall(function()
        local s = get_save()
        local pal = s and get_pallet(s)
        if not pal then error("no save data") end
        fn(pal)
    end)
    if ok then
        last_error = ""
    else
        last_error = tostring(e)
        status = "Error - see Advanced"
    end
end

local function draw_confirm(kind, label, tooltip, action)
    if confirm == kind then
        imgui.text_colored("Are you sure?", 0xFF50B4FF)
        imgui.same_line()
        if imgui.button("Yes##" .. kind) then action(); confirm = nil end
        imgui.same_line()
        if imgui.button("Cancel##" .. kind) then confirm = nil end
    else
        if imgui.button(label) then confirm = kind end
        tip(tooltip)
    end
end

re.on_draw_ui(function()
    if not imgui.tree_node("Separate Shortcut Palettes") then return end

    local ch, v = imgui.checkbox("Enabled", db.settings.enabled)
    if ch then db.settings.enabled = v; write_db() end
    tip("Keep separate shortcut palettes for keyboard and gamepad.\nTurning this off freezes the palettes as they are.")

    -- status
    if last_error ~= "" then
        imgui.text_colored(status, 0xFF5050FF)
    elseif entry then
        imgui.text_colored(status, 0xFF66DD66)
    else
        imgui.text(status)
    end

    local ch2, v2 = imgui.checkbox("Also separate the selected palette number (experimental)", db.settings.separate_index)
    if ch2 then db.settings.separate_index = v2; write_db() end
    tip("Off: only the palette contents are separate; the selected palette (1, 2, 3...) is shared.\nOn: each device also remembers which palette was selected.\nExperimental - leave off unless you need it.")

    if entry then
        imgui.spacing()
        imgui.text("Switch manually")
        if imgui.button("Gamepad palettes") then
            with_pallet(function(pal) last_dev = "pad"; switch_to(pal, "pad", true) end)
        end
        tip("Load the gamepad palettes right now.\nNormally this happens automatically when you press a gamepad button.")
        imgui.same_line()
        if imgui.button("Keyboard palettes") then
            with_pallet(function(pal) last_dev = "kb"; switch_to(pal, "kb", true) end)
        end
        tip("Load the keyboard palettes right now.\nNormally this happens automatically when you press a keyboard key.")
    end

    if imgui.tree_node("Advanced") then
        if last_input_dev then
            imgui.text(string.format("Last input: %s (%.0fs ago)", DEVICE_NAME[last_input_dev], os.clock() - last_input_t))
        else
            imgui.text("Last input: none yet")
        end
        imgui.text("Gamepad API: " .. pad_method)
        imgui.text("Keyboard detection: " .. (kb_available and "ok" or "unavailable"))
        if last_error ~= "" then imgui.text_colored("Last error: " .. last_error, 0xFF5050FF) end
        if entry then
            imgui.spacing()
            draw_confirm("sync", "Copy current palettes to both devices",
                "Makes the gamepad and keyboard copies identical to the palettes you have right now\n(the copy of the other device is overwritten).",
                function()
                    with_pallet(function(pal)
                        entry.pad = capture(pal)
                        entry.kb = capture(pal)
                        write_db()
                        status = "Both devices now use the current palettes"
                    end)
                end)
        end
        imgui.tree_pop()
    end

    imgui.tree_pop()
end)
