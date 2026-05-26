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
local texts  = require('texts')
local images = require('images')

-- Icon pipeline (copied from GSUI; originally Rubenator's EquipViewer code,
-- BSD-licensed). Extracts item icons from FFXI DAT files into BMPs cached
-- under libs/cache, then exposes them via icon_handler.create_image /
-- load_icon. Same API as GSUI for consistency.
local icon_handler = require('libs/icon_handler')

-- Globals (NOT local) — Nalfey's data modules (inventory.lua, etc.) reference
-- these as globals (no `local` keyword) so we have to expose them globally
-- here too. Don't change to `local` or inventory.lua errors out with
-- "attempt to index global 'slips' (a nil value)" at line 207.
res   = require('resources')
file  = require('files')
slips = require('slips')

-- Data modules from the original JSE addon (unmodified — also globals so
-- inter-module references like `currency.get_value(...)` work even if we
-- only need a local handle on this side).
job_equipment = require('job_equipment')
currency      = require('currency')
inventory     = require('inventory')

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
local ROW_H        = 18                  -- material sub-row height
local ICON_SIZE    = 32                  -- per-piece icon dimensions
local PIECE_H      = ICON_SIZE + 6       -- min piece row height (icon-driven)
local SCROLL_BTN_H = 20
local PAD          = 8
local FOOTER_H     = 38                  -- bottom button strip
local BTN_H        = 26
local PANEL_W      = 580                 -- wider to fit icon + name + materials
local PANEL_BODY_H = 460                 -- FIXED body height; content scrolls inside

-- Job picker dropdown (3 cols × 8 rows = 24 cells; 23 entries: Auto + 22 jobs)
local DROPDOWN_COLS = 3
local DROPDOWN_ROWS = 8
local DROPDOWN_CELL_W = 56
local DROPDOWN_CELL_H = 22
local DROPDOWN_W = DROPDOWN_COLS * DROPDOWN_CELL_W + 4
local DROPDOWN_H = DROPDOWN_ROWS * DROPDOWN_CELL_H + 4
local JOB_LIST = {
    'AUTO', 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD',
    'DRK',  'BST', 'BRD', 'RNG', 'SAM', 'NIN', 'DRG', 'SMN',
    'BLU',  'COR', 'PUP', 'DNC', 'SCH', 'GEO', 'RUN',
}

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
-- Footer button colors
local C_SEL_HIGHLIGHT = { 100, 200, 150, 50 }  -- selected piece row tint
local C_BTN_GATHER_ON  = { 220, 50,  120, 60 }  -- green, ready
local C_BTN_GATHER_OFF = { 130, 30,  60,  35 }  -- dim, no piece selected
local C_BTN_TRADE_ON   = { 220, 110, 80,  50 }  -- amber, ready
local C_BTN_TRADE_OFF  = { 130, 60,  40,  30 }  -- dim
local C_BTN_TXT_ON     = { 255, 240, 240, 240 }
local C_BTN_TXT_OFF    = { 200, 160, 160, 160 }
-- Job dropdown
local C_DROP_BG        = { 240, 20,  35,  60 }
local C_DROP_CELL_OFF  = { 220, 40,  55,  90 }
local C_DROP_CELL_ON   = { 240, 70,  130, 180 }  -- active job
local C_DROP_TXT_OFF   = { 255, 200, 200, 220 }
local C_DROP_TXT_ON    = { 255, 255, 255, 255 }
local C_JOB_TAG_HOVER  = { 255, 255, 230, 160 }

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

-- Name → item_id lookup table. Built lazily on first call because res.items
-- has ~65k entries and iterating at addon-load adds visible latency. Built
-- once and reused for every piece-row icon resolution after that.
local _item_id_cache
local function item_id_by_name(name)
    if not name or name == '' then return nil end
    if not _item_id_cache then
        _item_id_cache = {}
        for id, item in pairs(res.items) do
            if item.name    then _item_id_cache[item.name]    = id end
            if item.english then _item_id_cache[item.english] = id end
        end
    end
    return _item_id_cache[name]
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
--   { {long_name [, short_name]}, slot_id, { ["+1"]=mats, ["+2"]=mats, ... } }
-- short_name is OPTIONAL — many entries (e.g. {"Brioso Roundlet"}) only have
-- a long name. Default short_name to long_name to keep the probe loop safe.
local function highest_owned_tier(piece)
    local names = piece[1] or {}
    local long_name  = names[1]
    local short_name = names[2] or long_name
    if not long_name then return nil end   -- malformed data row — bail
    local storage    = inventory.get_local_storage() or {}

    -- Check each tier in reverse order — the highest owned wins
    for i = #TIER_ORDER, 1, -1 do
        local tier = TIER_ORDER[i]
        local probe_name  = (tier == 'NQ') and long_name  or (long_name  .. ' ' .. tier)
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
-- Bag IDs and names
-- =============================================================================
-- windower.ffxi.get_items() returns bags keyed by NAME (items.inventory,
-- items.satchel, items.wardrobe2, etc.). windower.ffxi.put_item() takes
-- the numeric bag ID. So we keep both — id and name — and index back and
-- forth.
local BAG = {
    inventory = 0,  safe     = 1,  storage   = 2,  temporary = 3,
    locker    = 4,  satchel  = 5,  sack      = 6,  case      = 7,
    wardrobe  = 8,  safe2    = 9,  wardrobe2 = 10, wardrobe3 = 11,
    wardrobe4 = 12, wardrobe5= 13, wardrobe6 = 14, wardrobe7 = 15,
    wardrobe8 = 16,
}
local BAG_NAMES = {}                            -- id  → name
for name, id in pairs(BAG) do BAG_NAMES[id] = name end

-- Short labels for the per-material "currently in [...]" tag in the UI.
local BAG_SHORT = {
    [BAG.inventory] = 'Inv',
    [BAG.safe]      = 'Safe',
    [BAG.safe2]     = 'Safe2',
    [BAG.storage]   = 'Stor',
    [BAG.locker]    = 'Lock',
    [BAG.satchel]   = 'Sat',
    [BAG.sack]      = 'Sack',
    [BAG.case]      = 'Case',
    [BAG.wardrobe]  = 'Wd1',
    [BAG.wardrobe2] = 'Wd2',
    [BAG.wardrobe3] = 'Wd3',
    [BAG.wardrobe4] = 'Wd4',
    [BAG.wardrobe5] = 'Wd5',
    [BAG.wardrobe6] = 'Wd6',
    [BAG.wardrobe7] = 'Wd7',
    [BAG.wardrobe8] = 'Wd8',
}

-- Equipment slot → /unequip command argument. windower.ffxi.get_items()
-- returns equipment keyed by these names, mostly matching what /unequip
-- expects except for the left/right pairs.
local UNEQUIP_SLOT = {
    main = 'main', sub = 'sub', range = 'range', ammo = 'ammo',
    head = 'head', neck = 'neck',
    left_ear  = 'ear1',  right_ear  = 'ear2',
    body = 'body', hands = 'hands',
    left_ring = 'ring1', right_ring = 'ring2',
    back = 'back', waist = 'waist', legs = 'legs', feet = 'feet',
}

-- Mog-house-only bags. Player can only access these while standing in a
-- mog house — pull-from attempts elsewhere fail silently. Mog House is
-- usually accessible: safe, safe2, storage, locker. Sack/Satchel/Case are
-- field-accessible.
local MOG_ONLY = {
    [BAG.safe]    = 'Mog Safe',
    [BAG.safe2]   = 'Mog Safe 2',
    [BAG.storage] = 'Storage',
    [BAG.locker]  = 'Mog Locker',
}

-- Accessible-from-anywhere bags
local FIELD_BAGS = {
    BAG.inventory, BAG.wardrobe, BAG.wardrobe2, BAG.wardrobe3, BAG.wardrobe4,
    BAG.wardrobe5, BAG.wardrobe6, BAG.wardrobe7, BAG.wardrobe8,
    BAG.satchel,   BAG.sack,     BAG.case,
}

-- Detect if player is in a mog house. The mog-house-only bags become
-- "enabled" only while standing in the mog house. Outside, they show
-- enabled=false (or zero size), so the player can't pull from them.
local function in_mog_house()
    local items = windower.ffxi.get_items()
    if not items then return false end
    return items.safe ~= nil and items.safe.enabled == true
end

-- Walk every bag and find slots holding the given item name.
-- Returns list of {bag_id, slot, count, mog_only, bag_name}.
local function find_item_locations(item_name)
    local target_id = item_id_by_name(item_name)
    if not target_id then return {} end

    local out = {}
    local items = windower.ffxi.get_items()
    if not items then return out end

    local function scan(bag_id)
        local bag_name = BAG_NAMES[bag_id]
        local bag = bag_name and items[bag_name]
        if not bag or type(bag) ~= 'table' then return end
        for slot = 1, (bag.max or 80) do
            local it = bag[slot]
            if it and type(it) == 'table' and it.id == target_id and (it.count or 0) > 0 then
                table.insert(out, {
                    bag_id   = bag_id,
                    bag_name = bag_name,
                    slot     = slot,
                    count    = it.count,
                    mog_only = MOG_ONLY[bag_id] ~= nil,
                })
            end
        end
    end

    -- Field bags first (they're always pullable)
    for _, b in ipairs(FIELD_BAGS) do scan(b) end
    -- Then mog-only (might be pullable, might not — caller decides)
    for b, _ in pairs(MOG_ONLY) do scan(b) end
    return out
end

-- Count free slots in main inventory
local function inventory_free_slots()
    local items = windower.ffxi.get_items()
    if not items or not items.inventory then return 0 end
    local inv = items.inventory
    local used = 0
    for slot = 1, (inv.max or 80) do
        local it = inv[slot]
        if it and type(it) == 'table' and (it.count or 0) > 0 then
            used = used + 1
        end
    end
    return (inv.max or 80) - used
end

-- For a given item name, build a comma-joined short bag tag like
-- "[Inv, Wd2]" or "[Equip]" for the UI. Returns "" when not owned anywhere.
-- "[Equip]" is added FIRST in the list when the item is currently worn.
local function bag_summary(item_name)
    local target_id = item_id_by_name(item_name)
    if not target_id then return '' end

    local seen, list = {}, {}
    local function add(short)
        if short and not seen[short] then
            seen[short] = true
            table.insert(list, short)
        end
    end

    local items = windower.ffxi.get_items()
    if not items then return '' end

    -- Equipment first (always show "[Equip]" up front if worn)
    if items.equipment then
        for slot, eq in pairs(items.equipment) do
            if type(eq) == 'table' and eq.bag and eq.slot and eq.slot > 0 then
                local bag = items[BAG_NAMES[eq.bag] or '']
                local it = bag and bag[eq.slot]
                if it and type(it) == 'table' and it.id == target_id then
                    add('Equip')
                end
            end
        end
    end

    -- Then every other bag
    for _, loc in ipairs(find_item_locations(item_name)) do
        add(BAG_SHORT[loc.bag_id] or '?')
    end

    if #list == 0 then return '' end
    return '[' .. table.concat(list, ', ') .. ']'
end

-- Find the equipment slot the given item ID is currently equipped to (if any).
-- Returns (slot_unequip_name, bag_id, bag_slot) or nil.
local function find_equipped_slot(item_id)
    if not item_id then return nil end
    local items = windower.ffxi.get_items()
    if not items or not items.equipment then return nil end
    for slot, eq in pairs(items.equipment) do
        if type(eq) == 'table' and eq.bag and eq.slot and eq.slot > 0 then
            local bag = items[BAG_NAMES[eq.bag] or '']
            local it = bag and bag[eq.slot]
            if it and type(it) == 'table' and it.id == item_id then
                return UNEQUIP_SLOT[slot] or slot, eq.bag, eq.slot
            end
        end
    end
    return nil
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
    -- Selected piece (for the Gather / Trade buttons to act on). Stored as
    -- piece name + tier since piece-state objects rebuild every refresh.
    selected_name = nil,
    -- Job-picker dropdown open state (toggled by clicking the [JOB] tag)
    dropdown_open = false,
    dropdown_el   = {},
    dropdown_rect = {},          -- cell-key → {x, y, w, h, job}
}

-- =============================================================================
-- Gather Items: walk all bags, move material stacks to inventory
-- =============================================================================
local function notify(msg, color)
    windower.add_to_chat(color or 207, '[FFXIJSE] ' .. msg)
end

-- Plan + execute a gather for the materials of one piece's next upgrade.
-- - Skips materials already at-target count in main inventory.
-- - For materials in mog-only bags when player isn't in a mog house,
--   reports "please go to mog house first" and skips that material.
-- - Checks free inventory slots up front; if insufficient, reports and bails.
local function gather_for_piece(piece_state)
    if not piece_state then notify('No piece selected. Click a row first.', 167); return end
    if not piece_state.mats or #piece_state.mats == 0 then
        notify('"' .. piece_state.name .. '" has no pending upgrade materials.', 167); return
    end

    local in_mog = in_mog_house()
    local mog_blocked = {}     -- materials sitting in mog-only bags
    local moves = {}           -- planned moves: {bag_id, slot, count, name}
    local still_need = {}      -- per-material remaining need (after inv-on-hand)
    local unequip_first = nil  -- if non-nil, /unequip <slot> before put_item

    -- ===== Piece itself =====
    -- The trade NPC requires the piece + materials in main inventory. Find
    -- the OWNED-tier piece's current location. If it's equipped, schedule
    -- an /unequip before the put_item. If it's already in inventory, skip.
    local owned_probe = (piece_state.owned == 'NQ') and piece_state.name
                        or (piece_state.name .. ' ' .. piece_state.owned)
    local piece_id = item_id_by_name(owned_probe) or piece_state.item_id
    if piece_id then
        local items = windower.ffxi.get_items()
        local inv = items and items.inventory
        local already_in_inv = false
        if inv then
            for slot = 1, (inv.max or 80) do
                local it = inv[slot]
                if it and type(it) == 'table' and it.id == piece_id then
                    already_in_inv = true
                    break
                end
            end
        end
        if not already_in_inv then
            local eq_slot, eq_bag, eq_slot_idx = find_equipped_slot(piece_id)
            if eq_slot then
                -- Currently equipped — unequip first, then move from its wardrobe slot
                unequip_first = eq_slot
                table.insert(moves, {
                    bag_id = eq_bag, slot = eq_slot_idx, count = 1,
                    name = owned_probe, is_piece = true,
                })
            else
                -- Look in non-equipped storage
                local locs = find_item_locations(owned_probe)
                local placed = false
                for _, loc in ipairs(locs) do
                    if loc.bag_id ~= BAG.inventory then
                        if loc.mog_only and not in_mog then
                            mog_blocked[owned_probe] = (mog_blocked[owned_probe] or 0) + 1
                        else
                            table.insert(moves, {
                                bag_id = loc.bag_id, slot = loc.slot, count = 1,
                                name = owned_probe, is_piece = true,
                            })
                            placed = true
                            break    -- one piece is enough
                        end
                    end
                end
                if not placed and not mog_blocked[owned_probe] then
                    still_need[owned_probe] = 1
                end
            end
        end
    end

    -- For each material, see how much we already have in main inventory
    local items = windower.ffxi.get_items() or {}
    local function count_in_inv(target_id)
        local inv = items.inventory; if not inv then return 0 end
        local total = 0
        for slot = 1, (inv.max or 80) do
            local it = inv[slot]
            if it and type(it) == 'table' and it.id == target_id then
                total = total + (it.count or 0)
            end
        end
        return total
    end

    for _, m in ipairs(piece_state.mats) do
        -- Skip currency-only materials (Rem's Tale Ch.X, Apollyon Units, etc.)
        -- — these aren't physical items in any bag, so there's nothing to move.
        if get_currency_name(m.name) then
            -- noop; currency tracked separately
        else
            local target_id = item_id_by_name(m.name)
            if target_id then
                local have_inv = count_in_inv(target_id)
                local need = m.count - have_inv
                if need > 0 then
                    -- Pull from field bags first
                    local locs = find_item_locations(m.name)
                    local taken = 0
                    for _, loc in ipairs(locs) do
                        if taken >= need then break end
                        if loc.bag_id == BAG.inventory then
                            -- already in inv, skip
                        elseif loc.mog_only and not in_mog then
                            mog_blocked[m.name] = (mog_blocked[m.name] or 0) + loc.count
                        else
                            local take = math.min(loc.count, need - taken)
                            table.insert(moves, {
                                bag_id = loc.bag_id, slot = loc.slot, count = take,
                                name = m.name,
                            })
                            taken = taken + take
                        end
                    end
                    if taken + have_inv < m.count then
                        still_need[m.name] = m.count - have_inv - taken
                    end
                end
            end
        end
    end

    if #moves == 0 then
        -- Nothing to move — either everything already in inv, or everything
        -- blocked / missing
        if next(mog_blocked) then
            notify('Materials in mog house storage. Please go to your mog house first:', 167)
            for name, c in pairs(mog_blocked) do
                notify('  ' .. name .. ' (' .. c .. ' in safe/locker/storage)', 167)
            end
        elseif next(still_need) then
            notify('Missing materials (none found in any storage):', 167)
            for name, c in pairs(still_need) do
                notify('  ' .. name .. ' x' .. c, 167)
            end
        else
            notify('All materials already in inventory.', 158)
        end
        return
    end

    -- Make sure we have enough inventory slots for incoming stacks
    local free = inventory_free_slots()
    if free < #moves then
        notify(('Inventory full — need %d more free slot(s) for %d material stack(s).')
               :format(#moves - free, #moves), 167)
        return
    end

    -- Execute moves. windower.ffxi.put_item(bag_id, slot, count) takes a
    -- COUNT parameter and will split-stack when count < stack size — so if
    -- you need 12 SMN Cards and the stack has 99, this moves exactly 12,
    -- leaving 87 in the source bag.
    --
    -- If the piece is currently equipped, unequip first and delay the moves
    -- ~0.7s so the server processes the unequip before the put_item.
    notify(('Gathering %d stack(s) for %s...'):format(#moves, piece_state.name), 158)
    local function do_moves()
        for _, mv in ipairs(moves) do
            windower.ffxi.put_item(mv.bag_id, mv.slot, mv.count)
            local from = BAG_SHORT[mv.bag_id] or BAG_NAMES[mv.bag_id] or '?'
            local tag = mv.is_piece and '  (piece) +' or '  +'
            notify(('%s %s x%d  (from %s)'):format(tag, mv.name, mv.count, from), 160)
        end
    end
    if unequip_first then
        notify('  /unequip ' .. unequip_first .. '  (piece is currently worn)', 167)
        windower.send_command('input /unequip ' .. unequip_first)
        coroutine.schedule(do_moves, 0.7)
    else
        do_moves()
    end

    -- Surface any still-blocked items so the user knows what's left
    if next(mog_blocked) then
        notify('Still in mog house storage (go to mog house for these):', 167)
        for name, c in pairs(mog_blocked) do notify('  ' .. name .. ' x' .. c, 167) end
    end
    if next(still_need) then
        notify('Still missing (not in any storage):', 167)
        for name, c in pairs(still_need) do notify('  ' .. name .. ' x' .. c, 167) end
    end
end

-- =============================================================================
-- Trade to NPC: open trade with current target and stage the items
-- =============================================================================
-- Sends 0x032 (Trade Request) to open the trade window with the targeted
-- NPC, then 0x034 (Trade Offer) for each material stack to fill the trade
-- slots. Does NOT send the 0x033 confirm — user must press OK manually.
local function u8(n)  return string.char(n % 256) end
local function u16(n) return u8(n) .. u8(math.floor(n / 256)) end
local function u32(n)
    return u8(n) .. u8(math.floor(n / 256)) .. u8(math.floor(n / 65536)) .. u8(math.floor(n / 16777216))
end

local function trade_for_piece(piece_state)
    if not piece_state then notify('No piece selected. Click a row first.', 167); return end
    if not piece_state.mats or #piece_state.mats == 0 then
        notify('"' .. piece_state.name .. '" has no pending upgrade materials.', 167); return
    end

    local target = windower.ffxi.get_mob_by_target('t')
    if not target then
        notify('No target selected. Target the upgrade NPC first, then click Trade.', 167); return
    end
    if target.spawn_type ~= 16 then   -- 16 = NPC
        notify('Target must be an NPC. Currently targeting: ' .. (target.name or '?'), 167); return
    end

    -- Build the list of inventory slots to put in the trade window
    local items = windower.ffxi.get_items()
    if not items or not items.inventory then notify('Inventory not available.', 167); return end
    local inv = items.inventory

    local trade_stacks = {}    -- list of {item_id, count, inv_slot}
    local still_need = {}
    for _, m in ipairs(piece_state.mats) do
        if get_currency_name(m.name) then
            -- currencies don't go through trade — they're consumed automatically
        else
            local target_id = item_id_by_name(m.name)
            if target_id then
                -- Find this item in inventory; build stacks until satisfied
                local needed = m.count
                for slot = 1, (inv.max or 80) do
                    if needed <= 0 then break end
                    local it = inv[slot]
                    if it and type(it) == 'table' and it.id == target_id and (it.count or 0) > 0 then
                        local take = math.min(it.count, needed)
                        table.insert(trade_stacks, { item_id = target_id, count = take, inv_slot = slot, name = m.name })
                        needed = needed - take
                    end
                end
                if needed > 0 then still_need[m.name] = needed end
            end
        end
    end

    if next(still_need) then
        notify('Some materials are NOT in main inventory — run Gather first:', 167)
        for name, c in pairs(still_need) do notify('  ' .. name .. ' x' .. c, 167) end
        return
    end

    if #trade_stacks == 0 then
        notify('No physical items needed for this upgrade (currencies only).', 158); return
    end

    if #trade_stacks > 8 then
        notify(('Trade only fits 8 stacks; this upgrade needs %d.'):format(#trade_stacks), 167); return
    end

    -- Send packets
    local function build_packet(id, body)
        local size = math.ceil((4 + #body) / 4)
        return u16(id + (size * 256 * 64)) .. u32(0) .. body
    end

    -- 0x032 Trade Request
    local req = u32(target.id) .. u16(target.index) .. u8(0) .. u8(0)
    windower.packets.inject_outgoing(0x032, build_packet(0x032, req))

    notify(('Trade window opening with %s (%d stacks)...'):format(target.name, #trade_stacks), 158)

    -- Stagger the trade-slot fills so the server processes them in order
    for i, st in ipairs(trade_stacks) do
        coroutine.schedule(function()
            local body = u32(st.count) .. u16(st.item_id) .. u8(st.inv_slot) .. u8(i - 1)
            windower.packets.inject_outgoing(0x034, build_packet(0x034, body))
            notify(('  slot %d: %s x%d'):format(i - 1, st.name, st.count), 160)
        end, 0.3 * i)
    end

    coroutine.schedule(function()
        notify('Trade staged. Press OK in the trade window to confirm.', 158)
    end, 0.3 * (#trade_stacks + 1))
end

-- Get the list of pieces to show, with state per piece. Returns array of:
--   { piece, owned_tier, next_tier, can_upgrade, mats_for_next }
local function compute_piece_states()
    local job = active_job()
    local armor = settings.tab
    local data = (job_equipment[job] or {})[armor] or {}
    local out = {}
    for _, piece in ipairs(data) do
        local owned = highest_owned_tier(piece)
        -- List mode: only show pieces the player owns (any tier including NQ)
        if owned then
            local nxt   = next_tier(owned)
            local mats  = (nxt and piece[3]) and piece[3][nxt] or nil
            local ready = mats and can_upgrade(mats)
            local long_name = (piece[1] or {})[1] or '?'
            -- Resolve the owned-tier item ID so we can pull its icon.
            local probe = (owned == 'NQ') and long_name or (long_name .. ' ' .. owned)
            local item_id = item_id_by_name(probe) or item_id_by_name(long_name)
            table.insert(out, {
                piece = piece,
                name  = long_name,
                owned = owned,
                item_id = item_id,
                next_tier = nxt,
                mats  = mats,
                ready = ready,
            })
        end
    end
    return out
end

-- Each owned piece takes 1 row when maxed, else 1 row + #mats sub-rows.
-- (The left column is always 1 row — name + current tier. The right column
-- expands vertically into the material list.)
local function piece_block_height(p)
    if not p.mats then return PIECE_H end
    local mat_count = #p.mats
    return math.max(PIECE_H, PIECE_H + (mat_count * ROW_H) - ROW_H + 4)
end

-- =============================================================================
-- Window build / destroy
-- =============================================================================

-- Destroy the job-picker dropdown elements (called when closing / rebuilding)
local function destroy_dropdown()
    for _, e in pairs(ui.dropdown_el) do destroy(e) end
    ui.dropdown_el   = {}
    ui.dropdown_rect = {}
end

-- Render the job-picker dropdown right below the title bar, anchored to the
-- right edge (under the job tag).
local function build_dropdown()
    destroy_dropdown()
    if not ui.dropdown_open then return end

    -- Anchor: right edge under the job tag
    local x = settings.pos.x + ui.total_w - BORDER - DROPDOWN_W - 2
    local y = settings.pos.y + BORDER + TITLE_BAR_H + 2

    ui.dropdown_el.bg = make_bg(x, y, DROPDOWN_W, DROPDOWN_H, C_DROP_BG)

    local active = settings.job or 'AUTO'
    if not settings.job then active = 'AUTO' end

    for idx, j in ipairs(JOB_LIST) do
        local col = (idx - 1) % DROPDOWN_COLS
        local row = math.floor((idx - 1) / DROPDOWN_COLS)
        local cx = x + 2 + col * DROPDOWN_CELL_W
        local cy = y + 2 + row * DROPDOWN_CELL_H
        local is_active = (j == active)

        ui.dropdown_el['c_' .. j] = make_bg(cx + 1, cy + 1, DROPDOWN_CELL_W - 2, DROPDOWN_CELL_H - 2,
            is_active and C_DROP_CELL_ON or C_DROP_CELL_OFF)

        -- Center the 3-letter job label
        local label_w_px = #j * 6                   -- monospace approx
        local label_x = cx + math.floor((DROPDOWN_CELL_W - label_w_px) / 2)
        local txt_color = is_active and C_DROP_TXT_ON or C_DROP_TXT_OFF
        ui.dropdown_el['t_' .. j] = make_text(j, label_x, cy + 4, txt_color, 11, is_active)

        ui.dropdown_rect['c_' .. j] = { x = cx, y = cy, w = DROPDOWN_CELL_W, h = DROPDOWN_CELL_H, job = j }
    end

    for _, e in pairs(ui.dropdown_el) do show(e) end
end

local function destroy_window()
    destroy_dropdown()
    for _, e in pairs(ui.el)   do destroy(e) end
    for _, r in ipairs(ui.rows) do
        destroy(r.header); destroy(r.bg); destroy(r.icon)
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

    -- FIXED window height — body is always PANEL_BODY_H tall, scrollable.
    -- Stops the window from jumping around in size as you change tabs /
    -- jobs / inventory.
    ui.total_h = BORDER * 2 + TITLE_BAR_H + PANEL_BODY_H

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

    -- Job tag (right side of title bar) — clickable to open the job picker
    -- dropdown. The "*" suffix indicates an override is active (vs auto-
    -- detected from main_job).
    local job = active_job()
    local jt_x = tb_x + tb_w - job_tag_w + 4
    local tag_label = settings.job and ('[' .. job .. '*]') or ('[' .. job .. ']')
    local tag_color = ui.dropdown_open and C_JOB_TAG_HOVER or C_JOB_TAG
    ui.el.job_tag = make_text(tag_label, jt_x, tb_y + 7, tag_color, 11, true)
    ui.rect.job_tag = { x = jt_x - 2, y = tb_y, w = job_tag_w - 4, h = TITLE_BAR_H }

    -- Body — reserve FOOTER_H at the bottom for the action buttons
    local body_y = tb_y + TITLE_BAR_H
    local body_h = H - BORDER - TITLE_BAR_H - BORDER - FOOTER_H
    ui.el.body_bg = make_bg(tb_x, body_y, tb_w, body_h, C_BODY_BG)
    ui.rect.body = { x = tb_x, y = body_y, w = tb_w, h = body_h }

    -- Footer area + two buttons (Gather Items + Trade to NPC)
    local footer_y = body_y + body_h
    ui.el.footer_bg = make_bg(tb_x, footer_y, tb_w, FOOTER_H, C_TITLE_BG)

    local btn_w = math.floor((tb_w - PAD * 3) / 2)
    local btn_y = footer_y + math.floor((FOOTER_H - BTN_H) / 2)
    local g_x = tb_x + PAD
    local t_x = g_x + btn_w + PAD

    -- Find the currently-selected piece (if any) — used to decide button colors
    local selected = nil
    for _, p in ipairs(pieces) do
        if p.name == ui.selected_name then selected = p; break end
    end
    local can_gather = selected ~= nil and selected.mats and #selected.mats > 0
    local can_trade  = can_gather   -- same prereq

    ui.el.btn_gather_bg = make_bg(g_x, btn_y, btn_w, BTN_H,
        can_gather and C_BTN_GATHER_ON or C_BTN_GATHER_OFF)
    ui.el.btn_gather_text = make_text(
        'Gather Items',
        g_x + math.floor(btn_w / 2) - 38, btn_y + 6,
        can_gather and C_BTN_TXT_ON or C_BTN_TXT_OFF, 11, true)
    ui.rect.btn_gather = { x = g_x, y = btn_y, w = btn_w, h = BTN_H, enabled = can_gather }

    ui.el.btn_trade_bg = make_bg(t_x, btn_y, btn_w, BTN_H,
        can_trade and C_BTN_TRADE_ON or C_BTN_TRADE_OFF)
    ui.el.btn_trade_text = make_text(
        'Trade to NPC',
        t_x + math.floor(btn_w / 2) - 38, btn_y + 6,
        can_trade and C_BTN_TXT_ON or C_BTN_TXT_OFF, 11, true)
    ui.rect.btn_trade = { x = t_x, y = btn_y, w = btn_w, h = BTN_H, enabled = can_trade }

    if #pieces == 0 then
        -- Distinguish "no data" (no upgrade table for this job/armor)
        -- from "you don't own any pieces of this set yet".
        local has_data = job_equipment[job] and job_equipment[job][settings.tab]
        local msg
        if not has_data or #has_data == 0 then
            msg = 'No ' .. settings.tab:lower() .. ' data for ' .. job .. '.'
        else
            msg = 'No ' .. settings.tab:lower() .. ' pieces owned on ' .. job
                  .. ' yet.\n(' .. #has_data .. ' pieces exist for this set —\n'
                  .. ' acquire one to see it here.)'
        end
        ui.el.empty = make_text(msg, tb_x + PAD, body_y + PAD, C_SUMMARY, 11)
        for _, e in pairs(ui.el) do show(e) end
        return
    end

    -- List mode — owned pieces only. Three-column-ish layout:
    --   [icon] [name + tier + status]              [materials | MAXED]
    --    32px   ~210px                             ~280px
    --
    -- Scroll offsets the entire content; pieces outside the visible body
    -- band are skipped on render to save image-element creation work.
    local icon_x  = tb_x + PAD
    local name_x  = icon_x + ICON_SIZE + 8
    local right_x = tb_x + PAD + ICON_SIZE + 8 + 210
    local cur_y   = body_y + PAD - ui.scroll
    local body_top = body_y
    local body_bot = body_y + body_h - PAD

    for _, p in ipairs(pieces) do
        local block_h   = piece_block_height(p)
        local block_top = cur_y
        local block_bot = cur_y + block_h

        -- Only render pieces that intersect the visible body band
        if block_bot > body_top and block_top < body_bot then
            -- Selected-row highlight (subtle tint behind the row)
            local row_hl = nil
            if ui.selected_name == p.name then
                row_hl = make_bg(icon_x - 2, cur_y - 2, tb_w - PAD * 2 + 4, block_h, C_SEL_HIGHLIGHT)
            end

            -- ===== LEFT: icon + name + status =====
            local left_icon, left_color
            if not p.next_tier then
                left_icon  = '✓'           -- maxed
                left_color = C_PIECE_MAX
            elseif p.ready then
                left_icon  = '✓'           -- ready to upgrade
                left_color = C_PIECE_READY
            else
                left_icon  = '✗'           -- need more
                left_color = C_PIECE_NEED
            end

            -- 32x32 item icon. icon_handler.create_image returns a hidden
            -- image element; load_icon binds the texture by item ID.
            -- If item_id couldn't be resolved (rare), the image stays
            -- empty alpha=0 so it doesn't render a gray box.
            local icon = icon_handler.create_image({
                pos  = { x = icon_x, y = cur_y },
                size = { width = ICON_SIZE, height = ICON_SIZE },
            })
            if p.item_id then
                icon_handler.load_icon(icon, p.item_id)
            end

            -- Name text sits ~6px down so it visually centers next to the icon
            local owned_label = (p.owned == 'NQ') and '' or (' ' .. p.owned)
            local left_str = string.format('%s %s%s', left_icon, p.name, owned_label)
            local left_text = make_text(left_str, name_x, cur_y + 8, left_color, 11, false)

            -- ===== RIGHT: materials list or MAXED =====
            local mat_texts = {}
            if not p.next_tier then
                local mt = make_text('MAXED (+4)', right_x, cur_y + 8, C_PIECE_MAX, 11, true)
                table.insert(mat_texts, mt)
            elseif p.mats and #p.mats > 0 then
                for i, mat in ipairs(p.mats) do
                    local have  = count_material(mat.name)
                    local ok    = have >= mat.count
                    local color = ok and C_MAT_HAVE or C_MAT_NEED
                    local check = ok and '✓' or '✗'
                    local where = bag_summary(mat.name)
                    local line  = string.format('%s %s  %d/%d  %s', check, mat.name, have, mat.count, where)
                    local mt = make_text(line, right_x, cur_y + (i - 1) * ROW_H, color, 10)
                    table.insert(mat_texts, mt)
                end
            else
                local mt = make_text('—', right_x, cur_y + 8, C_SUMMARY, 11, false)
                table.insert(mat_texts, mt)
            end

            table.insert(ui.rows, {
                bg = row_hl, icon = icon, header = left_text, mats = mat_texts,
                rect = { x = icon_x, y = cur_y, w = tb_w - PAD * 2, h = block_h },
                name = p.name,
            })
        end

        cur_y = cur_y + block_h
    end


    for _, e in pairs(ui.el) do show(e) end

    -- When the job-picker dropdown is open we DON'T render the piece rows
    -- — Windower's text primitives always draw on top of image primitives,
    -- so row text would visibly punch through the dropdown background.
    -- Instead we let the (opaque) body bg show through behind the dropdown,
    -- and restore the rows when the dropdown closes (next build).
    if not ui.dropdown_open then
        for _, r in ipairs(ui.rows) do
            if r.bg then show(r.bg) end       -- selection highlight (under everything)
            if r.icon then show(r.icon) end
            if r.header then show(r.header) end
            if r.mats then for _, mt in ipairs(r.mats) do show(mt) end end
        end
    end

    -- Render dropdown LAST so it sits on top of everything
    if ui.dropdown_open then build_dropdown() end
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
        -- Dropdown cell click first (it sits on top of everything)
        if ui.dropdown_open then
            for _, r in pairs(ui.dropdown_rect) do
                if in_rect(x, y, r) then
                    if r.job == 'AUTO' then
                        settings.job = nil
                        notify('Auto-detect job: ' .. active_job(), 158)
                    else
                        settings.job = r.job
                        notify('Job override: ' .. r.job, 158)
                    end
                    config.save(settings)
                    ui.dropdown_open = false
                    ui.scroll = 0
                    refresh_window()
                    return true
                end
            end
            -- Click outside dropdown closes it
            ui.dropdown_open = false
            build_window()
            return true
        end

        if in_rect(x, y, ui.rect.title_bar) then
            -- Tabs first
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
            -- Job tag → open dropdown
            if ui.rect.job_tag and in_rect(x, y, ui.rect.job_tag) then
                ui.dropdown_open = true
                build_window()
                return true
            end
            ui.drag = { dx = x - settings.pos.x, dy = y - settings.pos.y }
            return true
        end

        -- Footer buttons
        if ui.rect.btn_gather and in_rect(x, y, ui.rect.btn_gather) then
            if ui.rect.btn_gather.enabled then
                local sel = nil
                for _, p in ipairs(ui.cached_pieces or {}) do
                    if p.name == ui.selected_name then sel = p; break end
                end
                gather_for_piece(sel)
                -- After a moment refresh the window so material counts update
                coroutine.schedule(refresh_window, 1)
            else
                notify('Click a piece in the list first to select it.', 167)
            end
            return true
        end
        if ui.rect.btn_trade and in_rect(x, y, ui.rect.btn_trade) then
            if ui.rect.btn_trade.enabled then
                local sel = nil
                for _, p in ipairs(ui.cached_pieces or {}) do
                    if p.name == ui.selected_name then sel = p; break end
                end
                trade_for_piece(sel)
            else
                notify('Click a piece in the list first to select it.', 167)
            end
            return true
        end

        -- Click on a piece row to select it
        for _, r in ipairs(ui.rows) do
            if r.rect and in_rect(x, y, r.rect) then
                if ui.selected_name == r.name then
                    ui.selected_name = nil   -- click again = deselect
                else
                    ui.selected_name = r.name
                end
                build_window()   -- rebuild to update button enabled state + highlight
                return true
            end
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
    -- Initialize icon extraction (BMPs into libs/cache/<id>.bmp on demand).
    -- icon_handler reads the FFXI install path via windower.ffxi_path; if
    -- that's not set (rare), get_icon_path returns nil and we'll just
    -- skip the icon on those rows.
    icon_handler.init(windower.ffxi_path)
    icon_handler.set_ui_visible(true)

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
    if icon_handler and icon_handler.cleanup then icon_handler.cleanup() end
end)
