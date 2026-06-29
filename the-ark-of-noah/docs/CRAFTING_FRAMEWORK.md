# Crafting Framework (Data-driven)

## Files

- Component: `res://components/crafting/crafting_bench_component.gd`
- Recipe class: `res://resources/crafting/crafting_recipe_resource.gd`
- Ingredient class: `res://resources/crafting/crafting_ingredient_resource.gd`
- Example bench: `res://scenes/construction/crafting_bench.tscn`
- Example recipe: `res://resources/crafting/recipe_bucket.tres`

## Concept

Crafting is driven by data resources, not hardcoded recipes.

## Recipe data

A recipe has:

- `recipe_id`
- `recipe_name`
- `ingredients` (resource array)
- `outputs` (resource array)

An ingredient/output resource has:

- `item_id`
- `count`

## Runtime flow

- Player presses interact near crafting bench.
- Bench checks recipes for first craftable one.
- Inputs are removed from InventoryComponent.
- Outputs are added as ItemStacks.

## Add new recipe

1. Create ingredient resources for inputs and outputs.
2. Create recipe `.tres` referencing those ingredients.
3. Assign recipe to a bench's `recipes` array.

## Suggested future expansion

- UI recipe list selector
- Craft queue / craft time
- Tool-category outputs using icons/resources map
