-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local status = require("../lib/fork-status")

local SYMBOL = "square.arrowtriangle.4.outward"

function render(ctx: Context)
    local s = status.get(ctx)
    if not s or #s.paddingPresets == 0 then
        return status.empty()
    end
    local name = s.paddingPreset or "Custom"
    return status.button(ctx, { symbol = SYMBOL, text = name, onClick = "cycle-padding-preset",
        help = "Padding: " .. name })
end

function popout(ctx: Context)
    local s = status.get(ctx)
    if not s then
        return status.empty()
    end
    local entries = {}
    for _, preset in s.paddingPresets do
        entries[#entries + 1] = { symbol = SYMBOL, text = preset.name, selected = preset.active,
            command = string.format("set-outer-gaps %g %g %g %g", preset.left, preset.right, preset.top, preset.bottom) }
    end
    return status.picker(ctx, "Padding", entries)
end
