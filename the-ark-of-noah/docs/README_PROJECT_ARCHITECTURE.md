# The Ark of Noah — Project Architecture Guide (Beginner Friendly)

This project uses a **component-based architecture**.

## 1) How the architecture works

- Main gameplay entities (Player, Logs, Chests, Construction Areas) are scene nodes.
- Behavior is split into reusable **Component** scripts under `res://components/`.
- Components inherit from `Component` (`res://components/core/component.gd`).
- Instead of giant scripts, each component owns one responsibility.

## 2) Main folders (current)

- `res://components/` → reusable gameplay behaviors (movement, rope, inventory, chest, construction, crafting, bucket)
- `res://scenes/` → scene composition (world, player, trees, decor, construction examples)
- `res://scripts/` → legacy/manager scripts and gameplay controllers
- `res://resources/` → data resources (`.tres`) and resource script classes
- `res://docs/` → documentation

## 3) Reuse rules used by this project

- Prefer adding a component to an entity over adding one-off logic.
- Keep data in resources (`.tres`) where practical.
- Use scene composition to create examples (boat area, pitch source, crafting bench).

## 4) New systems added in this pass

- Construction area component
- Bucket component (inventory-first flow)
- Resource collector component (pitch source)
- Crafting bench component + data-driven recipes

Read dedicated docs in this folder for setup and extension steps.
