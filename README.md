# NEON RUSH — Dash. Dodge. Survive.

A neon arcade dodger for Roblox (make.fun roblox-game-01). You are a
cyan orb in a neon arena. Magenta shards drift in from the edges —
dodge them, collect the amber stars to charge the portal, and clear
all 3 zones to win. Three hits and the run is over.

## Controls

- **WASD / arrow keys** — move
- **Space** — dash (a burst of speed, brief invulnerability, 1.6s cooldown)
- **Enter / click** — start from the title screen
- **R** — play again from the game-over screen
- **Touch** — drag the on-screen stick to move, tap DASH

## Rules

- A star is 10 points, times the combo multiplier (up to x8). Every 4
  clean collects steps the combo up; taking a hit resets it.
- **Zones:** each zone asks for a number of stars (8 / 10 / 12).
  Collect them all and the portal opens: +50 × zone bonus, hazards
  cleared, next zone faster with a new accent. Clear zone 3 to win.
- A hazard that passes within 46 px without hitting you pays a
  **near miss** (+2, feeds the combo). Brave play pays more than hiding.
- Every 150 points is a level up: hazards spawn faster and move faster.
- Power-ups: **Shield** (the next hit costs nothing), **Slow-Mo**
  (hazards at half speed, 5s), **Magnet** (stars fly to you, 6s).
- 3 lives. Best score is kept on the server (leaderstats + DataStore
  when the service answers, memory when it does not).

## Roblox UI rule learned the hard way

A GuiObject renders in front of another only when its ZIndex is
higher — a child with the default ZIndex 1 renders BEHIND a parent
panel whose ZIndex was raised (10, 20), so its text is invisible.
Every label in this game passes its parent's ZIndex + 1 (HUD 11,
title/game-over 21, zone 6, popups/particles 8). The title screen
itself is a 75%-opaque overlay, so anything under it (zone label,
arena) reads dimmed until the game starts.

## Hazards

- **Drifter** (square) — straight across, the baseline threat.
- **Weaver** (diamond) — sine wave, it covers a lane, not a line.
- **Chaser** (circle) — slow, turns toward you, burns out after 4.5s.

## Systems map

- `src/shared/Config.luau` — the palette, tuning, hazard/power-up defs.
- `src/server/State.luau` — the server's record: best scores,
  leaderstats, DataStore with pcall fallback.
- `src/server/init.server.luau` — wires the remotes, builds leaderstats.
- `src/client/Game.client.luau` — the arcade loop: movement, dash,
  spawning, collisions, combo, levels, game over.
- `src/client/UI.luau` — title, HUD, banner, game-over screen.
- `src/client/Effects.luau` — particles, screen shake, hit flash,
  floating score popups, combo pulse.
- `src/client/Input.luau` — keyboard state + action bindings.
- `src/client/Sound.luau` — guarded sound playback (silent until the
  owner drops real asset ids into Config.Sounds).

## Build

```sh
rojo build default.project.json --output game.rbxl
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

`main.ts` copies game.rbxl, src/, screenshots/ and PLAY.json to
/output and writes dossier.json with the vendored make.fun library.
