-- hold-speed.lua
-- Hold a mouse button to temporarily boost playback speed (default: 2x).
-- Releasing the button restores the previous speed.
-- Moving the mouse while holding the button does NOT cancel the boost --
-- only a real button-up event ends it.
--
-- Installation:
--   Copy this file to your mpv "scripts" folder:
--     Linux:   ~/.config/mpv/scripts/hold-speed.lua
--     Windows: %APPDATA%\mpv\scripts\hold-speed.lua
--     macOS:   ~/.config/mpv/scripts/hold-speed.lua
--
-- Configuration (optional):
--   Create ~/.config/mpv/script-opts/hold-speed.conf to override defaults:
--
--     speed=3.0
--     button=MBTN_RIGHT
--     show_osd=yes
--     osd_text=Speed: %.1fx
--     osd_duration=0.6

local options = {
    -- multiplier applied while the button is held down
    speed = 2.0,
    -- which mouse button triggers the speed-up
    -- common values: MBTN_LEFT, MBTN_RIGHT, MBTN_MID
    button = "MBTN_LEFT",
    -- show an on-screen message while boosted
    show_osd = true,
    -- text template; %.1f is replaced with the resulting speed
    osd_text = "Speed: %.1fx",
    -- how long (in seconds) the "restored" message lingers after release
    osd_duration = 0.6,
}

(require 'mp.options').read_options(options, "hold-speed")

local original_speed = nil
local is_held = false

local function speed_up()
    if is_held then return end
    is_held = true
    original_speed = mp.get_property_number("speed", 1.0)
    local boosted = original_speed * options.speed
    mp.set_property("speed", boosted)

    if options.show_osd then
        -- duration 0 = stays until explicitly replaced/cleared
        mp.osd_message(string.format(options.osd_text, boosted), 9999)
    end
end

local function speed_down()
    if not is_held then return end
    is_held = false
    local restored = original_speed or 1.0
    mp.set_property("speed", restored)
    original_speed = nil

    if options.show_osd then
        mp.osd_message(string.format("Speed: %.1fx", restored), options.osd_duration)
    end
end

-- Bind press (down) and release (up) events for the chosen button.
-- complex = true gives us the event table so we can tell down from up.
-- Mouse movement never fires this binding, so dragging the cursor
-- around the video while held has no effect on the boost.
mp.add_forced_key_binding(options.button, "hold-speed-toggle", function(table)
    if table.event == "down" then
        speed_up()
    elseif table.event == "up" or table.event == "repeat" then
        -- "up" ends the hold. Some builds can fire repeat on long holds;
        -- we ignore repeats (do nothing) so only "up" releases the boost.
        if table.event == "up" then
            speed_down()
        end
    end
end, { complex = true })

-- Safety nets: never leave playback stuck at boosted speed.
mp.register_event("end-file", function()
    if is_held then
        is_held = false
        if original_speed then
            mp.set_property("speed", original_speed)
        end
        original_speed = nil
    end
end)

-- If the window loses focus or mpv is paused/seeked externally while held,
-- the bound key's "up" event may not arrive (e.g. alt-tabbing away while
-- still physically holding the mouse button). Reset on file load just in
-- case state ever gets stuck across files.
mp.register_event("start-file", function()
    is_held = false
    original_speed = nil
end)
