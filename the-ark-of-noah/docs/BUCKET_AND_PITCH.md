# Bucket + Pitch System (Inventory-first)

## Files

- Bucket component: `res://components/bucket/bucket_component.gd`
- Resource collector component: `res://components/resources/resource_collector_component.gd`
- Pitch source example scene: `res://scenes/construction/pitch_source.tscn`

## Behavior

- Player has `BucketComponent` attached.
- Starter empty bucket is granted if player has none.
- Pitch source consumes `bucket_empty` and produces `bucket_pitch`.
- Construction deposit consumes `bucket_pitch`, deposits `pitch`, and gives back `bucket_empty`.

## Item IDs used

- `bucket_empty`
- `bucket_pitch`
- `pitch` (virtual delivered resource for construction requirement)

## Extend

You can create more collector nodes (water, oil, resin) by changing:

- `source_resource_id`
- `required_container_item_id`
- `produced_item_id`
- `produce_amount`
