-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local status = require("../lib/fork-status")

local PLACEMENTS = table.freeze({
    { id = "right", symbol = "inset.filled.righthalf.arrow.right.rectangle", text = "Right" },
    { id = "left", symbol = "inset.filled.lefthalf.arrow.left.rectangle", text = "Left" },
    { id = "first", symbol = "arrowtriangle.backward.leadingside.rectangle", text = "First" },
    { id = "last", symbol = "arrowtriangle.forward.trailingside.rectangle", text = "Last" },
})

function render(ctx: Context)
    local s = status.get(ctx)
    if not s then
        return status.empty()
    end
    local current = PLACEMENTS[1]
    for _, placement in PLACEMENTS do
        if placement.id == s.newWindowPlacement then
            current = placement
        end
    end
    return status.button(ctx, { symbol = current.symbol, onClick = "cycle-new-window-placement",
        help = "New windows: " .. current.text })
end

function popout(ctx: Context)
    local s = status.get(ctx)
    if not s then
        return status.empty()
    end
    local entries = {}
    for _, placement in PLACEMENTS do
        entries[#entries + 1] = { symbol = placement.symbol, text = placement.text,
            selected = placement.id == s.newWindowPlacement, command = "new-window-placement-" .. placement.id }
    end
    return status.picker(ctx, "New Window Placement", entries)
end
