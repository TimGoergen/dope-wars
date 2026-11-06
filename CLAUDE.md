# Dope Wars: Omaha Metro Edition — Project Instructions

Dope Wars: Omaha Metro Edition is a Godot 4.5.1 / GDScript mobile trading & strategy game optimized for the Google Pixel 10 Pro XL (`1080 × 2400` portrait). The Godot project lives in the `game/` subfolder (`game/project.godot`, main scene `game/Main.tscn`). The repo root holds `docs/` (design canon) and `tools/` (verification gate runner).

## Before any work
Consult `/docs/GDD_v1.1.md` (canonical design document) before modifying mechanics, UI layout, or balance constants.
- **Verification:** `pwsh tools\run_gates.ps1` runs all 8 headless verification gates + a 150-frame headless boot check.

## Hard rules
- **No tuning constants in code.** Costs, rates, multipliers, drug prices, affinities, cop stats, etc. load from `game/config/tuning.tres` (`TuningConfig.gd`) with runtime developer overrides layered from `user://tuning_overrides.json` via `TuningOverrides.gd`.
- **GDScript only.** Prioritize human readability — clear names, brief comments on non-obvious choices.
- **Atomic Git Execution.** Always execute `git` commands as single, unchained commands (`git status`, `git add -A`, `git commit -m "..."`, `git push origin main`). Never chain multiple commands with `;` or `&&`.

## Code map (`game/`)
- `scripts/core/` — headless game state + rules (NO scene tree).
  - `Money.gd` — currency and P/L string formatting.
  - `OmahaCatalog.gd` — static definitions for the 8 Omaha neighborhoods, 12 products, 5 weapons, 2 armors, 5 vehicle tiers, and 6 Legacy Perks.
  - `MarketEngine.gd` — daily availability rolls, neighborhood price affinities, `×4`/`÷4` market events, and VIP Intel guarantees.
  - `CombatEngine.gd` — Heat calculation, 3 cop tiers (OPD Hardass, Sheriff Bob, DEA Miller), Shared 50/50 Crew combat target pool (`30 HP` per encounter), and Crew death overflow.
  - `GameState.gd` — full turn loop, trading (`Avg Paid`), Street ATM, all 8 neighborhood facilities, and Day 31 settlement.
  - `SaveManager.gd` — mid-run auto-save, Street Cred, unlocked/active Legacy Perks, and Hall of Fame.
  - `ConfigLoader.gd` & `TuningOverrides.gd` — loads `res://config/tuning.tres` + `user://tuning_overrides.json`.
- `scripts/ui/` — Dark OLED "Omaha Street Noir" UI components (`UiPalette.gd`, `TradeOverlay.gd`, `FacilityOverlay.gd`, `CombatOverlay.gd`, `EncounterOverlay.gd`, `LegacyOverlay.gd`, `RunSummaryOverlay.gd`, `DevTuningOverlay.gd`).
- `scripts/Main.gd` — root `1080 × 2400` zero-scroll portrait dashboard and Unified 12-Row Trading Board.
- `scripts/audio/` — `Audio.gd` autoload (with procedural PCM WAV synthesis + file overrides) and `Haptics.gd`.
- `sim/` — 8 headless verification gates (`SceneTree` scripts).

## Build / verify (headless)
Godot 4.5.1 is invoked by absolute path:
`D:\Downloads\Godot_v4.5.1-stable_win64\Godot_v4.5.1-stable_win64_console.exe`
- Run all gates + boot check: `pwsh tools\run_gates.ps1`
- Refresh class cache after adding a new `class_name`:
  `D:\Downloads\Godot_v4.5.1-stable_win64\Godot_v4.5.1-stable_win64_console.exe --headless --editor --quit --path game`
