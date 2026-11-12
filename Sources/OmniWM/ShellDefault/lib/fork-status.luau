-- SPDX-License-Identifier: GPL-2.0-only
-- Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

local look = require("./look")

local status = { width = 240 }

function status.get(ctx: Context): BarStatus?
    local bar = ctx.data.bar
    return bar and bar.status
end

function status.empty()
    return ui.box{ w = 0, h = 0 }
end

function status.button(ctx: Context, props)
    local style = ctx.data.bar.style
    local button = { onClick = props.onClick or ui.popout, onRightClick = ui.popout, help = props.help }
    if props.symbol then
        button[#button + 1] = look.barGlyph(ctx, { name = props.symbol })
    end
    if props.text and not style.vertical then
        button[#button + 1] = look.text{ text = props.text, size = look.px(ctx, "text"), weight = "medium",
            maxWidth = 120 * look.scale(ctx) }
    end
    return look.bar(ctx, button)
end

function status.picker(ctx: Context, title: string, entries)
    local width = status.width
    local rows = { gap = 3 }
    for _, entry in entries do
        rows[#rows + 1] = ui.row{ w = width - 24, gap = 10, pad = 5, radius = look.radius(7), hover = look.hover,
            onClick = entry.command,
            look.glyph{ name = entry.symbol, size = 14, w = 20, h = 18,
                color = if entry.selected then "accent" else "secondaryForeground" },
            look.text{ text = entry.text, size = 13, grow = 1, maxWidth = width - 96,
                weight = if entry.selected then "medium" else nil },
            look.glyph{ name = "checkmark", w = 12, h = 12, color = "accent", opacity = if entry.selected then 1 else 0 } }
    end
    return look.panel(ctx, { w = width + 28,
        ui.column{ w = width, gap = 12, center = false, look.heading(title, width), look.group(rows) } })
end

return table.freeze(status)
