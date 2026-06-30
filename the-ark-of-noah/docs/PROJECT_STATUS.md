# PROJECT STATUS

## Completed
- Gameplay feel pass (high-impact) for active loops:
  - Breakable rock hit/break feedback now includes impact flash, debris particles, camera shake, and audio cue hooks.
  - Harvest pickup feedback now includes pickup particles, floating pickup text, and pickup audio cue hooks.
  - Player movement now emits lightweight footstep particles and terrain-tagged footstep audio hooks (`grass/sand/water`).
- Weather polish integration:
  - Added weather-driven leaf-particle activation using existing leaves particle groups.
  - Added lightweight fog overlay response to rain/thunder states.
  - Fixed `set_weather_intensity()` to scale from base chance values (avoids compounding drift).
  - Added `get_weather_intensity()` for save/load integration.
- Save/load scope improved:
  - Weather intensity persisted/restored.
  - Inventory save/load now persists tool and seed resources in addition to stack items.
- Animated world polish:
  - Village house scene now exposes editable animation speed exports for house and smoke.
- Blacksmith polish:
  - Added purchase success/fail status pulse feedback and audio cue hooks in shop UI.

## Improved
- Reused existing systems only (AttackComponent, HarvestPickup, game_stats, WeatherManager, leaves particle scene, InventoryComponent, SaveManager, Blacksmith UI).
- Kept changes editor-facing and configurable via exports where feasible.
- Added non-destructive polish hooks instead of replacing core architecture.

## Remaining
- Full biome hand-paint and transition artistry pass across entire map still pending.
- Full water/waterfall/shoreline animated tile authoring audit still pending (current pass audited state and structure, not full repaint).
- Weather ambient audio loop authoring/mixing remains placeholder-hook level.
- Tool progression/upgrade resources and blacksmith upgrade economy balancing still need deeper content pass.
- Full vertical-slice QA matrix (all loops + all map zones + full save/load scenario grid) remains incomplete.

## Known Issues
- Vision screenshot/playtest analysis tool hit weekly spending limit during this iteration; visual runtime confirmation is partially blocked in-tool.
- Existing unrelated project issue remains: missing `res://video.mp4` referenced by intro cutscene placeholder.
- Very large map layers (Beach/Water) limit practical automated in-chat terrain artistry verification.

## Future Work
- Add dedicated reusable VFX resource profiles (mining, harvest, pickup, footsteps) for centralized tuning.
- Expand weather polish with explicit ambient loops (rain/wind/storm) and bus routing.
- Add deterministic terrain QA scene for transition tiles and animated shoreline/waterfall previews.
- Extend progression with explicit upgrade resources consumed by blacksmith loop and persisted in saves.
