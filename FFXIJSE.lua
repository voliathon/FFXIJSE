--[[
Copyright © 2026, mullerdane85-hash
Derived from JSE (Copyright © 2025, Nalfey of Asura) under the same
BSD 3-clause terms — see LICENSE.

All redistribution / modification terms from JSE preserved. This file
replaces JSE's main module with a GSUI-style window UI. The underlying
data modules (inventory.lua, currency.lua, job_equipment.lua, jobs/)
are unchanged from Nalfey's original work.
]]

_addon.name     = 'FFXIJSE'
_addon.author   = 'mullerdane85-hash (UI), Nalfey (data)'
_addon.version  = '0.1'
_addon.commands = {'ffxijse', 'fj'}

require('chat')
require('lists')
require('logger')
require('sets')
require('tables')
require('strings')
require('pack')

local config = require('config')
local res    = require('resources')
local texts  = require('texts')
local images = require('images')
local file   = require('files')
local slips  = require('slips')

-- Data modules from the original JSE addon (unmodified)
local job_equipment = require('job_equipment')
local currency      = require('currency')
local inventory     = require('inventory')

-- =============================================================================
-- Settings (persistent)
-- =============================================================================
local defaults = {
    pos     = { x = 220, y = 220 },
    visible = true,                 -- open by default; hidden state persists if user hides
    tab     = 'ARTIFACT',           -- ARTIFACT | RELIC | EMPYREAN
    job     = nil,                  -- nil = auto-detect from player
}
local settings = config.load(defaults)
config.save(settings)

-- =============================================================================
-- Visual constants — match GSUI's look
-- =============================================================================
local BORDER       = 3
local TITLE_BAR_H  = 30
local TAB_H        = 22
local TAB_GAP      = 4
local ROW_H        = 18
local PIECE_H      = 22         -- piece header row (slightly taller)
local SCROLL_BTN_H = 20
local PAD          = 8
local PANEL_W      = 540
local VISIBLE_ROWS = 22

local C_BORDER     = { 220, 70,  130, 200 }
local C_TITLE_BG   = { 240, 30,  60,  120 }
local C_TITLE_TXT  = { 255, 200, 200, 230 }
local C_BODY_BG    = { 200, 15,  15,  35  }
local C_TAB_ON     = { 240, 50,  100, 180 }
local C_TAB_OFF    = { 180, 30,  40,  70  }
local C_TAB_TXT_ON = { 255, 255, 255, 255 }
local C_TAB_TXT_OFF= { 255, 160, 160, 200 }
local C_JOB_TAG    = { 255, 230, 200, 130 }
local C_PIECE_NAME = { 255, 230, 230, 230 }
local C_PIECE_MAX  = { 255, 130, 230, 130 }    -- "Maxed" / +4 - green
local C_PIECE_READY= { 255, 130, 220, 130 }    -- ready to upgrade - green
local C_PIECE_NEED = { 255, 220, 180, 130 }    -- need more - amber
local C_MAT_HAVE   = { 255, 130, 220, 130 }
local C_MAT_NEED   = { 255, 220, 130, 130 }
local C_SUMMARY    = { 255, 230, 230, 150 }
local C_SCROLL_BG  = { 200, 40,  50,  90  }
local C_SCROLL_TXT = { 255, 255, 255, 255 }
local C_SCROLL_OFF = { 80,  40,  50,  90  }
local C_SCROLL_TXT_OFF = { 100, 200, 200, 200 }

-- Tier mapping ARMOR-TYPE → upgrade chain available
local TIER_ORDER  = { 'NQ', '+1', '+2', '+3', '+4' }
local TABS        = { 'ARTIFACT', 'RELIC', 'EMPYREAN' }
local TAB_LABELS  = { ARTIFACT = 'AF', RELIC = 'Relic', EMPYREAN = 'Empy' }

-- =============================================================================
-- UI element factories
-- =============================================================================
local function make_bg(x, y, w, h, c)
    return images.new({
        color = { alpha = c[1], red = c[2], green = c[3], blue = c[4] },
        pos   = { x = x, y = y },
        size  = { width = w, height = h },
        draggable = false,
    })
end

local function make_text(content, x, y, c, size, bold)
    local t = texts.new({
        text = { size = size or 10, font = 'Consolas',
            alpha = c[1] or 255, red = c[2] or 255, green = c[3] or 255, blue = c[4] or 255,
            stroke = { width = 1, alpha = 180, red = 0, green = 0, blue = 0 },
        },
        bg    = { alpha = 0 },
        pos   = { x = x, y = y },
        flags = { draggable = false, bold = bold or false },
    })
    t:text(content)
    return t
end

local function show(el)    if el and el.show    then el:show()    end end
local function destroy(el)
    if not el then return end
    if el.hide    then el:hide()    end
    if el.destroy then el:destroy() end
end

-- =============================================================================
-- Data helpers — wrap JSE's modules
-- =============================================================================

-- Returns the player's current job string (e.g. "WAR"), or nil if not logged in.
local function current_job()
    local p = windower.ffxi.get_player()
    return p and p.main_job
end

-- Returns the job to display: settings override > current main job > 'WAR'.
local function active_job()
    return settings.job or current_job() or 'WAR'
end

-- Get item count across all storage for a specific item name.
-- Currency-aware (Rem's Tale Ch.X, Apollyon Units, Gallimaufry, etc.)
local function get_currency_name(mat_name)
    local chapter = mat_name:match("^Rem's Tale Ch%.(%d+)$")
    if chapter then return "Rem's Tale Chapters " .. chapter .. " Stored" end
    if mat_name == 'Apollyon Units' or mat_name == 'Temenos Units' or mat_name == 'Gallimaufry' then
        return mat_name
    end
    return nil
end

local function count_material(mat_name)
    local curr_name = get_currency_name(mat_name)
    if curr_name then return currency.get_value(curr_name) or 0 end

    -- Scan all storages
    local total = 0
    local storage = inventory.get_local_storage() or {}
    for storage_name, items in pairs(storage) do
        if storage_name ~= 'gil' and storage_name ~= 'key items' then
            for item_id, qty in pairs(items) do
                local item = res.items[tonumber(item_id)]
                if item and item.name == mat_name then total = total + qty end
            end
        end
    end
    return total
end

-- For a piece definition (data row from job_equipment), find the highest tier
-- the player owns. Returns the tier string ('NQ', '+1', ..., '+4') or nil.
-- The piece definition format from JSE:
--   { {long_name, short_name}, slot_id, { ["+1"]=mats, ["+2"]=mats, ... } }
local function highest_owned_tier(piece)
    local names = piece[1]
    local long_name  = names[1]
    local short_name = names[2]
    local storage    = inventory.get_local_storage() or {}

    -- Check each tier in reverse order — the highest owned wins
    for i = #TIER_ORDER, 1, -1 do
        local tier = TIER_ORDER[i]
        local probe_name = (tier == 'NQ') and long_name or (long_name .. ' ' .. tier)
        local probe_short = (tier == 'NQ') and short_name or (short_name .. ' ' .. tier)
        for storage_name, items in pairs(storage) do
            if storage_name ~= 'gil' and storage_name ~= 'key items' then
                for item_id, _ in pairs(items) do
                    local item = res.items[tonumber(item_id)]
                    if item and (item.name == probe_name or item.name == probe_short
                                 or item.english == probe_name or item.english == probe_short) then
                        return tier
                    end
                end
            end
        end
    end
    return nil
end

-- Returns the tier label the piece is NEXT upgradeable to.
-- 'NQ' owned → '+1' next; '+4' owned → nil (maxed).
local function next_tier(owned)
    if not owned then return '+1' end   -- nothing owned, +1 is the first stage
    if owned == 'NQ' then return '+1' end
    if owned == '+1' then return '+2' end
    if owned == '+2' then return '+3' end
    if owned == '+3' then return '+4' end
    return nil    -- +4 = maxed
end

-- Returns true if every material for the given upgrade is available.
local function can_upgrade(mats)
    if not mats then return false end
    for _, mat in ipairs(mats) do
        if count_material(mat.name) < mat.count then return false end
    end
    return true
end

-- =============================================================================
-- UI state + element refs
-- =============================================================================
local ui = {
    el      = {},
    rows    = {},
    scroll  = 0,
    drag    = nil,
    rect    = {},
    total_w = PANEL_W,
    total_h = 0,
    -- Per-piece expanded materials show on rebuild — cache the rendered piece
    -- list so scroll math is consistent.
    cached_pieces = nil,
}

-- Get the list of pieces to show, with state per piece. Returns array of:
--   { piece, owned_tier, next_tier, can_upgrade, mats_for_next }
local function compute_piece_states()
    local job = active_job()
    local armor = settings.tab
    local data = (job_equipment[job] or {})[armor] or {}
    local out = {}
    for _, piece in ipairs(data) do
        local owned = highest_owned_tier(piece)
        local nxt   = next_tier(owned)
        local mats  = (nxt and piece[3]) and piece[3][nxt] or nil
        local ready = mats and can_upgrade(mats)
        table.insert(out, {
            piece = piece,
            name  = piece[1][1],
            owned = owned,
            next_tier = nxt,
            mats  = mats,
            ready = ready,
        })
    end
    return out
end

-- Each piece takes 1 header row + (#mats if not maxed) sub-rows
local function piece_block_height(p)
    local mat_count = (p.mats and #p.mats) or 0
    return PIECE_H + (mat_count * ROW_H) + 4   -- 4px gap
end

-- =============================================================================
-- Window build / destroy
-- =============================================================================

local function destroy_window()
    for _, e in pairs(ui.el)   do destroy(e) end
    for _, r in ipairs(ui.rows) do
        destroy(r.header); destroy(r.bg)
        if r.mats then for _, mt in ipairs(r.mats) do destroy(mt) end end
    end
    ui.el = {}
    ui.rows = {}
    ui.rect = {}
end

local function build_window()
    destroy_window()

    local pieces = compute_piece_states()
    ui.cached_pieces = pieces

    -- Compute total content height
    local content_h = 0
    for _, p in ipairs(pieces) do content_h = content_h + piece_block_height(p) end
    if content_h == 0 then content_h = PIECE_H end  -- placeholder for empty

    local panel_h = math.min(content_h + PAD * 2, VISIBLE_ROWS * ROW_H + PAD * 2)
    ui.total_h = BORDER * 2 + TITLE_BAR_H + panel_h + PAD * 2

    local x, y = settings.pos.x, settings.pos.y
    local W, H = ui.total_w, ui.total_h

    -- Border frame
    ui.el.border_top    = make_bg(x,              y,              W,      BORDER, C_BORDER)
    ui.el.border_bottom = make_bg(x,              y + H - BORDER, W,      BORDER, C_BORDER)
    ui.el.border_left   = make_bg(x,              y,              BORDER, H,      C_BORDER)
    ui.el.border_right  = make_bg(x + W - BORDER, y,              BORDER, H,      C_BORDER)

    -- Title bar
    local tb_x = x + BORDER
    local tb_y = y + BORDER
    local tb_w = W - BORDER * 2
    ui.el.title_bar  = make_bg(tb_x, tb_y, tb_w, TITLE_BAR_H, C_TITLE_BG)
    ui.el.title_text = make_text('FFXIJSE', tb_x + PAD, tb_y + 7, C_TITLE_TXT, 11, true)
    ui.rect.title_bar = { x = tb_x, y = tb_y, w = tb_w, h = TITLE_BAR_H }

    -- Tabs row in the title bar — 3 equal tabs (AF / Relic / Empy)
    -- Leave 80px on the right for the job tag.
    local tab_area_x = tb_x + 100
    local job_tag_w  = 80
    local tab_avail  = tb_w - 100 - job_tag_w
    local tab_w = math.floor((tab_avail - TAB_GAP * 2) / 3)
    local tab_y = tb_y + math.floor((TITLE_BAR_H - TAB_H) / 2)

    for i, key in ipairs(TABS) do
        local tx = tab_area_x + (i - 1) * (tab_w + TAB_GAP)
        local on = (settings.tab == key)
        local bg_c  = on and C_TAB_ON  or C_TAB_OFF
        local txt_c = on and C_TAB_TXT_ON or C_TAB_TXT_OFF
        local bg = make_bg(tx, tab_y, tab_w, TAB_H, bg_c)
        local label = TAB_LABELS[key]
        local label_x = tx + math.floor(tab_w / 2) - math.floor(#label * 6 / 2)
        local txt = make_text(label, label_x, tab_y + 4, txt_c, 11, on)
        ui.el['tab_bg_'  .. key] = bg
        ui.el['tab_txt_' .. key] = txt
        ui.rect['tab_'   .. key] = { x = tx, y = tab_y, w = tab_w, h = TAB_H }
    end

    -- Job tag (right side of title bar)
    local job = active_job()
    local jt_x = tb_x + tb_w - job_tag_w + 4
    ui.el.job_tag = make_text('[' .. job .. ']', jt_x, tb_y + 7, C_JOB_TAG, 11, true)
    -- (No click target — auto-detects current main job)

    -- Body
    local body_y = tb_y + TITLE_BAR_H
    local body_h = H - BORDER - TITLE_BAR_H - BORDER
    ui.el.body_bg = make_bg(tb_x, body_y, tb_w, body_h, C_BODY_BG)
    ui.rect.body = { x = tb_x, y = body_y, w = tb_w, h = body_h }

    if #pieces == 0 then
        ui.el.empty = make_text(
            'No ' .. settings.tab:lower() .. ' data for ' .. job .. '.',
            tb_x + PAD, body_y + PAD, C_SUMMARY, 11)
        for _, e in pairs(ui.el) do show(e) end
        return
    end

    -- Render pieces — apply ui.scroll offset
    local row_x = tb_x + PAD
    local cur_y = body_y + PAD - ui.scroll

    for _, p in ipairs(pieces) do
        local block_h = piece_block_height(p)
        local block_top = cur_y
        local block_bot = cur_y + block_h

        -- Skip pieces entirely above the visible area
        if block_bot > body_y and block_top < body_y + body_h - PAD then
            -- Header row
            local status_text, status_color
            if not p.next_tier then
                status_text  = '✓ MAXED (+4)'
                status_color = C_PIECE_MAX
            elseif not p.owned then
                status_text  = string.format('? owns NONE  →  +1')
                status_color = C_PIECE_NEED
            elseif p.ready then
                status_text  = string.format('✓ READY  %s → %s', p.owned, p.next_tier)
                status_color = C_PIECE_READY
            else
                status_text  = string.format('✗ NEED  %s → %s', p.owned, p.next_tier)
                status_color = C_PIECE_NEED
            end

            local header = make_text(
                string.format('%-26s  %s', p.name, status_text),
                row_x, cur_y, status_color, 11, false)
            local mat_texts = {}
            if p.mats then
                for i, mat in ipairs(p.mats) do
                    local have = count_material(mat.name)
                    local ok = have >= mat.count
                    local color = ok and C_MAT_HAVE or C_MAT_NEED
                    local check = ok and '✓' or '✗'
                    local line = string.format('   %-24s %d/%d  %s', mat.name, have, mat.count, check)
                    local mt = make_text(line, row_x, cur_y + PIECE_H + (i - 1) * ROW_H, color, 10)
                    table.insert(mat_texts, mt)
                end
            end
            table.insert(ui.rows, { header = header, mats = mat_texts })
        end

        cur_y = cur_y + block_h
    end

    for _, e in pairs(ui.el) do show(e) end
    for _, r in ipairs(ui.rows) do
        if r.header then show(r.header) end
        if r.mats then for _, mt in ipairs(r.mats) do show(mt) end end
    end
end

local function show_window()
    settings.visible = true
    config.save(settings)
    -- Inventory refresh before showing so data is fresh
    inventory.update()
    currency.request_update()
    build_window()
end

local function hide_window()
    settings.visible = false
    config.save(settings)
    destroy_window()
end

local function toggle_window()
    if settings.visible then hide_window() else show_window() end
end

local function refresh_window()
    if settings.visible then
        inventory.update()
        currency.request_update()
        build_window()
    end
end

-- =============================================================================
-- Mouse + keyboard
-- =============================================================================
local function in_rect(x, y, r)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function is_over_window(x, y)
    if not settings.visible then return false end
    return x >= settings.pos.x and x <= settings.pos.x + ui.total_w
        and y >= settings.pos.y and y <= settings.pos.y + ui.total_h
end

local function scroll_by(delta)
    -- Total content height vs visible
    local pieces = ui.cached_pieces or {}
    local content_h = 0
    for _, p in ipairs(pieces) do content_h = content_h + piece_block_height(p) end
    local visible_h = ui.total_h - BORDER * 2 - TITLE_BAR_H - PAD * 2
    local max_scroll = math.max(0, content_h - visible_h)
    ui.scroll = math.max(0, math.min(max_scroll, ui.scroll + delta))
    if settings.visible then build_window() end
end

windower.register_event('mouse', function(mtype, x, y, delta, blocked)
    if not settings.visible then return false end
    if blocked then return false end

    -- Mouse move
    if mtype == 0 then
        if ui.drag then
            settings.pos.x = x - ui.drag.dx
            settings.pos.y = y - ui.drag.dy
            build_window()
            return true
        end
        return is_over_window(x, y)
    end

    -- LMB up — release drag from anywhere
    if mtype == 2 then
        if ui.drag then
            ui.drag = nil
            config.save(settings)
            return true
        end
        return is_over_window(x, y)
    end

    if not is_over_window(x, y) then return false end

    -- LMB down
    if mtype == 1 then
        if in_rect(x, y, ui.rect.title_bar) then
            -- Check tab clicks first
            for _, key in ipairs(TABS) do
                if in_rect(x, y, ui.rect['tab_' .. key]) then
                    if settings.tab ~= key then
                        settings.tab = key
                        ui.scroll = 0
                        config.save(settings)
                        refresh_window()
                    end
                    return true
                end
            end
            ui.drag = { dx = x - settings.pos.x, dy = y - settings.pos.y }
            return true
        end
        return true
    end

    -- Mouse wheel
    if mtype == 10 then
        scroll_by(delta > 0 and -30 or 30)
        return true
    end

    return true   -- swallow other events over our window
end)

-- O key toggle (DIK_O = 0x18 = 24)
-- Chat-open guard so typing 'o' in chat doesn't fire the toggle.
local DIK_O = 24
windower.register_event('keyboard', function(dik, pressed, flags, blocked)
    if blocked or not pressed then return end
    if dik ~= DIK_O then return end
    local info = windower.ffxi.get_info()
    if info and info.chat_open then return end
    toggle_window()
end)

-- =============================================================================
-- Commands
-- =============================================================================
windower.register_event('addon command', function(cmd, ...)
    cmd = (cmd or 'toggle'):lower()
    local args = {...}

    if cmd == 'toggle' or cmd == 't' or cmd == '' then
        toggle_window()
    elseif cmd == 'show' or cmd == 'open' then
        show_window()
    elseif cmd == 'hide' or cmd == 'close' then
        hide_window()
    elseif cmd == 'refresh' or cmd == 'r' then
        refresh_window()
        windower.add_to_chat(207, '[FFXIJSE] refreshed.')
    elseif cmd == 'af' or cmd == 'artifact' then
        settings.tab = 'ARTIFACT'; ui.scroll = 0; config.save(settings); refresh_window()
    elseif cmd == 'relic' then
        settings.tab = 'RELIC'; ui.scroll = 0; config.save(settings); refresh_window()
    elseif cmd == 'empy' or cmd == 'empyrean' then
        settings.tab = 'EMPYREAN'; ui.scroll = 0; config.save(settings); refresh_window()
    elseif cmd == 'job' then
        local j = (args[1] or ''):upper()
        if j == '' or j == 'AUTO' or j == 'CLEAR' then
            settings.job = nil
            windower.add_to_chat(207, '[FFXIJSE] auto-detect job: ' .. active_job())
        elseif job_equipment[j] then
            settings.job = j
            windower.add_to_chat(207, '[FFXIJSE] override job: ' .. j)
        else
            windower.add_to_chat(167, '[FFXIJSE] unknown job: ' .. j .. ' (try WAR, MNK, WHM, BLM, ...)')
            return
        end
        config.save(settings); ui.scroll = 0; refresh_window()
    elseif cmd == 'help' or cmd == '?' then
        windower.add_to_chat(207, '[FFXIJSE] Commands:')
        windower.add_to_chat(160, '  //fj            — toggle window (also: J key)')
        windower.add_to_chat(160, '  //fj af / relic / empy — switch tab')
        windower.add_to_chat(160, '  //fj job <JOB> — override job (or //fj job auto)')
        windower.add_to_chat(160, '  //fj refresh   — re-scan inventory + currency')
    else
        windower.add_to_chat(167, '[FFXIJSE] unknown command: ' .. cmd)
    end
end)

-- =============================================================================
-- Lifecycle
-- =============================================================================
windower.register_event('load', function()
    -- Defer slightly so player + inventory are ready, then open the
    -- window if the saved-state says so (default visible=true so it
    -- opens on first install). User can hide with O key or //fj hide.
    coroutine.schedule(function()
        if settings.visible then show_window() end
    end, 2)
end)

windower.register_event('job change', function()
    coroutine.schedule(refresh_window, 1)
end)

windower.register_event('zone change', function()
    coroutine.schedule(refresh_window, 2)
end)

windower.register_event('unload', function()
    destroy_window()
end)
