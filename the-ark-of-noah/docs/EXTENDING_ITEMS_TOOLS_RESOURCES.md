# How to add new resources, items, and tools

## Add a new item ID

This project uses string IDs in ItemStack (`item_id`).
Examples: `log`, `bucket_empty`, `bucket_pitch`, `pitch`.

## Add a new tool

1. Create a new `ToolData` `.tres` in `res://resources/tools/`.
2. Assign icon and swing sprites.
3. Add to player inventory startup or crafting outputs.

## Add a new collectable resource source

1. Create a scene with a `ResourceCollectorComponent` child.
2. Configure required container and produced item IDs.
3. Place source scene in world.

## Add a new construction material

1. Use new item ID in inventory production/drop flow.
2. Add requirement resource with same ID.
3. Add to construction stage requirements.

## Add a new crafting output item

1. Add ingredient/output resources.
2. Add recipe resource.
3. Assign recipe to a crafting bench.
