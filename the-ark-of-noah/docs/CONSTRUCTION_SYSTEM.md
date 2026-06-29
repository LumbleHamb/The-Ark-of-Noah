# Construction System (Reusable)

## Files

- Component: `res://components/construction/construction_area_component.gd`
- Stage resource class: `res://resources/construction/construction_stage_resource.gd`
- Requirement resource class: `res://resources/construction/construction_requirement_resource.gd`

## What it does

A construction area accepts resources in stages and progresses to completion.

## Inspector properties (ConstructionAreaComponent)

- `construction_name` (String)
- `stages` (Array of `ConstructionStageResource`)
- `current_stage` (int)
- `blueprint_sprite` (Texture2D)
- `completed_scene` (PackedScene)
- `interact_radius` (float)
- `accepted_resource_types` (Array[String])
- `auto_spawn_stage_scene` (bool)

## Stage setup

Each `ConstructionStageResource` has:

- `stage_name`
- `requirements` (Array of requirement resources)
- `stage_scene` (visual scene shown for this stage)

Each requirement resource has:

- `item_id` (example: `log`, `pitch`)
- `amount`

## Boat example included

- Scene: `res://scenes/construction/boat_construction_area.tscn`
- Stage data:
  - `res://resources/construction/boat_stage_1.tres` (3 log + 2 pitch)
  - `res://resources/construction/boat_stage_2.tres` (8 log + 3 pitch)
- Completion scene: `res://scenes/construction/completed_boat.tscn`

## How player deposits

Player interaction (`E`) deposits matching inventory resources if standing in the area.
Special handling converts `bucket_pitch` into `pitch` delivery and returns empty buckets.

## Add a new construction project

1. Create requirement `.tres` resources.
2. Create stage `.tres` resources.
3. Create a Node2D scene with `ConstructionAreaComponent` child.
4. Fill component exports in Inspector.
5. Place scene in world.
