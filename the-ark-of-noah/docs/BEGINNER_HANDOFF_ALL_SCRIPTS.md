# Beginner Script Handoff (Auto-Generated)

This reference lists every .gd script, its class/extends, exported vars, signals, and function signatures.
Generated automatically from the current project for onboarding and maintenance.

## res://components/animation/animal_animation_component.gd
- Class: `AnimalAnimationComponent`
- Extends: `Component`
- Exported properties:
  - `@export var animated_sprite: AnimatedSprite2D = null`
  - `@export var flip_facing: bool = true`
- Signals: none
- Functions:
  - `func _component_ready() -> void:`
  - `func get_sprite() -> AnimatedSprite2D:`
  - `func play(anim_name: String) -> void:`
  - `func play_unique(anim_name: String) -> void:`
  - `func stop() -> void:`
  - `func current() -> String:`
  - `func is_playing() -> bool:`
  - `func has(anim_name: String) -> bool:`
  - `func face_from_direction(dir: Vector2) -> void:`
  - `func is_facing_right() -> bool:`
  - `func directional_walk_anim(dir: Vector2) -> String:`

## res://components/animation/player_animation_component.gd
- Class: `PlayerAnimationComponent`
- Extends: `Component`
- Exported properties:
  - `@export var anim_sprite: AnimatedSprite2D = null`
- Signals: none
- Functions:
  - `func _component_ready() -> void:`
  - `func setup(sprite: AnimatedSprite2D) -> void:`
  - `func play_idle(dir_key: String) -> void:`
  - `func play_walk(dir_key: String) -> void:`
  - `func play_run(dir_key: String) -> void:`
  - `func play_attack(dir_key: String) -> void:`
  - `func stop_animation() -> void:`
  - `func is_playing() -> bool:`
  - `func get_dir_from_vector(v: Vector2) -> String:`

## res://components/attack/attack_component.gd
- Class: `AttackComponent`
- Extends: `Component`
- Exported properties:
  - `@export var hitbox: Area2D = null`
  - `@export var hitbox_offsets: Dictionary = {`
- Signals:
  - `attack_started(direction: String)`
  - `attack_finished()`
  - `body_hit(body: Node)`
- Functions:
  - `func _component_ready() -> void:`
  - `func start_attack(dir_key: String) -> void:`
  - `func process_attack() -> bool:`
  - `func cancel_attack() -> void:`
  - `func is_attacking_now() -> bool:`
  - `func _on_hitbox_body_entered(body: Node) -> void:`

## res://components/biome/biome_component.gd
- Class: `BiomeComponent`
- Extends: `Component`
- Exported properties:
  - `@export var biome_id: String = "base"`
  - `@export var biome_color: Color = Color.WHITE`
- Signals: none
- Functions:
  - `func get_layers() -> Array[TileMapLayer]:`
  - `func get_used_rect() -> Rect2i:`

## res://components/biome/bridge_component.gd
- Class: `BridgeComponent`
- Extends: `Component`
- Exported properties:
  - `@export var bridge_layer_path: NodePath = NodePath("")`
- Signals: none
- Functions:
  - `func _component_ready() -> void:`
  - `func get_layer() -> TileMapLayer:`
  - `func is_bridge_at(cell: Vector2i) -> bool:`

## res://components/biome/buildings_component.gd
- Class: `BuildingsComponent`
- Extends: `Component`
- Exported properties:
  - `@export var buildings_layer_path: NodePath = NodePath("")`
- Signals: none
- Functions:
  - `func _component_ready() -> void:`
  - `func get_layer() -> TileMapLayer:`
  - `func has_building_at(cell: Vector2i) -> bool:`
  - `func building_count() -> int:`

## res://components/biome/elevation_component.gd
- Class: `ElevationComponent`
- Extends: `Component`
- Exported properties:
  - `@export var elevation_layer_path: NodePath = NodePath("")`
  - `@export var max_height_level: int = 4`
  - `@export var step_height_pixels: float = 16.0`
- Signals: none
- Functions:
  - `func _component_ready() -> void:`
  - `func get_layer() -> TileMapLayer:`
  - `func get_height_at(cell: Vector2i) -> int:`

## res://components/biome/props_component.gd
- Class: `PropsComponent`
- Extends: `Component`
- Exported properties:
  - `@export var props_layer_path: NodePath = NodePath("")`
- Signals: none
- Functions:
  - `func _component_ready() -> void:`
  - `func get_layer() -> TileMapLayer:`
  - `func has_prop_at(cell: Vector2i) -> bool:`

## res://components/biome/tree_top_layer_component.gd
- Class: `TreeTopLayerComponent`
- Extends: `Component`
- Exported properties:
  - `@export var treetop_layer_path: NodePath = NodePath("")`
  - `@export var wind_intensity: float = 0.0`
- Signals: none
- Functions:
  - `func _component_ready() -> void:`
  - `func get_layer() -> TileMapLayer:`
  - `func set_wind_intensity(amount: float) -> void:`

## res://components/biome/tree_trunk_layer_component.gd
- Class: `TreeTrunkLayerComponent`
- Extends: `Component`
- Exported properties:
  - `@export var trunk_layer_path: NodePath = NodePath("")`
  - `@export var add_collision: bool = true`
- Signals: none
- Functions:
  - `func _component_ready() -> void:`
  - `func get_layer() -> TileMapLayer:`

## res://components/book/book_animation_component.gd
- Class: `BookAnimationComponent`
- Extends: `Node`
- Exported properties:
  - `@export var animation_player: AnimationPlayer = null`
  - `@export var open_animation: String = "book_open"`
  - `@export var close_animation: String = "book_close"`
- Signals:
  - `book_opened()`
  - `book_closed()`
- Functions:
  - `func _ready() -> void:`
  - `func play_open() -> void:`
  - `func play_close() -> void:`
  - `func is_animating() -> bool:`
  - `func _on_animation_finished(anim_name: String) -> void:`

## res://components/book/book_page_component.gd
- Class: `BookPageComponent`
- Extends: `Control`
- Exported properties:
  - `@export var page_title: String = "Page"`
- Signals:
  - `page_opened()`
  - `page_closed()`
- Functions:
  - `func on_page_opened() -> void:`
  - `func on_page_closed() -> void:`

## res://components/book/credits_page_component.gd
- Class: `CreditsPageComponent`
- Extends: `Control`
- Exported properties:
  - `@export var page_title: String = "Credits"`
  - `@export var credit_lines: Array[String] = [`
- Signals:
  - `page_opened()`
  - `page_closed()`
- Functions:
  - `func _ready() -> void:`
  - `func on_page_opened() -> void:`
  - `func on_page_closed() -> void:`
  - `func _build_ui() -> void:`

## res://components/book/page_turn_component.gd
- Class: `PageTurnComponent`
- Extends: `Node`
- Exported properties:
  - `@export var animation_player: AnimationPlayer = null`
  - `@export var next_animation: String = "next_page"`
  - `@export var prev_animation: String = "previous_page"`
  - `@export var turning_page: Sprite2D = null`
- Signals:
  - `turn_completed(direction: int)  # +1 forward, -1 backward`
  - `turn_midpoint()                  # best moment to swap content invisibly`
- Functions:
  - `func _ready() -> void:`
  - `func turn_forward() -> void:`
  - `func turn_backward() -> void:`
  - `func _play_turn(anim_name: String, direction: int) -> void:`
  - `func is_turning() -> bool:`
  - `func _on_animation_finished(anim_name: String) -> void:`

## res://components/book/pause_component.gd
- Class: `PauseComponent`
- Extends: `Node`
- Exported properties:
  - `@export var pause_input_action: String = "pause"`
  - `@export var inventory_input_action: String = "inventory"`
- Signals:
  - `world_paused()`
  - `world_resumed()`
- Functions:
  - `func _ready() -> void:`
  - `func _process(_delta: float) -> void:`
  - `func pause_world() -> void:`
  - `func resume_world() -> void:`
  - `func is_world_paused() -> bool:`
  - `func _find_player() -> void:`

## res://components/book/settings_page_component.gd
- Class: `SettingsPageComponent`
- Extends: `Control`
- Exported properties:
  - `@export var page_title: String = "Settings"`
  - `@export var categories: Array[String] = ["Audio", "Graphics", "Controls", "Gameplay"]`
- Signals:
  - `page_opened()`
  - `page_closed()`
- Functions:
  - `func _ready() -> void:`
  - `func on_page_opened() -> void:`
  - `func on_page_closed() -> void:`
  - `func _build_ui() -> void:`
  - `func _on_category_selected(index: int) -> void:`
  - `func _rebuild_category_list() -> void:`
  - `func _show_category(index: int) -> void:`
  - `func _build_audio_settings() -> void:`
  - `func _build_graphics_settings() -> void:`
  - `func _build_controls_settings() -> void:`
  - `func _build_gameplay_settings() -> void:`
  - `func _build_placeholder(text: String) -> void:`
  - `func _create_slider_row(label_text: String, min_value: float, max_value: float, step: float, value: float) -> HSlider:`
  - `func _create_checkbox(label_text: String, toggled_on: bool) -> CheckBox:`
  - `func _on_master_volume_changed(value: float) -> void:`
  - `func _on_music_volume_changed(value: float) -> void:`
  - `func _on_sfx_volume_changed(value: float) -> void:`
  - `func _on_zoom_changed(value: float) -> void:`
  - `func _on_fullscreen_toggled(enabled: bool) -> void:`
  - `func _on_vsync_toggled(enabled: bool) -> void:`
  - `func _load_display_settings() -> void:`

## res://components/book/statistics_page_component.gd
- Class: `StatisticsPageComponent`
- Extends: `Control`
- Exported properties:
  - `@export var page_title: String = "Statistics"`
- Signals:
  - `page_opened()`
  - `page_closed()`
- Functions:
  - `func _ready() -> void:`
  - `func on_page_opened() -> void:`
  - `func on_page_closed() -> void:`
  - `func _build_ui() -> void:`
  - `func _refresh_stats() -> void:`

## res://components/chest/chest_component.gd
- Class: `ChestComponent`
- Extends: `Component`
- Exported properties:
  - `@export var chest_capacity: int = 12`
  - `@export var interact_radius: float = 40.0`
  - `@export var open_animation: String = "chest_opening"`
- Signals:
  - `chest_opened(chest: ChestComponent)`
  - `chest_closed(chest: ChestComponent)`
  - `contents_changed()`
- Functions:
  - `func _component_ready() -> void:`
  - `func get_storage() -> InventoryComponent:`
  - `func is_player_in_zone() -> bool:`
  - `func open_for(_player: Node) -> void:`
  - `func close() -> void:`
  - `func is_open() -> bool:`
  - `func _on_contents_changed() -> void:`
  - `func _build_interact_zone() -> void:`
  - `func get_save_data() -> Dictionary:`
  - `func load_from_save(data: Dictionary) -> void:`

## res://components/chest/chest_ui.gd
- Class: `(none)`
- Extends: `CanvasLayer`
- Exported properties: none
- Signals:
  - `chest_ui_opened(chest: ChestComponent)`
  - `chest_ui_closed()`
- Functions:
  - `func _ready() -> void:`
  - `func _process(_delta: float) -> void:`
  - `func show_for(chest: ChestComponent) -> void:`
  - `func show_for_inventories(left_inventory: InventoryComponent, right_inventory: InventoryComponent, left_title: String = "Inventory", right_title: String = "Storage") -> void:`
  - `func close_ui() -> void:`
  - `func _resolve_player_inventory() -> void:`
  - `func _resolve_player_inventory_for_return() -> InventoryComponent:`

## res://components/core/component.gd
- Class: `Component`
- Extends: `Node`
- Exported properties:
  - `@export var active: bool = true:`
- Signals:
  - `component_enabled()`
  - `component_disabled()`
- Functions:
  - `func _ready() -> void:`
  - `func _component_ready() -> void:`
  - `func get_entity() -> Node:`
  - `func get_sibling_component(component_class: Script) -> Component:`
  - `func get_sibling_component_by_name(comp_name: String) -> Component:`
  - `func _apply_active_state() -> void:`

## res://components/detection/detection_component.gd
- Class: `DetectionComponent`
- Extends: `Component`
- Exported properties:
  - `@export var detection_radius: float = 48.0`
  - `@export var target_group: String = "Player"`
- Signals:
  - `target_entered(body: Node2D)`
  - `target_exited(body: Node2D)`
- Functions:
  - `func _component_ready() -> void:`
  - `func _add_area_deferred(entity: Node, a: Area2D) -> void:`
  - `func get_closest_target() -> Node2D:`
  - `func has_target() -> bool:`
  - `func is_target_too_close(threshold: float) -> bool:`
  - `func is_target_safe(threshold: float) -> bool:`
  - `func _on_body_entered(body: Node2D) -> void:`
  - `func _on_body_exited(body: Node2D) -> void:`

## res://components/fade/fade_component.gd
- Class: `FadeComponent`
- Extends: `Component`
- Exported properties:
  - `@export var fade_in_duration: float = 0.5`
  - `@export var fade_out_duration: float = 0.8`
  - `@export var auto_fade_in: bool = true`
- Signals:
  - `fade_started(direction: String)`
  - `fade_completed(direction: String)`
- Functions:
  - `func _component_ready() -> void:`
  - `func fade_in(duration: float = -1.0) -> void:`
  - `func fade_out(duration: float = -1.0) -> void:`
  - `func is_fading() -> bool:`
  - `func kill_fade() -> void:`
  - `func _on_fade_in_complete(_duration: float) -> void:`
  - `func _on_fade_out_complete(_duration: float) -> void:`
  - `func _kill_tween() -> void:`
  - `func _find_canvas_item() -> CanvasItem:`

## res://components/farming/crop_growth_component.gd
- Class: `CropGrowthTileComponent`
- Extends: `Component`
- Exported properties:
  - `@export var sprite_path: NodePath = NodePath("../Sprite2D")`
- Signals:
  - `stage_changed(new_stage: int)`
  - `became_harvestable()`
- Functions:
  - `func _component_ready() -> void:`
  - `func initialize(data: CropData, day_planted: int, stage: int = 0, is_harvestable: bool = false) -> void:`
  - `func advance_to_day(current_day: int) -> void:`
  - `func consume_harvest(current_day: int) -> void:`
  - `func _apply_visual() -> void:`

## res://components/farming/farming_component.gd
- Class: `FarmingComponent`
- Extends: `Component`
- Exported properties:
  - `@export var cooldown_time: float = 0.4`
- Signals:
  - `farming_action_performed(action: String, tile_pos: Vector2i)`
- Functions:
  - `func setup(farm_mgr: FarmManager, inv: InventoryComponent) -> void:`
  - `func process_cooldown(delta: float) -> void:`
  - `func is_on_cooldown() -> bool:`
  - `func do_farming_action(entity_pos: Vector2, last_dir: Vector2) -> bool:`
  - `func try_harvest(entity_pos: Vector2, last_dir: Vector2) -> bool:`
  - `func _plant_seed(tile_pos: Vector2i) -> bool:`
  - `func _get_target_tile(entity_pos: Vector2, last_dir: Vector2) -> Vector2i:`

## res://components/flee/flee_component.gd
- Class: `FleeComponent`
- Extends: `Component`
- Exported properties:
  - `@export var flee_distance: float = 48.0`
  - `@export var flee_safe_distance: float = 200.0`
  - `@export var flee_speed: float = 60.0`
  - `@export var detection_component_path: NodePath = NodePath("")`
- Signals:
  - `started_fleeing(direction: Vector2)`
  - `finished_fleeing()`
- Functions:
  - `func _component_ready() -> void:`
  - `func start_fleeing() -> void:`
  - `func stop_fleeing() -> void:`
  - `func process_flee(entity: CharacterBody2D) -> bool:`
  - `func get_flee_direction() -> Vector2:`
  - `func should_start_fleeing() -> bool:`
  - `func _get_flee_direction() -> Vector2:`
  - `func _get_flee_direction_from_target(target: Node2D) -> Vector2:`

## res://components/health/health_component.gd
- Class: `HealthComponent`
- Extends: `Component`
- Exported properties:
  - `@export var min_hp: int = 0`
  - `@export var max_hp: int = 2`
  - `@export var start_hp: int = -1`
- Signals:
  - `health_changed(old_value: int, new_value: int)`
  - `damaged(amount: int, remaining: int)`
  - `healed(amount: int, current: int)`
  - `died()`
- Functions:
  - `func _component_ready() -> void:`
  - `func take_damage(amount: int) -> void:`
  - `func heal(amount: int) -> void:`
  - `func set_hp(value: int) -> void:`
  - `func get_hp() -> int:`
  - `func get_hp_ratio() -> float:`
  - `func reset() -> void:`

## res://components/inventory/inventory_component.gd
- Class: `InventoryComponent`
- Extends: `Component`
- Exported properties:
  - `@export var item_capacity: int = 24`
  - `@export_range(2, 16, 1) var hotbar_slot_count: int = 8`
- Signals:
  - `slot_selected(index: int)`
  - `inventory_changed()`
  - `items_changed()`
- Functions:
  - `func setup_with_action_bar(action_bar_node: Node) -> void:`
  - `func add_tool(tool: ToolData) -> void:`
  - `func add_seed(crop: CropData) -> void:`
  - `func select_slot(index: int) -> bool:`
  - `func get_selected_tool() -> ToolData:`
  - `func get_selected_seed() -> CropData:`
  - `func is_tool_selected() -> bool:`
  - `func is_seed_selected() -> bool:`
  - `func is_seed_pouch_equipped() -> bool:`
  - `func get_total_slots() -> int:`
  - `func get_hotbar_slot_count() -> int:`
  - `func get_hotbar_texture(slot_index: int) -> Texture2D:`
  - `func get_hotbar_slot_label(slot_index: int) -> String:`
  - `func update_action_bar() -> void:`
  - `func _on_action_bar_selected(slot_index: int) -> void:`
  - `func add_item(stack: ItemStack) -> int:`
  - `func remove_item(item_id: String, amount: int = 1) -> int:`
  - `func count_of(item_id: String) -> int:`
  - `func get_item_index(item_id: String) -> int:`
  - `func move_slot(from: int, to: int) -> void:`
  - `func transfer_to(other: InventoryComponent, from: int, to: int) -> bool:`
  - `func equip_tool(index: int) -> void:`
  - `func get_equipped_tool() -> ToolData:`
  - `func get_save_data() -> Dictionary:`
  - `func load_from_save(data: Dictionary) -> void:`

## res://components/inventory/inventory_grid.gd
- Class: `InventoryGrid`
- Extends: `Control`
- Exported properties:
  - `@export var columns: int = SLOT_COLUMNS`
  - `@export var slot_size: float = SLOT_SIZE`
  - `@export var slot_gap: float = SLOT_GAP`
  - `@export var read_only: bool = false`
- Signals:
  - `stack_dragged_to(other_grid: InventoryGrid, from_index: int, to_index: int)`
- Functions:
  - `func _ready() -> void:`
  - `func bind_inventory(inventory: InventoryComponent) -> void:`
  - `func refresh() -> void:`
  - `func _build_ui() -> void:`
  - `func _make_slot(index: int) -> TextureRect:`
  - `func _stack_at(index: int) -> ItemStack:`
  - `func _on_slot_gui_input(event: InputEvent, index: int, slot: TextureRect) -> void:`
  - `func _start_drag(index: int, _slot: TextureRect) -> void:`
  - `func _end_drag(_slot: TextureRect, index: int) -> void:`
  - `func _split_stack(index: int) -> void:`
  - `func _on_slot_mouse_entered(index: int) -> void:`
  - `func _on_slot_mouse_exited() -> void:`
  - `func _show_drag_tooltip(index: int) -> void:`
  - `func _hide_drag_tooltip() -> void:`
  - `func _update_tooltip_to_mouse() -> void:`
  - `func _position_tooltip() -> void:`
  - `func _find_grid_under_mouse() -> InventoryGrid:`
  - `func _slot_index_at_mouse() -> int:`
  - `func _unhandled_input(event: InputEvent) -> void:`
  - `func _update_selection_visuals() -> void:`

## res://components/light_source/emissive_light_component.gd
- Class: `EmissiveLightComponent`
- Extends: `Component`
- Exported properties:
  - `@export var light_color: Color = Color(1.0, 0.82, 0.5, 1.0)`
  - `@export_range(0.0, 5.0, 0.05) var light_energy: float = 1.5`
  - `@export_range(0.1, 10.0, 0.1) var light_scale: float = 3.0`
  - `@export var light_offset: Vector2 = Vector2.ZERO`
  - `@export var shadow_enabled: bool = true`
  - `@export var flame_sprite: AnimatedSprite2D = null`
  - `@export var lit_animation: String = ""`
  - `@export var unlit_animation: String = ""`
  - `@export var auto_light: bool = true`
- Signals: none
- Functions:
  - `func _component_ready() -> void:`
  - `func set_lit(lit: bool) -> void:`
  - `func is_lit() -> bool:`
  - `func set_light_color(color: Color) -> void:`
  - `func set_light_energy(energy: float) -> void:`

## res://components/light_source/light_source_component.gd
- Class: `LightSourceComponent`
- Extends: `Component`
- Exported properties:
  - `@export var flame_sprite: AnimatedSprite2D = null`
  - `@export var lit_animation: String = ""`
  - `@export var unlit_animation: String = ""`
  - `@export var base_energy: float = 1.0`
  - `@export var auto_light: bool = true`
- Signals: none
- Functions:
  - `func _component_ready() -> void:`
  - `func _exit_tree() -> void:`
  - `func set_lit(lit: bool) -> void:`
  - `func is_lit() -> bool:`
  - `func _set_lit(lit: bool) -> void:`
  - `func _find_lights() -> void:`
  - `func _find_lighting_manager() -> LightingManager:`

## res://components/movement/movement_component.gd
- Class: `MovementComponent`
- Extends: `Component`
- Exported properties:
  - `@export var walk_speed: float = 80.0`
  - `@export var run_speed: float = 140.0`
- Signals: none
- Functions:
  - `func set_speed_modifier(mod: float) -> void:`
  - `func read_input() -> void:`
  - `func calculate_velocity() -> Vector2:`
  - `func get_last_dir() -> Vector2:`
  - `func set_input_enabled(enabled: bool) -> void:`
  - `func _read_movement_input() -> Vector2:`
  - `func _get_joystick() -> MobileJoystick:`

## res://components/rope/rope_component.gd
- Class: `RopeComponent`
- Extends: `Component`
- Exported properties:
  - `@export var drag_speed: float = 150.0`
  - `@export var rotation_speed: float = 0.1`
  - `@export var base_multiplier: float = 0.4`
  - `@export var stack_penalty: float = 0.1`
- Signals:
  - `attached(target: Node2D)`
  - `detached()`
- Functions:
  - `func _component_ready() -> void:`
  - `func attach_to_target(target: Node2D) -> bool:`
  - `func detach() -> void:`
  - `func is_attached() -> bool:`
  - `func get_rope_anchor_global() -> Vector2:`
  - `func apply_forces(state: PhysicsDirectBodyState2D) -> void:`
  - `func _on_push_detector_body_entered(body: Node2D) -> void:`
  - `func _on_push_detector_body_exited(body: Node2D) -> void:`
  - `func _update_player_penalty() -> void:`

## res://components/wander/wander_component.gd
- Class: `WanderComponent`
- Extends: `Component`
- Exported properties:
  - `@export var wander_radius: float = 128.0`
  - `@export var walk_speed: float = 30.0`
  - `@export var idle_time_min: float = 3.0`
  - `@export var idle_time_max: float = 8.0`
  - `@export var wander_chance: float = 0.4`
  - `@export var detection_component_path: NodePath = NodePath("")`
- Signals:
  - `started_wandering(target: Vector2)`
  - `stopped_wandering()`
  - `reached_target()`
- Functions:
  - `func _component_ready() -> void:`
  - `func start_wandering() -> void:`
  - `func stop_wandering() -> void:`
  - `func process_idle(delta: float) -> bool:`
  - `func process_wander(_delta: float, entity: CharacterBody2D) -> bool:`
  - `func get_move_direction() -> Vector2:`
  - `func _pick_wander_target() -> Vector2:`
  - `func _pick_new_idle_time() -> void:`

## res://components/weather/lightning_component.gd
- Class: `LightningComponent`
- Extends: `Component`
- Exported properties:
  - `@export var bolt_texture: Texture2D = preload("res://assets/generated/lightning_bolt_frame_0.png")`
  - `@export var flash_color: Color = Color(1.0, 1.0, 0.95, 1.0)`
  - `@export_range(0.0, 1.0, 0.01) var max_flash_alpha: float = 0.7`
  - `@export var show_bolt_sprite: bool = true`
  - `@export_range(50, 500, 10) var bolt_height: float = 300.0`
  - `@export var brighten_ambient: bool = true`
  - `@export_range(0.0, 1.0, 0.01) var ambient_boost: float = 0.6`
- Signals: none
- Functions:
  - `func _component_ready() -> void:`
  - `func _process(_delta: float) -> void:`
  - `func _on_lightning_strike(brightness: float, duration: float) -> void:`
  - `func _ambient_flash(duration: float) -> void:`
  - `func _build_flash_overlay() -> void:`
  - `func _build_bolt_sprite() -> void:`
  - `func _find_weather_manager() -> WeatherManager:`
  - `func _find_lighting_manager() -> LightingManager:`

## res://components/weather/rain_component.gd
- Class: `RainComponent`
- Extends: `Component`
- Exported properties:
  - `@export var drop_texture: Texture2D = preload("res://assets/generated/rain_drop_frame_0.png")`
  - `@export_range(50, 2000, 10) var max_particles: int = 600`
  - `@export var rain_area: Vector2 = Vector2(1920, 1080)`
  - `@export var follow_target: Node2D = null`
  - `@export_range(100, 2000, 10) var follow_radius: float = 700.0`
  - `@export_range(50, 1000, 10) var fall_speed: float = 400.0`
  - `@export_range(0.0, 1.0, 0.01) var wind_tilt: float = 0.6`
- Signals: none
- Functions:
  - `func _component_ready() -> void:`
  - `func _process(delta: float) -> void:`
  - `func _build_emitter() -> void:`
  - `func _apply_wind_tilt() -> void:`
  - `func _find_weather_manager() -> WeatherManager:`
  - `func get_display_intensity() -> float:`

## res://components/weather/thunder_component.gd
- Class: `ThunderComponent`
- Extends: `Component`
- Exported properties:
  - `@export var thunder_clips: Array[AudioStream] = []`
  - `@export_range(-40.0, 0.0, 0.5) var close_volume: float = -3.0`
  - `@export_range(-60.0, 0.0, 0.5) var distant_volume: float = -25.0`
  - `@export var pitch_min: float = 0.85`
  - `@export var pitch_max: float = 1.15`
  - `@export var synthesize_if_empty: bool = true`
- Signals: none
- Functions:
  - `func _component_ready() -> void:`
  - `func _process(_delta: float) -> void:`
  - `func _on_thunder_triggered(distance: float) -> void:`
  - `func _play_clip(clip: AudioStream, volume: float, pitch: float) -> void:`
  - `func _play_synthesized(volume: float, pitch: float) -> void:`
  - `func _find_weather_manager() -> WeatherManager:`

## res://components/weather/weather_controller.gd
- Class: `WeatherController`
- Extends: `Component`
- Exported properties:
  - `@export_group("Chances")`
  - `@export_range(0.0, 1.0, 0.01) var storm_chance: float = 0.15`
  - `@export_range(0.0, 1.0, 0.01) var rain_chance: float = 0.25`
  - `@export_range(0.0, 1.0, 0.01) var wind_chance: float = 0.35`
  - `@export_range(0.0, 1.0, 0.01) var lightning_chance: float = 0.5`
  - `@export_range(0.0, 1.0, 0.01) var thunder_chance: float = 0.9`
  - `@export_group("Durations")`
  - `@export var min_storm_duration: float = 60.0`
  - `@export var max_storm_duration: float = 180.0`
  - `@export var min_clear_duration: float = 90.0`
  - `@export var max_clear_duration: float = 240.0`
  - `@export_group("Intensities")`
  - `@export_range(0.0, 1.0, 0.01) var wind_strength: float = 0.3`
  - `@export_range(0.0, 1.0, 0.01) var rain_intensity: float = 0.5`
  - `@export_range(0.0, 1.0, 0.01) var lightning_frequency: float = 0.1`
  - `@export_range(1.0, 3.0, 0.05) var storm_wind_multiplier: float = 1.6`
  - `@export_group("Wind")`
  - `@export_range(0.2, 10.0, 0.1) var gust_frequency: float = 2.2`
  - `@export_range(0.1, 5.0, 0.1) var gust_duration: float = 1.0`
  - `@export_range(0.0, 1.0, 0.01) var gust_randomness: float = 0.45`
  - `@export_group("Thunder")`
  - `@export var thunder_delay_min: float = 0.5`
  - `@export var thunder_delay_max: float = 4.0`
  - `@export_group("Advanced")`
  - `@export var transition_speed: float = 1.5`
  - `@export var season_multiplier: float = 1.0`
  - `@export var random_seed: int = 0`
  - `@export var enable_debug: bool = false`
- Signals: none
- Functions:
  - `func _component_ready() -> void:`
  - `func _find_weather_manager() -> WeatherManager:`

## res://components/weather/wind_component.gd
- Class: `WindComponent`
- Extends: `Component`
- Exported properties:
  - `@export var wind_target: WindTarget = WindTarget.TILEMAP_LAYER`
  - `@export var target_path: NodePath = NodePath("")`
  - `@export_range(0.0, 20.0, 0.1) var sway_amplitude: float = 3.0`
  - `@export_range(0.0, 5.0, 0.01) var sway_frequency: float = 1.5`
  - `@export_range(0.0, 0.5, 0.01) var rotation_strength: float = 0.05`
  - `@export var react_to_gusts: bool = true`
- Signals: none
- Functions:
  - `func _component_ready() -> void:`
  - `func _process(delta: float) -> void:`
  - `func _apply_tilemap(strength: float, _direction: float) -> void:`
  - `func _apply_sprite(strength: float, _direction: float, gust: float) -> void:`
  - `func _apply_particles(strength: float, direction: float) -> void:`
  - `func _auto_resolve_target() -> Node:`
  - `func _find_weather_manager() -> WeatherManager:`

## res://resources/items/item_definition.gd
- Class: `ItemDefinition`
- Extends: `Resource`
- Exported properties:
  - `@export var item_id: String = ""`
  - `@export var item_name: String = "Item"`
  - `@export_multiline var description: String = ""`
  - `@export var icon: Texture2D = null`
  - `@export var world_sprite: Texture2D = null`
  - `@export var weight: float = 0.0`
  - `@export var sell_value: int = 0`
  - `@export var category: ItemCategory = ItemCategory.MISC`
  - `@export var can_equip: bool = false`
  - `@export var tool_type: String = ""`
  - `@export var consumable: bool = false`
  - `@export var quest_item: bool = false`
  - `@export var max_stack_size: int = 1`
- Signals: none
- Functions: none

## res://resources/items/item_stack.gd
- Class: `ItemStack`
- Extends: `Resource`
- Exported properties:
  - `@export var item_id: String = ""`
  - `@export var item_name: String = "Item"`
  - `@export var icon: Texture2D = null`
  - `@export var count: int = 1`
  - `@export var max_stack: int = 99`
  - `@export var stackable: bool = true`
  - `@export var crop_ref: CropData = null`
  - `@export var tool_ref: ToolData = null`
- Signals: none
- Functions:
  - `func can_accept_more(amount: int) -> bool:`
  - `func add(amount: int) -> int:`
  - `func remove(amount: int) -> int:`
  - `func is_empty() -> bool:`
  - `func same_type(other: Resource) -> bool:`

## res://scenes/book/book_ui_controller.gd
- Class: `(none)`
- Extends: `CanvasLayer`
- Exported properties:
  - `@export var dimmer_fade_duration: float = 0.3`
  - `@export var dimmer_alpha: float = 0.45`
- Signals:
  - `book_opened(page_index: int)`
  - `book_closed()`
- Functions:
  - `func _ready() -> void:`
  - `func _process(_delta: float) -> void:`
  - `func _discover_pages() -> void:`
  - `func _wire_page_signals() -> void:`
  - `func _show_page(page_index: int, show_it: bool) -> void:`
  - `func _on_pause_input() -> void:`
  - `func open_book(target_page: int) -> void:`
  - `func close_book() -> void:`
  - `func _on_book_opened() -> void:`
  - `func _on_book_closed() -> void:`
  - `func turn_to_page(target: int) -> void:`
  - `func _on_turn_midpoint() -> void:`
  - `func _on_turn_completed(_direction: int) -> void:`
  - `func _on_corner_prev() -> void:`
  - `func _on_corner_next() -> void:`
  - `func _show_nav() -> void:`
  - `func _hide_nav() -> void:`
  - `func _on_save_requested() -> void:`
  - `func _on_exit_requested() -> void:`
  - `func _tween_dimmer(target_alpha: float) -> void:`
  - `func _find_component_by_script(script_path: String) -> Node:`

## res://scenes/menu/main_menu.gd
- Class: `MainMenu`
- Extends: `Control`
- Exported properties: none
- Signals: none
- Functions:
  - `func _ready() -> void:`
  - `func _animate_background() -> void:`
  - `func _on_new_game_pressed() -> void:`
  - `func _on_continue_pressed() -> void:`
  - `func _on_settings_pressed() -> void:`
  - `func _on_slot_cancelled() -> void:`
  - `func _on_slot_selected(slot_index: int) -> void:`
  - `func _transition_to(scene_path: String) -> void:`

## res://scenes/ui/inventory_window.gd
- Class: `InventoryWindow`
- Extends: `CanvasLayer`
- Exported properties: none
- Signals:
  - `inventory_opened()`
  - `inventory_closed()`
- Functions:
  - `func _ready() -> void:`
  - `func _process(_delta: float) -> void:`
  - `func toggle_ui() -> void:`
  - `func open_ui() -> void:`
  - `func close_ui() -> void:`
  - `func is_open() -> bool:`
  - `func open_for_inventory(inventory: InventoryComponent, title: String = "Inventory") -> void:`
  - `func _bind_player_inventory() -> void:`
  - `func _set_player_paused(paused: bool) -> void:`
  - `func _on_inventory_items_changed() -> void:`
  - `func _sync_hotbar_grid() -> void:`
  - `func _deferred_sync_hotbar_grid() -> void:`

## res://scripts/autoload/scene_transition.gd
- Class: `(none)`
- Extends: `CanvasLayer`
- Exported properties: none
- Signals: none
- Functions:
  - `func _ready() -> void:`
  - `func transition(scene_path: String, fade_duration: float = 0.5) -> void:`

## res://scripts/components/bucket/bucket_component.gd
- Class: `BucketComponent`
- Extends: `Component`
- Exported properties:
  - `@export var auto_grant_starter_bucket: bool = true`
- Signals:
  - `bucket_state_changed(state_item_id: String)`
- Functions:
  - `func _component_ready() -> void:`
  - `func has_empty_bucket() -> bool:`
  - `func has_pitch_bucket() -> bool:`
  - `func collect_pitch() -> bool:`
  - `func deposit_pitch() -> bool:`
  - `func _make_stack(item_id: String, item_name: String, count: int) -> ItemStack:`

## res://scripts/components/construction/construction_area_component.gd
- Class: `ConstructionAreaComponent`
- Extends: `Component`
- Exported properties:
  - `@export var construction_name: String = "Construction"`
  - `@export var stages: Array[ConstructionStageResource] = []`
  - `@export var construction_plan: ConstructionPlanResource = null`
  - `@export var current_stage: int = 0`
  - `@export var blueprint_sprite: Texture2D = null`
  - `@export var completed_scene: PackedScene = null`
  - `@export var interact_radius: float = 60.0`
  - `@export var accepted_resource_types: Array[String] = []`
  - `@export var auto_spawn_stage_scene: bool = true`
- Signals:
  - `resource_deposited(item_id: String, amount: int)`
  - `stage_progressed(stage_index: int)`
  - `construction_completed(construction_name: String)`
- Functions:
  - `func _component_ready() -> void:`
  - `func _apply_plan_if_present() -> void:`
  - `func is_player_in_zone() -> bool:`
  - `func is_finished() -> bool:`
  - `func get_current_stage() -> ConstructionStageResource:`
  - `func try_deposit(item_id: String, amount: int = 1) -> int:`
  - `func get_required_count(item_id: String) -> int:`
  - `func get_deposited_count(item_id: String) -> int:`
  - `func _find_requirement(stage: ConstructionStageResource, item_id: String) -> Resource:`
  - `func _is_stage_complete(stage: ConstructionStageResource) -> bool:`
  - `func _advance_stage() -> void:`
  - `func _complete_construction() -> void:`
  - `func _refresh_visuals() -> void:`
  - `func _build_interact_zone() -> void:`
  - `func _stage_item_key(stage_index: int, item_id: String) -> String:`

## res://scripts/components/crafting/crafting_bench_component.gd
- Class: `CraftingBenchComponent`
- Extends: `Component`
- Exported properties:
  - `@export var bench_name: String = "Crafting Bench"`
  - `@export var recipes: Array[Resource] = []`
  - `@export var interact_radius: float = 48.0`
- Signals:
  - `crafted(recipe_id: String)`
- Functions:
  - `func _component_ready() -> void:`
  - `func is_player_in_zone() -> bool:`
  - `func craft_first_available(inventory: InventoryComponent) -> bool:`
  - `func can_craft(recipe: Resource, inventory: InventoryComponent) -> bool:`
  - `func craft(recipe_id: String, inventory: InventoryComponent) -> bool:`
  - `func _find_recipe(recipe_id: String) -> Resource:`
  - `func _build_interact_zone() -> void:`

## res://scripts/components/resources/resource_collector_component.gd
- Class: `ResourceCollectorComponent`
- Extends: `Component`
- Exported properties:
  - `@export var source_resource_id: String = "pitch"`
  - `@export var required_container_item_id: String = "bucket_empty"`
  - `@export var produced_item_id: String = "bucket_pitch"`
  - `@export var produce_amount: int = 1`
  - `@export var interact_radius: float = 40.0`
- Signals:
  - `resource_collected(resource_id: String, amount: int)`
- Functions:
  - `func _component_ready() -> void:`
  - `func is_player_in_zone() -> bool:`
  - `func collect_into(inventory: InventoryComponent) -> int:`
  - `func _build_interact_zone() -> void:`

## res://scripts/cutscenes/cutscene_placeholder.gd
- Class: `CutscenePlaceholder`
- Extends: `Control`
- Exported properties:
  - `@export var next_scene_path: String = "res://scenes/world/world.tscn"`
  - `@export var duration_seconds: float = 2.0`
  - `@export var caption_text: String = "# PLACEHOLDER: Cutscene"`
- Signals: none
- Functions:
  - `func _ready() -> void:`

## res://scripts/farming/crop_data.gd
- Class: `CropData`
- Extends: `Resource`
- Exported properties:
  - `@export var crop_name: String = ""`
  - `@export var growth_stages: int = 4`
  - `@export var growth_days: int = 4`
  - `@export var stage_sprites: Array[Texture2D] = []`
  - `@export var harvest_item_id: String = ""`
  - `@export var harvest_item_name: String = ""`
  - `@export var harvest_amount: int = 1`
  - `@export var harvest_icon: Texture2D = null`
  - `@export var regrowable: bool = false`
  - `@export var regrow_days: int = 2`
  - `@export var seed_sprite: Texture2D = null`
  - `@export var seed_tile_coords: Vector2i = Vector2i.ZERO`
  - `@export var min_yield: int = 1`
  - `@export var max_yield: int = 1`
  - `@export var harvest_sprite: Texture2D = null`
- Signals: none
- Functions:
  - `func get_growth_days() -> int:`
  - `func get_growth_stage_count() -> int:`
  - `func get_stage_sprite(stage: int) -> Texture2D:`
  - `func is_regrowable() -> bool:`
  - `func get_regrow_days() -> int:`
  - `func get_harvest_amount() -> int:`
  - `func get_harvest_item_id() -> String:`
  - `func get_harvest_display_name() -> String:`
  - `func get_harvest_icon() -> Texture2D:`

## res://scripts/farming/crop_growth_component.gd
- Class: `FarmCropGrowthMath`
- Extends: `Node`
- Exported properties: none
- Signals: none
- Functions:
  - `func get_expected_stage(days_elapsed: int, growth_days: int, growth_stages: int) -> int:`
  - `func is_harvestable(stage: int, growth_stages: int) -> bool:`

## res://scripts/farming/farm_manager.gd
- Class: `FarmManager`
- Extends: `Node2D`
- Exported properties:
  - `@export var tile_size: int = 32`
  - `@export var map_node_name: StringName = &"map"`
  - `@export var grass_layer_names: Array[StringName] = [&"Grass", &"grass", &"Ground", &"ground"]`
  - `@export var tilled_layer_names: Array[StringName] = [&"TilledSoil", &"garden"]`
  - `@export var meadows_layer_names: Array[StringName] = [&"Meadows", &"Interaction"]`
- Signals:
  - `tile_tilled(tile_pos: Vector2i)`
  - `crop_planted(tile_pos: Vector2i, crop_name: String)`
  - `crop_grew(tile_pos: Vector2i, stage: int)`
  - `crop_harvestable(tile_pos: Vector2i, crop_name: String)`
  - `crop_harvested(tile_pos: Vector2i, crop_name: String, yield_count: int)`
- Functions:
  - `func _ready() -> void:`
  - `func _setup_growth_component() -> void:`
  - `func _find_time_manager() -> void:`
  - `func _on_time_tick(_hour: int, _minute: int, day: int) -> void:`
  - `func _on_day_change(day: int) -> void:`
  - `func _find_map_layers() -> void:`
  - `func _find_first_layer(root: Node, names: Array[StringName]) -> TileMapLayer:`
  - `func is_grass_tile(tile_pos: Vector2i) -> bool:`
  - `func is_meadows_tile(tile_pos: Vector2i) -> bool:`
  - `func is_tillable(tile_pos: Vector2i) -> bool:`
  - `func till_tile(tile_pos: Vector2i) -> bool:`
  - `func clear_soil_tile(tile_pos: Vector2i) -> void:`
  - `func _load_crop_registry() -> void:`
  - `func get_tile_data(tile_pos: Vector2i) -> Dictionary:`
  - `func is_plantable(tile_pos: Vector2i) -> bool:`
  - `func is_harvestable(tile_pos: Vector2i) -> bool:`
  - `func plant_crop(tile_pos: Vector2i, crop_id: String) -> bool:`
  - `func harvest_tile(tile_pos: Vector2i) -> int:`
  - `func _spawn_harvest_pickup(crop: CropData, tile_pos: Vector2i, yield_count: int) -> void:`
  - `func _process_daily_growth(day: int) -> void:`
  - `func _process_soil_reversion(day: int) -> void:`
  - `func _create_crop_sprite(tile_pos: Vector2i, texture: Texture2D) -> void:`
  - `func _update_crop_sprite(tile_pos: Vector2i, texture: Texture2D) -> void:`
  - `func _remove_crop_sprite(tile_pos: Vector2i) -> void:`
  - `func get_save_data() -> Dictionary:`
  - `func load_from_save(farm_data: Dictionary) -> void:`
  - `func get_world_pos(tile_pos: Vector2i) -> Vector2:`
  - `func get_tile_pos(world_pos: Vector2) -> Vector2i:`
  - `func get_crop_names() -> Array[String]:`

## res://scripts/farming/harvest_pickup.gd
- Class: `HarvestPickup`
- Extends: `Node2D`
- Exported properties:
  - `@export var collect_radius: float = 28.0`
  - `@export var collect_speed: float = 420.0`
  - `@export var bob_height: float = 4.0`
  - `@export var bob_speed: float = 2.5`
- Signals: none
- Functions:
  - `func _ready() -> void:`
  - `func _process(delta: float) -> void:`
  - `func set_stack(stack: ItemStack) -> void:`
  - `func _resolve_player() -> void:`
  - `func _collect() -> void:`

## res://scripts/farming/tool_data.gd
- Class: `ToolData`
- Extends: `Resource`
- Exported properties:
  - `@export var tool_name: String = ""`
  - `@export var tool_type: ToolType = ToolType.HOE`
  - `@export var tier: String = "starter"`
  - `@export var swing_sprites: Array[Texture2D] = []`
  - `@export var icon: Texture2D = null`
  - `@export var range_tiles: int = 1`
  - `@export var speed_multiplier: float = 1.0`
  - `@export var efficiency: float = 1.0`
- Signals: none
- Functions: none

## res://scripts/menu/save_selection_menu.gd
- Class: `SaveSelectionMenu`
- Extends: `Control`
- Exported properties: none
- Signals:
  - `slot_selected(slot_index: int)`
  - `cancelled()`
- Functions:
  - `func _ready() -> void:`

## res://scripts/npc/animal_npc.gd
- Class: `AnimalNPC`
- Extends: `CharacterBody2D`
- Exported properties:
  - `@export var wander_radius: float = 128.0`
  - `@export var flee_distance: float = 48.0`
  - `@export var flee_safe_distance: float = 200.0`
  - `@export var walk_speed: float = 30.0`
  - `@export var flee_speed: float = 60.0`
  - `@export var idle_time_min: float = 3.0`
  - `@export var idle_time_max: float = 8.0`
  - `@export var wander_chance: float = 0.4`
  - `@export_group("Fade")`
  - `@export var auto_fade_in: bool = true`
- Signals:
  - `started_wandering()`
  - `stopped_wandering()`
  - `started_fleeing()`
  - `finished_fleeing()`
  - `fade_complete()`
- Functions:
  - `func _ready() -> void:`
  - `func _resolve_components() -> void:`
  - `func _process(_delta: float) -> void:`
  - `func _physics_process(delta: float) -> void:`
  - `func _process_idle(delta: float) -> void:`
  - `func _pick_new_idle_time() -> void:`
  - `func _start_wandering() -> void:`
  - `func _process_wandering(delta: float) -> void:`
  - `func _end_wandering() -> void:`
  - `func _pick_wander_target() -> Vector2:`
  - `func _should_flee() -> bool:`
  - `func _start_fleeing() -> void:`
  - `func _process_fleeing(_delta: float) -> void:`
  - `func _end_flee() -> void:`
  - `func _get_flee_direction() -> Vector2:`
  - `func _player_is_safe() -> bool:`
  - `func _process_flee_finished(_delta: float) -> void:`
  - `func _face(dir: Vector2) -> void:`
  - `func _handle_idle(_delta: float) -> void:`
  - `func _play_walk(_dir: Vector2) -> void:`
  - `func _play_flee(_dir: Vector2) -> void:`
  - `func _on_start_flee() -> void:`
  - `func _on_flee_safe() -> void:`
  - `func _on_animation_finished() -> void:`
  - `func _change_state(new_state: AnimalState) -> void:`
  - `func _on_enter_state(_new_state: AnimalState) -> void:`
  - `func _on_fade_completed(_direction: String) -> void:`
  - `func _start_fade_in() -> void:`
  - `func _on_fade_out_complete() -> void:`

## res://scripts/npc/bird_ai.gd
- Class: `BirdAI`
- Extends: `AnimalNPC`
- Exported properties:
  - `@export var fly_speed: float = 120.0`
  - `@export var fly_height: float = 56.0`
  - `@export var fly_return_distance: float = 150.0`
  - `@export var hop_chance: float = 0.5`
- Signals: none
- Functions:
  - `func _ready() -> void:`
  - `func _handle_idle(_delta: float) -> void:`
  - `func _play_walk(_dir: Vector2) -> void:`
  - `func _on_start_flee() -> void:`
  - `func _process_fleeing(_delta: float) -> void:`
  - `func _on_flee_safe() -> void:`
  - `func _process_flee_finished(_delta: float) -> void:`
  - `func _start_landing() -> void:`
  - `func _on_animation_finished() -> void:`

## res://scripts/npc/duck_ai.gd
- Class: `DuckAI`
- Extends: `AnimalNPC`
- Exported properties:
  - `@export var near_water: bool = false`
- Signals: none
- Functions:
  - `func _ready() -> void:`
  - `func _ensure_ripples_playing() -> void:`
  - `func _handle_idle(delta: float) -> void:`
  - `func _play_walk(dir: Vector2) -> void:`
  - `func _on_start_flee() -> void:`
  - `func _play_flee(dir: Vector2) -> void:`
  - `func _on_flee_safe() -> void:`
  - `func _on_animation_finished() -> void:`
  - `func _on_fade_out_complete() -> void:`

## res://scripts/npc/frog_ai.gd
- Class: `FrogAI`
- Extends: `AnimalNPC`
- Exported properties:
  - `@export var hop_distance: float = 24.0`
  - `@export var hop_cooldown: float = 0.5`
  - `@export var idle_variant_chance: float = 0.35`
- Signals: none
- Functions:
  - `func _handle_idle(_delta: float) -> void:`
  - `func _process_wandering(delta: float) -> void:`
  - `func _hop_step(delta: float, dir: Vector2, speed: float) -> void:`
  - `func _play_walk(dir: Vector2) -> void:`
  - `func _on_start_flee() -> void:`
  - `func _play_flee(dir: Vector2) -> void:`
  - `func _on_flee_safe() -> void:`
  - `func _on_animation_finished() -> void:`

## res://scripts/player/player.gd
- Class: `Player`
- Extends: `CharacterBody2D`
- Exported properties: none
- Signals: none
- Functions:
  - `func _ready() -> void:`
  - `func _physics_process(delta: float) -> void:`
  - `func set_player_paused(paused: bool) -> void:`
  - `func set_speed_modifier(mod: float) -> void:`
  - `func _handle_movement_state() -> void:`
  - `func _handle_attack_state() -> void:`
  - `func _on_hitbox_body_entered(_body: Node) -> void:`
  - `func _handle_farming_state() -> void:`
  - `func _process_input_actions() -> void:`
  - `func _handle_interact() -> void:`
  - `func _start_attack() -> void:`
  - `func _try_attach_rope() -> void:`
  - `func _attach_rope(log_body: Node2D) -> void:`
  - `func _detach_rope() -> void:`
  - `func _handle_chest() -> bool:`
  - `func safe_get_chest_ui() -> CanvasLayer:`
  - `func _get_inventory_window() -> CanvasLayer:`
  - `func _handle_construction_deposit() -> bool:`
  - `func _deposit_into_area(area: Node) -> bool:`
  - `func _handle_resource_collection() -> bool:`
  - `func _handle_crafting() -> bool:`
  - `func _update_rope_visuals() -> void:`
  - `func _can_attack_with_axe() -> bool:`
  - `func _do_farming_anim() -> void:`
  - `func _on_slot_selected(_index: int) -> void:`
  - `func _update_animation() -> void:`
  - `func _load_starter_equipment() -> void:`
  - `func _find_farm_manager() -> FarmManager:`
  - `func _update_step_stats(delta: float) -> void:`

## res://scripts/resources/audio/audio_placeholder_library.gd
- Class: `AudioPlaceholderLibrary`
- Extends: `Resource`
- Exported properties:
  - `@export var cues: Dictionary[String, String] = {}`
- Signals: none
- Functions: none

## res://scripts/resources/construction/construction_plan_resource.gd
- Class: `ConstructionPlanResource`
- Extends: `Resource`
- Exported properties:
  - `@export var plan_name: String = "Plan"`
  - `@export var stages: Array[ConstructionStageResource] = []`
- Signals: none
- Functions: none

## res://scripts/resources/construction/construction_requirement_resource.gd
- Class: `ConstructionRequirementResource`
- Extends: `Resource`
- Exported properties:
  - `@export var item_id: String = ""`
  - `@export var amount: int = 1`
- Signals: none
- Functions: none

## res://scripts/resources/construction/construction_stage_resource.gd
- Class: `ConstructionStageResource`
- Extends: `Resource`
- Exported properties:
  - `@export var stage_name: String = "Stage"`
  - `@export var requirements: Array[Resource] = []`
  - `@export var stage_scene: PackedScene = null`
- Signals: none
- Functions: none

## res://scripts/resources/crafting/crafting_ingredient_resource.gd
- Class: `CraftingIngredientResource`
- Extends: `Resource`
- Exported properties:
  - `@export var item_id: String = ""`
  - `@export var count: int = 1`
- Signals: none
- Functions: none

## res://scripts/resources/crafting/crafting_recipe_resource.gd
- Class: `CraftingRecipeResource`
- Extends: `Resource`
- Exported properties:
  - `@export var recipe_id: String = ""`
  - `@export var recipe_name: String = "Recipe"`
  - `@export var ingredients: Array[Resource] = []`
  - `@export var outputs: Array[Resource] = []`
- Signals: none
- Functions: none

## res://scripts/resources/data/placeholder_asset_catalog.gd
- Class: `PlaceholderAssetCatalog`
- Extends: `Resource`
- Exported properties:
  - `@export var sprite_placeholders: Array[String] = []`
  - `@export var animation_placeholders: Array[String] = []`
  - `@export var particle_placeholders: Array[String] = []`
  - `@export var icon_placeholders: Array[String] = []`
  - `@export var ui_placeholders: Array[String] = []`
  - `@export var portrait_placeholders: Array[String] = []`
  - `@export var cutscene_placeholders: Array[String] = []`
- Signals: none
- Functions: none

## res://scripts/trees/logs.gd
- Class: `Log`
- Extends: `RigidBody2D`
- Exported properties: none
- Signals: none
- Functions:
  - `func _ready() -> void:`
  - `func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:`
  - `func attach_to_target(target: Node2D) -> bool:`
  - `func detach() -> void:`
  - `func get_rope_anchor_global() -> Vector2:`

## res://scripts/trees/trunks.gd
- Class: `Trunk`
- Extends: `StaticBody2D`
- Exported properties: none
- Signals: none
- Functions:
  - `func _ready() -> void:`
  - `func hit() -> void:`
  - `func _on_damaged(_amount: int, _remaining: int) -> void:`
  - `func _on_died() -> void:`
  - `func _do_fall_animation() -> void:`
  - `func _do_impact_effect() -> void:`
  - `func _spawn_log() -> void:`
  - `func _manual_fade_out() -> void:`
  - `func _on_fade_complete(_direction: String) -> void:`
  - `func _cleanup_and_free() -> void:`

## res://scripts/ui/action_button_bar.gd
- Class: `ResourceOrbBar`
- Extends: `CanvasLayer`
- Exported properties: none
- Signals: none
- Functions:
  - `func _ready() -> void:`
  - `func _on_mp_pressed() -> void:`
  - `func _on_mp_button_down() -> void:`
  - `func _on_mp_button_up() -> void:`

## res://scripts/ui/hotbar.gd
- Class: `ActionBar`
- Extends: `CanvasLayer`
- Exported properties:
  - `@export_range(2, 16, 1) var slot_count: int = 8`
- Signals:
  - `tool_selected(slot_index: int)`
- Functions:
  - `func _ready() -> void:`
  - `func set_slot_texture(index: int, texture: Texture2D) -> void:`
  - `func clear_slot_texture(index: int) -> void:`
  - `func select_slot(index: int) -> void:`
  - `func _on_slot_pressed(index: int) -> void:`
  - `func get_selected_index() -> int:`

## res://scripts/ui/settings_popup.gd
- Class: `SettingsPopup`
- Extends: `PopupPanel`
- Exported properties: none
- Signals: none
- Functions:
  - `func _ready() -> void:`
  - `func set_target_camera(camera: Camera2D) -> void:`
  - `func _on_zoom_in_pressed() -> void:`
  - `func _on_zoom_out_pressed() -> void:`
  - `func _on_master_changed(value: float) -> void:`
  - `func _on_music_changed(value: float) -> void:`
  - `func _on_sfx_changed(value: float) -> void:`

## res://scripts/ui/virtual_joystick.gd
- Class: `MobileJoystick`
- Extends: `CanvasLayer`
- Exported properties:
  - `@export_group("Geometry")`
  - `@export_range(16.0, 256.0, 1.0) var radius: float = 80.0`
  - `@export_range(8.0, 128.0, 1.0) var knob_size: float = 48.0`
  - `@export_range(16.0, 256.0, 1.0) var base_size: float = 140.0`
  - `@export_group("Behaviour")`
  - `@export_range(0.0, 0.5, 0.01) var dead_zone: float = 0.15`
  - `@export_range(0.0, 0.95, 0.01) var knob_smoothing: float = 0.35`
  - `@export_range(100.0, 2000.0, 10.0) var return_speed: float = 1200.0`
  - `@export_range(0.0, 1.0, 0.01) var fade_duration: float = 0.18`
  - `@export_group("Debug")`
  - `@export var debug_overlay: bool = false`
  - `@export_group("Colours")`
  - `@export var col_base_fill: Color = Color(0.10, 0.10, 0.18, 0.45)`
  - `@export var col_base_ring: Color = Color(0.60, 0.65, 0.85, 0.55)`
  - `@export var col_dead_zone: Color = Color(0.80, 0.85, 1.00, 0.18)`
  - `@export var col_knob_fill: Color = Color(0.94, 0.95, 1.00, 0.92)`
  - `@export var col_knob_outline: Color = Color(1.00, 1.00, 1.00, 0.75)`
  - `@export var col_knob_glow: Color = Color(0.50, 0.70, 1.00, 0.40)`
  - `@export var col_indicator: Color = Color(1.00, 1.00, 1.00, 0.55)`
  - `@export var col_debug: Color = Color(1.00, 1.00, 0.40, 0.95)`
  - `@export var col_shadow: Color = Color(0.00, 0.00, 0.00, 0.30)`
- Signals:
  - `joystick_pressed`
  - `joystick_released`
  - `direction_changed(new_direction: Vector2)`
  - `strength_changed(new_strength: float)`
- Functions:
  - `func _ready() -> void:`
  - `func _process(delta: float) -> void:`
  - `func _exit_tree() -> void:`
  - `func _unhandled_input(event: InputEvent) -> void:`
  - `func _handle_touch(event: InputEventScreenTouch) -> void:`
  - `func _handle_drag(event: InputEventScreenDrag) -> void:`
  - `func _handle_mouse_button(event: InputEventMouseButton) -> void:`
  - `func _handle_mouse_motion(event: InputEventMouseMotion) -> void:`
  - `func _press(pos: Vector2, pointer_index: int, is_touch: bool) -> void:`
  - `func _drag(pos: Vector2) -> void:`
  - `func _release() -> void:`
  - `func reset() -> void:`
  - `func is_active() -> bool:`
  - `func _update_output() -> void:`
  - `func set_inject_actions(enabled: bool) -> void:`
  - `func _release_actions() -> void:`
  - `func _is_touch_index_held(_index: int) -> bool:`
  - `func _on_area_resized() -> void:`
  - `func _on_draw() -> void:`

## res://scripts/world/chunk_manager.gd
- Class: `ChunkManager`
- Extends: `Node`
- Exported properties:
  - `@export var chunk_size: float = 320.0`
  - `@export var render_distance: int = 2`
  - `@export var player_path: NodePath = NodePath("../player")`
  - `@export var pause_processing_when_hidden: bool = true`
- Signals: none
- Functions:
  - `func _ready() -> void:`
  - `func _physics_process(_delta: float) -> void:`
  - `func register_node(node: Node2D) -> void:`
  - `func unregister_node(node: Node2D) -> void:`
  - `func world_to_chunk(world_pos: Vector2) -> Vector2i:`
  - `func get_player_chunk() -> Vector2i:`
  - `func force_update() -> void:`
  - `func _world_to_chunk(pos: Vector2) -> Vector2i:`
  - `func _register_all_grouped_nodes() -> void:`
  - `func _update_chunks() -> void:`

## res://scripts/world/game_stats.gd
- Class: `GameStats`
- Extends: `Node`
- Exported properties: none
- Signals:
  - `stat_changed(stat_key: String, value: int)`
  - `stats_reset()`
- Functions:
  - `func _ready() -> void:`
  - `func reset_stats() -> void:`
  - `func has_stat(stat_key: String) -> bool:`
  - `func ensure_stat(stat_key: String, default_value: int = 0) -> void:`
  - `func increment_stat(stat_key: String, delta: int = 1) -> int:`
  - `func set_stat(stat_key: String, value: int) -> void:`
  - `func get_stat(stat_key: String, default_value: int = 0) -> int:`
  - `func get_all_stats() -> Dictionary:`
  - `func load_from_save(data: Dictionary) -> void:`
  - `func get_save_data() -> Dictionary:`
  - `func format_stat_name(stat_key: String) -> String:`

## res://scripts/world/light_source.gd
- Class: `LightSource`
- Extends: `Node`
- Exported properties:
  - `@export var flame_sprite: AnimatedSprite2D = null`
  - `@export var lit_animation: String = ""`
  - `@export var unlit_animation: String = ""`
  - `@export var base_energy: float = 1.0`
  - `@export var auto_light: bool = true`
- Signals: none
- Functions:
  - `func _ready() -> void:`
  - `func _exit_tree() -> void:`
  - `func set_lit(lit: bool) -> void:`
  - `func is_lit() -> bool:`
  - `func _set_lit(lit: bool) -> void:`
  - `func _find_lights() -> void:`
  - `func _find_lighting_manager() -> LightingManager:`

## res://scripts/world/lighting_manager.gd
- Class: `LightingManager`
- Extends: `Node`
- Exported properties:
  - `@export var player_light: PointLight2D = null`
  - `@export var flicker_speed: float = 6.0`
  - `@export var flicker_strength: float = 0.08`
  - `@export var light_start_phase: TimeManager.TimePhase = TimeManager.TimePhase.SUNSET`
  - `@export_range(0.0, 2.0, 0.01) var night_light_boost: float = 0.25`
  - `@export_range(0.0, 2.0, 0.01) var night_darkness: float = 1.0:`
  - `@export_range(0.0, 5.0, 0.1) var light_energy_multiplier: float = 1.0:`
  - `@export_range(0.0, 5.0, 0.1) var light_scale_multiplier: float = 1.0:`
- Signals:
  - `ambient_color_changed(color: Color)`
- Functions:
  - `func _ready() -> void:`
  - `func _process(delta: float) -> void:`
  - `func _lamps_should_be_on() -> bool:`
  - `func _update_ambient(progress: float) -> void:`
  - `func _on_phase_changed(_phase: TimeManager.TimePhase) -> void:`
  - `func _connect_weather() -> void:`
  - `func _on_rain_intensity_changed(intensity: float) -> void:`
  - `func _refresh_light_sources() -> void:`
  - `func _collect_point_lights(node: Node, out: Array[PointLight2D]) -> void:`
  - `func _update_lights(is_night: bool) -> void:`
  - `func _apply_flicker(is_night: bool) -> void:`
  - `func _apply_size() -> void:`
  - `func register_light_source(node: Node) -> void:`
  - `func unregister_light_source(node: Node) -> void:`
  - `func _on_node_added(node: Node) -> void:`
  - `func _on_node_removed(node: Node) -> void:`
  - `func _refresh_and_apply_lights() -> void:`
  - `func _find_time_manager() -> TimeManager:`

## res://scripts/world/player_house.gd
- Class: `PlayerHouse`
- Extends: `Node2D`
- Exported properties: none
- Signals: none
- Functions:
  - `func _ready() -> void:`
  - `func _on_doorway_body_entered(body: Node2D) -> void:`
  - `func _on_doorway_body_exited(body: Node2D) -> void:`
  - `func _apply_layer_state(player_inside: bool) -> void:`

## res://scripts/world/save_manager.gd
- Class: `SaveManagerSingleton`
- Extends: `Node`
- Exported properties: none
- Signals:
  - `save_completed(success: bool)`
  - `load_completed(success: bool)`
- Functions:
  - `func set_active_slot(slot_index: int) -> void:`
  - `func get_active_slot() -> int:`
  - `func save_game() -> void:`
  - `func load_game() -> void:`
  - `func delete_save(slot_index: int = -1) -> void:`
  - `func has_save(slot_index: int = -1) -> bool:`
  - `func list_existing_slots() -> Array[int]:`
  - `func _ensure_save_dir() -> void:`
  - `func _slot_path(slot_index: int) -> String:`
  - `func _find_farm_manager() -> FarmManager:`
  - `func _find_time_manager() -> TimeManager:`
  - `func _find_player_inventory() -> InventoryComponent:`

## res://scripts/world/time_manager.gd
- Class: `TimeManager`
- Extends: `Node`
- Exported properties:
  - `@export var seconds_per_minute: float = 0.5`
  - `@export var start_hour: int = 6`
  - `@export var start_minute: int = 0`
  - `@export var start_day: int = 1`
  - `@export var start_season: int = 0`
- Signals:
  - `time_tick(hour: int, minute: int, day: int)`
  - `phase_changed(phase: TimePhase)`
  - `sunrise()       # 06:00`
  - `morning()       # 08:00`
  - `midday()        # 12:00`
  - `afternoon()     # 17:00`
  - `sunset()        # 19:00`
  - `nightfall()     # 21:00`
  - `late_night()    # 00:00`
  - `pre_dawn()      # 04:00`
- Functions:
  - `func _ready() -> void:`
  - `func _process(delta: float) -> void:`
  - `func _tick() -> void:`
  - `func _calc_phase() -> TimePhase:`
  - `func get_phase() -> TimePhase:`
  - `func is_night() -> bool:`
  - `func is_day() -> bool:`
  - `func get_day_progress() -> float:`
  - `func get_save_data() -> Dictionary:`
  - `func load_from_save(data: Dictionary) -> void:`

## res://scripts/world/weather_manager.gd
- Class: `(none)`
- Extends: `Node`
- Exported properties: none
- Signals:
  - `weather_changed(active_effects: Array)  # Array of WeatherEffect enums currently on`
  - `wind_changed(strength: float, direction: float)  # direction in radians`
  - `rain_intensity_changed(intensity: float)  # 0..1`
  - `lightning_strike(brightness: float, duration: float)  # a flash just happened`
  - `thunder_triggered(distance: float)  # simulated distance 0=near, 1=far`
  - `state_changed(from_state: int, to_state: int)`
  - `storm_intensity_changed(intensity: float)`
- Functions:
  - `func _ready() -> void:`
  - `func _process(delta: float) -> void:`
  - `func _enter_state(new_state: WeatherState) -> void:`
  - `func _pick_next_state() -> void:`
  - `func _update_wind(delta: float) -> void:`
  - `func _set_wind_target(strength: float) -> void:`
  - `func get_wind_strength() -> float:`
  - `func get_wind_direction() -> float:`
  - `func get_wind_gust() -> float:`
  - `func get_storm_intensity() -> float:`
  - `func _update_rain(delta: float) -> void:`
  - `func _set_rain_target(intensity: float) -> void:`
  - `func get_rain_intensity() -> float:`
  - `func _update_lightning(delta: float) -> void:`
  - `func _fire_lightning() -> void:`
  - `func _update_thunder(delta: float) -> void:`
  - `func _set_effects(effects: Array) -> void:`
  - `func _set_storm_intensity(intensity: float) -> void:`
  - `func has_effect(effect: WeatherEffect) -> bool:`
  - `func _find_controller() -> void:`
  - `func _apply_controller_config() -> void:`
  - `func _find_time_manager() -> void:`
  - `func _debug_print() -> void:`
  - `func force_state(state: WeatherState) -> void:`
  - `func get_weather_label() -> String:`

## res://scripts/world/world_flow.gd
- Class: `WorldFlow`
- Extends: `Node`
- Exported properties:
  - `@export var phase2_cutscene_path: String = "res://scenes/cutscenes/phase2_cutscene_placeholder.tscn"`
- Signals: none
- Functions:
  - `func _ready() -> void:`
  - `func _on_boat_completed(_name: String) -> void:`

## res://tests/test_weather_manager.gd
- Class: `(none)`
- Extends: `Node`
- Exported properties: none
- Signals: none
- Functions:
  - `func _ensure_wm() -> WeatherManager:`
  - `func test_initial_state_is_clear() -> void:`
  - `func test_wind_zero_in_clear() -> void:`
  - `func test_rain_zero_in_clear() -> void:`
  - `func test_storm_activates_all_effects() -> void:`
  - `func test_weather_label_combines_effects() -> void:`
  - `func test_wind_has_nonzero_target_in_storm() -> void:`
  - `func test_rain_has_nonzero_target_in_storm() -> void:`
  - `func test_state_changed_signal_emits() -> void:`
  - `func test_clear_has_no_rain_effect() -> void:`
  - `func test_get_weather_label_returns_string() -> void:`
