-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local status = require("../lib/fork-status")

local NIRI = "rectangle.split.3x1"
local DWINDLE = "rectangle.split.2x2"
local MAX_VISIBLE = 5

function render(ctx: Context)
    local s = status.get(ctx)
    if not s then
        return status.empty()
    end
    if s.layout == "dwindle" then
        return status.button(ctx, { symbol = DWINDLE, help = "Dwindle (BSP)" })
    end
    local next = s.visibleContainers % MAX_VISIBLE + 1
    return status.button(ctx, { symbol = NIRI, text = "VC " .. s.visibleContainers,
        onClick = "set-visible-containers " .. next, help = "Niri (Scrolling): Visible Containers" })
end

function popout(ctx: Context)
    local s = status.get(ctx)
    if not s then
        return status.empty()
    end
    local entries = {}
    if s.layout == "niri" then
        for count = 1, MAX_VISIBLE do
            entries[#entries + 1] = { symbol = NIRI, text = "VC " .. count, selected = s.visibleContainers == count,
                command = "set-visible-containers " .. count }
        end
    end
    entries[#entries + 1] = { symbol = if s.layout == "niri" then DWINDLE else NIRI,
        text = if s.layout == "niri" then "Switch to Dwindle" else "Switch to Niri", selected = false,
        command = "toggle-workspace-layout" }
    return status.picker(ctx, "Layout", entries)
end
