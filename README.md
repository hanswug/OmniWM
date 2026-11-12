# OmniWM (hanswug fork)

**We respect macOS and push it to its limits.** No tricks: if macOS doesn't offer something, we don't fake it.

This is a personal fork of **[OmniWM](https://github.com/OmniNull/OmniWM)**, the free, open-source tiling window manager for Apple Silicon Macs by [OmniNull](https://github.com/OmniNull) and its contributors.

**If you're looking for OmniWM, use upstream:** [website](https://omniwm.app) · [documentation](https://omniwm.app/guides/quick-start/) · [install](https://omniwm.app/guides/install/) · [repository](https://github.com/OmniNull/OmniWM). Upstream is signed, notarized and actively maintained. This fork's releases are self-signed and not notarized.

OmniWM's engine is a joy to use: it's instant, smooth at 120 and 144 Hz, and full of features that deserve more attention. This fork exists because I use it every day, and I keep a handful of small quality-of-life changes for the Niri layout that fit my workflow. Real fixes are offered back upstream. Everything else stays here, opt-in, with upstream's defaults left unchanged.

## What's different

Each change is a topic branch cut from upstream `main`, so it can be reviewed and proposed on its own. `hans/main` (the default branch here) is upstream `main` plus the topics below. Upstream changes are merged in regularly.

| Change | Kind | Upstream |
|---|---|---|
| [Explicit resizes retest learned minimums](#explicit-resizes-retest-learned-minimums) | fix | not proposed yet |
| [Keyboard resizes stay inside the working area](#keyboard-resizes-stay-inside-the-working-area) | fix | fork only |
| [Columns end exactly on the outer gaps](#columns-end-exactly-on-the-outer-gaps) | fix | candidate, both parts fail on clean upstream |
| [Shrink visible columns to fit](#shrink-visible-columns-to-fit) | setting | agreed in [#1110](https://github.com/OmniNull/OmniWM/issues/1110) as one opt-in setting in two PRs; first PR not opened yet |
| [Reset Layout](#reset-layout) | command, setting | fork only |
| [New window placement](#new-window-placement) | settings, commands | fork only |
| [Padding presets](#padding-presets) | setting, commands | fork only |
| [Command feedback](#command-feedback) | setting | fork only |
| [Status widgets](#status-widgets) | menu bar widgets | fork only |
| [IPC hooks](#ipc-hooks) | commands, event | fork only |

Merged upstream: [Fullscreen toggle raises the window](https://github.com/OmniNull/OmniWM/pull/1109), in upstream since 2026-11-08.

New settings default to upstream's behaviour. Niri ones live in the `[niri]` table and in **Settings → Layouts → Niri**.

### Explicit resizes retest learned minimums

OmniWM learns an app's minimum size when the app refuses to shrink, and then won't size it smaller. Some apps' real minimum later drops (Safari is one), but the learned value stayed, so the column was held wider than it needed to be. Now a resize you ask for (keyboard resizing, Reset Layout) retests the learned minimum instead of trusting it forever. If the app really can't go narrower, the column keeps the width the app kept, so growing it back works on the first press.

A minimum the app has just refused is trusted on the next shrink step for that window, so pressing shrink against it changes nothing instead of making the window and its neighbours jump on every press. Growing, setting or cycling the span, Reset Layout and a visible container change retest it again.

### Keyboard resizes stay inside the working area

Sizing commands (a fixed width, a proportion above 100%, repeated grow steps) are capped at a full-width column, the same bound mouse resizing already uses, so a column no longer runs past the screen into the outer gaps. A window's minimum size still wins.

### Columns end exactly on the outer gaps

Each column's width was rounded to whole pixels on its own, so two half-pixel columns both rounded up and the row ended a pixel into the right outer gap, or shifted a pixel when focus moved. Column edges are now rounded instead of widths: neighbours meet exactly, the last column ends on the gap, and widths stay fixed while the view scrolls.

The view is placed on whole pixels too. When the first column in view started at a fractional position (the second of two 1275.5 pt columns, say), the whole row sat a pixel into an outer gap, 641 to 3201 instead of 640 to 3200. Upstream has both problems.

### Shrink visible columns to fit

```toml
[niri]
shrinkToFit = true   # default false
```

Upstream intentionally leaves the other columns alone when you resize one ([#615](https://github.com/OmniNull/OmniWM/pull/615)), so the row can extend into the outer gaps until you scroll. With `shrinkToFit` on, the visible columns fill the working area and nothing sits in the outer gaps:

- **Keyboard resizes** (set, adjust or cycle a span) fit the other columns of the visible group, as many as the visible container count, each within its size limits.
- **Size events** fit the row again: a window opening or closing, an app refusing a size, a gap or visible container change. An app with a wide minimum (Apple Music) is honoured on its first frame.
- **Moving focus never resizes.** Widths fitted for one pair can leave the next pair short or too wide; a column that would only partly show moves out of view instead of into the outer gaps. The strip it leaves stays empty until Reset Layout or a visible container change.
- The row sits flush on the gaps, a full-span column fills the row on its own and gets its neighbours back unchanged, and when even the minimums can't fit, whole columns move out of view.

The columns keep their own widths underneath, and mouse resizing is unchanged. Reset Layout honours minimums on the first press either way. With the setting off, everything behaves as upstream.

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
newWindowPlacement = "right"   # "right" (default), "left", "first" or "last"
newWindowJoin = "newColumn"    # "newColumn" (default), "tabbed" or "stacked"
```

`newWindowPlacement` sets where a new window goes: next to the focused column on the right or left, or at the start or end of the workspace.

`newWindowJoin` sets how it arrives there:

- **New column** (default): it opens its own column, as upstream.
- **Tabbed**: it joins that column as a tab, and the column becomes tabbed if it isn't.
- **Stacked**: it joins that column below its other windows, and a tabbed column becomes stacked.

The mode only changes a column when a window joins it; switching modes changes nothing on its own.

With Right or Left and no column on that side, it joins the focused column. While Tabbed or Stacked is on, every new window joins, so switch back to New column when you want columns again. Windows restored with their own size and the first window of a workspace always get their own column.

Switch it from the command palette or a hotkey: **New Windows: New Column / Tabbed / Stacked**, or **Cycle New Window Join Mode** (`omniwmctl command new-window-join-tabbed`, `cycle-new-window-join`, …). The older `newWindowJoinsTabbedColumn = true` is read as `"tabbed"`. Placement works the same way: **Cycle New Window Placement** (`cycle-new-window-placement`), or `new-window-placement-right|left|first|last`.

### Padding presets

```toml
[[gaps.presets]]
name = "Wide Tall"
top = 540
bottom = 8
left = 8
right = 8
```

Named sets of outer gaps, in cycle order. **Cycle Padding Preset** (`omniwmctl command cycle-padding-preset`) applies the next one. The active preset isn't stored: it's whichever preset matches the current outer gaps, so editing the gaps by hand simply leaves you on a custom padding. For a display that should always use different gaps (a laptop's built-in screen, say), use the per-display gap override in **Settings → Gaps**.

### Command feedback

```toml
[general]
commandFeedback = true   # default false
```

A short HUD in the middle of the screen for commands whose result you can't otherwise see: Visible Containers, padding preset, fullscreen and full container on/off, new-window placement and join mode, borders on/off, and a resize that did nothing because the app's minimum or maximum size stopped it ("Safari: minimum 574"). Toggle it in **Settings → General → Feedback**.

### Status widgets

Five OmniShell widgets for the menu bar, bundled with the default widgets. Add them to a lane in `~/.config/omniwm/shell/shell.toml`:

| Widget | Shows |
|---|---|
| `layout-vc` | the layout, and Visible Containers in Niri ("VC 3") |
| `window-state` | whether the focused window is normal, fullscreen or full container |
| `new-window-placement` | where new windows go |
| `new-window-join` | how new windows join |
| `padding` | the active padding preset, or Custom |

Click a widget to move to the next value; right-click it to pick one. Widget scripts can read the same state as `ctx.data.bar.status`.

### IPC hooks

Commands that change settings live, so a client doesn't have to edit `settings.toml`, all bindable as hotkeys:

```sh
omniwmctl command set-visible-containers <1-5>
omniwmctl command set-outer-gaps <left> <right> <top> <bottom>
omniwmctl command toggle-borders
```

The `focus` event is also published when the focused window's fullscreen or full-span state changes, so a client needs no polling.

## Install

Download `OmniWM-<version>.zip` from [Releases](https://github.com/hanswug/OmniWM/releases), unzip it and move **OmniWM.app** to `/Applications` or `~/Applications`.

- **It replaces upstream's OmniWM.** It uses the same settings file, `~/.config/omniwm/settings.toml`, and the same IPC socket, so quit or uninstall upstream first (`brew uninstall --cask omniwm` if you installed it with Homebrew). Only one OmniWM can run at a time.
- **It's self-signed**, not notarized. On first launch macOS refuses to open it; right-click OmniWM.app, choose **Open**, and confirm. Then grant **Accessibility** (and Input Monitoring if you use hotkeys that need it) in System Settings → Privacy & Security.
- **It has its own bundle ID** (`com.hanswug.OmniWM`), so macOS asks for those permissions again even if you granted them to upstream.
- **Updates:** with update checks on, OmniWM tells you when a new fork release is out and links to it. It can't install it itself, because the in-app installer needs a notarized build.

Versions follow upstream's with a fork build number: `0.8.0.1` is the first fork release on upstream 0.8.0.

### Sample settings

[`examples/settings.toml`](examples/settings.toml) is my full working configuration, exactly as I run it: Niri with shrink-to-fit, Reset Layout on visible container changes, and the fork's new-window placement. Copy it to `~/.config/omniwm/settings.toml` (back up yours first) and adjust; the app rules name the apps I use.

[`examples/shell/`](examples/shell) is my menu bar: an OmniShell `shell.toml` with the Apple menu, app menu, OmniWM and compact workspaces on the left, scratchpads in the centre, and the five [status widgets](#status-widgets) and system stats on the right. Copy it to `~/.config/omniwm/shell/`; OmniWM fills in its default widgets there on launch.

## Building

Build it the way upstream documents in [CONTRIBUTING.md](CONTRIBUTING.md): `make doctor`, `make setup`, then `make run`. `make run` builds the fork as **OmniWM** (`com.hanswug.OmniWM`), installs it in `~/Applications` and starts it. `make fork-release` builds the self-signed release zip in `dist/`.

## Companion app: retired

OmniWM Extension, my companion menu bar app, used to add padding presets, Visible Containers and borders hotkeys, a menu bar status and a command HUD. All of it is built into this fork now: [padding presets](#padding-presets), the catalog's hotkeys (**Set Visible Containers 1–5**, **Toggle Borders**, **Cycle Padding Preset**), the [status widgets](#status-widgets) and [command feedback](#command-feedback). Quit the companion before you bind the same keys in OmniWM.

## License and credit

GPL-2.0, like OmniWM. See [LICENSE](LICENSE). All credit for OmniWM goes to OmniNull and the [OmniWM contributors](https://github.com/OmniNull/OmniWM#contributors). This fork isn't affiliated with or endorsed by them; please report issues with these changes here, not upstream.
