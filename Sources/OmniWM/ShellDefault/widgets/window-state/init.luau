-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("../lib/look")
local status = require("../lib/fork-status")

local FULLSCREEN = "arrow.up.left.and.arrow.down.right"
local FULL_CONTAINER = "arrow.left.and.right"
local NORMAL = "arrow.down.right.and.arrow.up.left"

local function state(s: BarStatus)
    local window = s.focusedWindow
    if window and window.fullscreen then
        return FULLSCREEN, "Fullscreen"
    elseif window and window.fullSpan then
        return FULL_CONTAINER, "Full Container"
    end
    return NORMAL, "Normal"
end

function render(ctx: Context)
    local s = status.get(ctx)
    if not s then
        return status.empty()
    end
    local symbol, name = state(s)
    local window = s.focusedWindow
    local content
    if window then
        local size = look.px(ctx, "icon")
        local badge = math.round(size * 0.8)
        content = ui.stack{ w = size + badge * 0.5, h = size,
            ui.icon{ pid = window.pid, w = size, h = size, placeholder = "app.dashed", align = "leading" },
            ui.stack{ align = "bottomTrailing", dy = 3 * look.scale(ctx), w = badge, h = badge, radius = badge / 2,
                fill = "background", border = "border", borderWidth = 0.5,
                ui.symbol{ name = symbol, size = badge * 0.68, weight = "heavy", color = "foreground" } } }
    end
    return status.button(ctx, { content = content, symbol = if window then nil else symbol,
        onClick = "toggle-fullscreen", help = if window then window.app .. ": " .. name else name })
end

function popout(ctx: Context)
    local s = status.get(ctx)
    if not s then
        return status.empty()
    end
    local window = s.focusedWindow
    return status.picker(ctx, if window then window.app else "Window", {
        { symbol = FULLSCREEN, text = "Fullscreen", selected = window ~= nil and window.fullscreen,
            command = "toggle-fullscreen" },
        { symbol = FULL_CONTAINER, text = "Full Container", selected = window ~= nil and window.fullSpan,
            command = "toggle-container-full-primary-span" },
    })
end
