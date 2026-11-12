-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local status = require("../lib/fork-status")

local MODES = table.freeze({
    { id = "newColumn", command = "new-column", symbol = "rectangle.split.2x1", text = "New Column" },
    { id = "tabbed", command = "tabbed", symbol = "rectangle.topthird.inset.filled", text = "Tabbed" },
    { id = "stacked", command = "stacked", symbol = "rectangle.split.1x2", text = "Stacked" },
})

function render(ctx: Context)
    local s = status.get(ctx)
    if not s then
        return status.empty()
    end
    local current = MODES[1]
    for _, mode in MODES do
        if mode.id == s.newWindowJoin then
            current = mode
        end
    end
    return status.button(ctx, { symbol = current.symbol, onClick = "cycle-new-window-join",
        help = "New windows: " .. current.text })
end

function popout(ctx: Context)
    local s = status.get(ctx)
    if not s then
        return status.empty()
    end
    local entries = {}
    for _, mode in MODES do
        entries[#entries + 1] = { symbol = mode.symbol, text = mode.text, selected = mode.id == s.newWindowJoin,
            command = "new-window-join-" .. mode.command }
    end
    return status.picker(ctx, "How New Windows Join", entries)
end
