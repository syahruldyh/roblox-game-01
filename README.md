# NEON RUSH — Dash. Dodge. Survive.

A neon arcade dodger for Roblox (make.fun roblox-game-01). You are a
cyan orb in a neon arena. Magenta shards drift in from the edges —
dodge them, collect the amber stars, chain combos, and grab power-ups.
Three hits and the run is over.

## Controls

- **WASD / arrow keys** — move
- **Space** — dash (a burst of speed, brief invulnerability, 1.6s cooldown)
- **Enter / click** — start from the title screen
- **R** — play again from the game-over screen

## Rules

- A star is 10 points, times the combo multiplier (up to x8). Every 4
  clean collects steps the combo up; taking a hit resets it.
- A hazard that passes within 46 px without hitting you pays a
  **near miss** (+2, feeds the combo). Brave play pays more than hiding.
- Every 150 points is a level up: hazards spawn faster and move faster.
- Power-ups: **Shield** (the next hit costs nothing), **Slow-Mo**
  (hazards at half speed, 5s), **Magnet** (stars fly to you, 6s).
- 3 lives. Best score is kept on the server (leaderstats + DataStore
  when the service answers, memory when it does not).

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
