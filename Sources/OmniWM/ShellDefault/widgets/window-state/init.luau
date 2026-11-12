-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

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
    return status.button(ctx, { symbol = symbol, onClick = "toggle-fullscreen",
        help = if window and window.app ~= "" then window.app .. ": " .. name else name })
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
