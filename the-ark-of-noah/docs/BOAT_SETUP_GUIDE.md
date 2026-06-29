# Boat Construction Setup (Step-by-step)

## Included example nodes in world

- `BoatConstructionArea`
- `PitchSource`
- `CraftingBench`

All are already placed in `res://scenes/world/world.tscn`.

## Stage requirements used

- Stage 1: 3 logs + 2 pitch
- Stage 2: 8 logs + 3 pitch

## How to test in game

1. Get logs (tree/chop flow).
2. Ensure you have an empty bucket.
3. Interact near PitchSource to fill bucket(s).
4. Interact near BoatConstructionArea to deposit resources.
5. On completion, completed boat scene is spawned.

## Change stage requirements

Edit these resources:

- `res://resources/construction/boat_stage_1.tres`
- `res://resources/construction/boat_stage_2.tres`

## Replace visuals

Set in inspector for `ConstructionAreaComponent`:

- `blueprint_sprite`
- `stages[].stage_scene`
- `completed_scene`
