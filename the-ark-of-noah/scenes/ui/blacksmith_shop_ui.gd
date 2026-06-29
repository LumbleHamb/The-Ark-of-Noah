extends CanvasLayer

signal shop_ui_opened(shop: BlacksmithShopComponent)
signal shop_ui_closed()

@onready var dimmer: TextureRect = %Dimmer
@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel
@onready var close_button: BaseButton = %CloseButton
@onready var trade_list: VBoxContainer = %TradeList
@onready var status_label: Label = %StatusLabel

var _shop: BlacksmithShopComponent = null
var _player_inventory: InventoryComponent = null

var _slot_texture: Texture2D = preload("res://images/ui/Individual files/ui_images/Item slots/Slot_01_Empty.png")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	dimmer.modulate.a = 0.0
	close_button.pressed.connect(close_ui)

func _process(_delta: float) -> void:
	if visible and Input.is_action_just_pressed("pause"):
		close_ui()

func show_for(shop: BlacksmithShopComponent) -> void:
	if shop == null:
		return
	_shop = shop
	title_label.text = shop.shop_name
	_populate_trades()
	_resolve_player_inventory()
	dimmer.modulate.a = 0.35
	visible = true
	shop_ui_opened.emit(shop)

func _populate_trades() -> void:
	for child: Node in trade_list.get_children():
		child.queue_free()
	if _shop == null or _shop.trades.is_empty():
		var lbl := Label.new()
		lbl.text = "No trades available."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		lbl.add_theme_font_size_override("font_size", 14)
		trade_list.add_child(lbl)
		return
	for trade_res: Resource in _shop.trades:
		var trade: ShopTradeResource = trade_res as ShopTradeResource
		if trade != null:
			_add_trade_row(trade)

func _add_trade_row(trade: ShopTradeResource) -> void:
	var can_afford: bool = _shop.can_afford(trade, _player_inventory) if _shop and _player_inventory else false
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	var costs_box := HBoxContainer.new()
	costs_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	costs_box.size_flags_stretch_ratio = 2.0
	costs_box.alignment = BoxContainer.ALIGNMENT_CENTER
	for cost_res: Resource in trade.costs:
		var cost: ShopCostResource = cost_res as ShopCostResource
		if cost != null:
			costs_box.add_child(_make_cost_display(cost, can_afford))

	var arrow := Label.new()
	arrow.text = " -> "
	arrow.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6, 1) if can_afford else Color(0.5, 0.5, 0.5, 1))
	arrow.add_theme_font_size_override("font_size", 20)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var reward_box := HBoxContainer.new()
	reward_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_box.size_flags_stretch_ratio = 1.5
	reward_box.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_box.add_child(_make_reward_display(trade))

	var btn := Button.new()
	btn.text = "Trade"
	btn.disabled = not can_afford
	btn.custom_minimum_size = Vector2(80, 36)
	btn.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2, 1) if can_afford else Color(0.5, 0.5, 0.5, 1))
	btn.pressed.connect(_on_trade_pressed.bind(trade))

	row.add_child(costs_box)
	row.add_child(arrow)
	row.add_child(reward_box)
	row.add_child(btn)

	var vbox := VBoxContainer.new()
	vbox.add_child(row)
	var sep := HSeparator.new()
	sep.add_theme_color_override("default_color", Color(0.4, 0.35, 0.3, 0.3))
	vbox.add_child(sep)
	trade_list.add_child(vbox)

func _make_cost_display(cost: ShopCostResource, can_afford: bool) -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(48, 48)
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(24, 24)
	tex.expand_mode = 1
	tex.stretch_mode = 5
	tex.texture = _get_item_icon(cost.item_id)
	box.add_child(tex)
	var lbl := Label.new()
	lbl.text = "x%d" % cost.count
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color.WHITE if can_afford else Color(0.6, 0.3, 0.3, 1))
	box.add_child(lbl)
	return box

func _make_reward_display(trade: ShopTradeResource) -> Control:
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(28, 28)
	tex.expand_mode = 1
	tex.stretch_mode = 5
	if trade.rewards_item():
		tex.texture = _get_item_icon(trade.reward_item_id)
	elif trade.rewards_tool():
		var tool: ToolData = trade.reward_tool as ToolData
		if tool and tool.icon:
			tex.texture = tool.icon
	elif trade.rewards_crop():
		var crop: CropData = trade.reward_crop as CropData
		tex.texture = crop.harvest_icon if crop and crop.harvest_icon else (crop.seed_sprite if crop else null)
	box.add_child(tex)
	var lbl := Label.new()
	lbl.text = trade.get_reward_summary()
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8, 1))
	box.add_child(lbl)
	return box

func _on_trade_pressed(trade: ShopTradeResource) -> void:
	if _shop == null or _player_inventory == null:
		return
	if _shop.execute_trade(trade, _player_inventory):
		_populate_trades()
		status_label.text = "Received " + trade.get_reward_summary() + "!"
		status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3, 1))
	else:
		status_label.text = "Cannot complete trade - resources or inventory full."
		status_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))

func _resolve_player_inventory() -> void:
	if get_tree() == null:
		return
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player == null:
		player = get_tree().get_first_node_in_group(&"Player")
	if player:
		for child: Node in player.get_children():
			if child is InventoryComponent:
				_player_inventory = child as InventoryComponent
				return

func _get_item_icon(item_id: String) -> Texture2D:
	var reg: Node = Engine.get_singleton("ItemRegistry")
	if reg and reg.has_method("has_item") and reg.has_method("get_item"):
		if reg.has_item(item_id):
			var def: ItemDefinition = reg.get_item(item_id)
			if def and def.icon:
				return def.icon
	return _slot_texture

func close_ui() -> void:
	if _shop and _shop.is_open():
		_shop.close()
	if _player_inventory != null:
		var owner: Node = _player_inventory.get_parent()
		if owner and owner.has_method(&"set_player_paused"):
			owner.call("set_player_paused", false)
	_shop = null
	dimmer.modulate.a = 0.0
	visible = false
	shop_ui_closed.emit()
