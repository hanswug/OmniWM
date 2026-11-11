# OmniWM (hanswug fork)

**We respect macOS and push it to its limits.** No tricks: if macOS doesn't offer something, we don't fake it.

This is a personal fork of **[OmniWM](https://github.com/OmniNull/OmniWM)**, the free, open-source tiling window manager for Apple Silicon Macs by [OmniNull](https://github.com/OmniNull) and its contributors.

**If you're looking for OmniWM, use upstream:** [website](https://omniwm.app) · [documentation](https://omniwm.app/guides/quick-start/) · [install](https://omniwm.app/guides/install/) · [repository](https://github.com/OmniNull/OmniWM). Upstream is signed, notarized and actively maintained. This fork isn't.

OmniWM's engine is a joy to use: it's instant, smooth at 120 and 144 Hz, and full of features that deserve more attention. This fork exists because I use it every day, and I keep a handful of small quality-of-life changes for the Niri layout that fit my workflow. Real fixes are offered back upstream. Everything else stays here, opt-in, with upstream's defaults left unchanged.

## What's different

Each change is a topic branch cut from upstream `main`, so it can be reviewed and proposed on its own. `hans/main` (the default branch here) is upstream `main` plus the topics below. Upstream changes are merged in regularly.

| Change | Kind | Upstream |
|---|---|---|
| [Fullscreen toggle raises the window](#fullscreen-toggle-raises-the-window) | fix | [PR #1109](https://github.com/OmniNull/OmniWM/pull/1109), in review |
| [Explicit resizes retest learned minimums](#explicit-resizes-retest-learned-minimums) | fix | not proposed yet |
| [Keyboard resizes stay inside the working area](#keyboard-resizes-stay-inside-the-working-area) | fix | fork only |
| [Columns end exactly on the outer gaps](#columns-end-exactly-on-the-outer-gaps) | fix | candidate, fails on clean upstream |
| [Shrink visible columns to fit](#shrink-visible-columns-to-fit) | setting | offered upstream in [#1110](https://github.com/OmniNull/OmniWM/issues/1110) as one opt-in setting, waiting for the maintainer |
| [Reset Layout](#reset-layout) | command, setting | fork only |
| [New window placement](#new-window-placement) | settings | fork only |
| [Focus clicked windows without scrolling](#focus-clicked-windows-without-scrolling) | setting | upstream [PR #1092](https://github.com/OmniNull/OmniWM/pull/1092) by ylorn, imported early |

New settings default to upstream's behaviour. Niri ones live in the `[niri]` table and in **Settings → Layouts → Niri**.

### Fullscreen toggle raises the window

`toggle-fullscreen` now focuses and raises the window it changes. Before, a window selected without being raised (for example after Niri keyboard navigation, or among several windows of one app such as Safari) could go fullscreen *behind* the tiles it now covers, and wasn't key until you clicked it.

### Explicit resizes retest learned minimums

OmniWM learns an app's minimum size when the app refuses to shrink, and then won't size it smaller. Some apps' real minimum later drops (Safari is one), but the learned value stayed, so the column was held wider than it needed to be. Now a resize you ask for (keyboard resizing, Reset Layout) retests the learned minimum instead of trusting it forever. If the app really can't go narrower, the column keeps the width the app kept, so growing it back works on the first press.

### Keyboard resizes stay inside the working area

Sizing commands (a fixed width, a proportion above 100%, repeated grow steps) are capped at a full-width column, the same bound mouse resizing already uses, so a column no longer runs past the screen into the outer gaps. A window's minimum size still wins.

### Columns end exactly on the outer gaps

Each column's width was rounded to whole pixels on its own, so two half-pixel columns both rounded up and the row ended a pixel into the right outer gap, or shifted a pixel when focus moved. Column edges are now rounded instead of widths: neighbours meet exactly, the last column ends on the gap, and widths stay fixed while the view scrolls.

### Shrink visible columns to fit

```toml
[niri]
shrinkToFit = true   # default false
```

Upstream intentionally leaves the other columns alone when you resize one ([#615](https://github.com/OmniNull/OmniWM/pull/615)), so the row can extend into the outer gaps until you scroll. With `shrinkToFit` on, the visible columns always fill the working area, each within its size limits: after a keyboard resize (set, adjust or cycle a column's span), and when windows open or close, a minimum size changes, the gaps change, or the visible container count changes. An app with a wide minimum (Apple Music) is honoured on its first frame. When even the minimums can't fit, whole columns move out of view instead of into the outer gaps. The columns keep their own widths underneath, and mouse resizing is unchanged. Reset Layout honours minimums on the first press either way.

### Reset Layout

A **Reset Layout** command (`omniwmctl command reset-layout`, bindable in Settings → Hotkeys) resets the active workspace to an even layout that fills the working area: equal columns in Niri, equal areas in Dwindle. Upstream's **Balance Sizes** is unchanged; it keeps its 1 / visible-containers slot widths on purpose.

```toml
[niri]
visibleContainerChangeAction = "reset"   # "balance" (default) or "reset"
```

Chooses what happens when you change the visible container count: upstream's Balance Sizes, or Reset Layout.

### New window placement

```toml
[niri]
newWindowPlacement = "right"           # "right" (default), "left", "first" or "last"
newWindowJoinsTabbedColumn = false     # default false
```

`newWindowPlacement` sets where a new window's column opens: right or left of the focused column, or at the start or end of the workspace. With `newWindowJoinsTabbedColumn`, if the column on that side (or the first or last column) is tabbed, the new window joins it as a tab instead of opening a new column.

### Focus clicked windows without scrolling

```toml
[focus]
clickFocusWithoutScrolling = true   # default false
```

A click on a partially visible Niri window focuses it without scrolling the row, so the next click lands where you aimed. Keyboard navigation, gestures, Cmd-Tab and the Dock still scroll windows into view. This is [upstream PR #1092](https://github.com/OmniNull/OmniWM/pull/1092) by ylorn, imported before upstream merges it (planned after 0.8.0); the fork drops its copy once it lands.

## Building

There are no releases of this fork. To try it, build it the way upstream documents in [CONTRIBUTING.md](CONTRIBUTING.md) (`make doctor`, `make setup`, then `make run`). `make run` installs a separate **OmniWM Dev** app in `~/Applications`, with its own settings in `~/.config/omniwm-dev/`, so your regular OmniWM install is left alone. Only one of the two runs at a time; `make use-release` switches back.

## Companion app: OmniWM Extension

[**OmniWM Extension**](https://github.com/hanswug/omniwm-extension) is a small native menu bar app that works with OmniWM (upstream or this fork) through its IPC socket:

- **Padding presets.** Cycle or pick outer-gap presets with a hotkey; on the built-in display alone it switches to the first preset, and restores yours when you dock again.
- **Visible containers 1–5** from hotkeys. With upstream OmniWM it runs Balance Sizes afterwards; with this fork, `visibleContainerChangeAction` decides.
- **Borders toggle.**
- **A live menu bar status** with the workspace, layout, visible-container dots and fullscreen state, plus a small HUD that confirms each command.

It needs no Accessibility or Input Monitoring permission. It's a separate app for now; whether parts of it move into this fork is still open.

## License and credit

GPL-2.0, like OmniWM. See [LICENSE](LICENSE). All credit for OmniWM goes to OmniNull and the [OmniWM contributors](https://github.com/OmniNull/OmniWM#contributors). This fork isn't affiliated with or endorsed by them; please report issues with these changes here, not upstream.
