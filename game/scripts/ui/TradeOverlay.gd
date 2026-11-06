class_name TradeOverlay
extends ColorRect

# Modal slider overlay when tapping a product row on the Unified 12-Row Trading Board.
# Supports partial/custom Buy, Sell, or Dump (25%, 50%, 75%, Max, or HSlider stepper).

signal trade_committed()

var _state: GameState
var _product_id: String = ""
var _qty_slider: HSlider
var _qty_label: Label
var _preview_label: Label
var _mode: String = "buy" # "buy" | "sell" | "dump"
var _max_qty: int = 0


func _init() -> void:
	color = UiPalette.MODAL_BACKDROP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open_for_product(state: GameState, product_id: String) -> void:
	_state = state
	_product_id = product_id
	for c in get_children():
		c.queue_free()

	var p_def := OmahaCatalog.get_product(product_id)
	var price := int(_state.market_prices.get(product_id, 0))
	var entry: Dictionary = _state.inventory.get(product_id, {"qty": 0, "avg_paid": 0})
	var held := int(entry["qty"])
	var avg_paid := int(entry["avg_paid"])
	var max_buy := _state.get_max_buyable(product_id)

	if held > 0 and price > 0:
		_mode = "sell"
	elif price > 0:
		_mode = "buy"
	elif held > 0:
		_mode = "dump"
	else:
		return

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(940, 0)
	card.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.PANEL_BG, UiPalette.BORDER_BRIGHT, 18, 3, 32, 28))
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	card.add_child(vbox)

	# Title Row
	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := UiPalette.add_label(header, "%s — Street Trade" % p_def["name"], UiPalette.FONT_HEADER, UiPalette.GOLD_ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(64, 56)
	UiPalette.style_button(close_btn, UiPalette.CARD_BG, UiPalette.BORDER_SLATE)
	close_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		visible = false
	)
	header.add_child(close_btn)

	# Market & Stash summary
	var mkt_str := Money.format(price) if price > 0 else "No Local Buyers Today"
	UiPalette.add_label(vbox, "Local Price: %s   |   Held: %d (Avg Paid: %s)   |   Free Space: %d" % [
		mkt_str, held, Money.format(avg_paid) if held > 0 else "—", _state.get_free_capacity()
	], UiPalette.FONT_ROW_SUB, UiPalette.TEXT_SECONDARY)

	# Mode Toggle Buttons (Buy / Sell / Dump)
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 14)
	vbox.add_child(mode_row)

	var buy_tab := Button.new()
	buy_tab.text = "BUY (Max %d)" % max_buy
	buy_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_tab.custom_minimum_size = Vector2(0, 68)
	buy_tab.disabled = (max_buy <= 0)
	UiPalette.style_button(buy_tab, UiPalette.BTN_PRIMARY if _mode == "buy" else UiPalette.CARD_BG, UiPalette.BANK_CYAN if _mode == "buy" else UiPalette.BORDER_SLATE)
	buy_tab.pressed.connect(func() -> void:
		Audio.play(&"tap")
		_switch_mode("buy")
	)
	mode_row.add_child(buy_tab)

	var sell_tab := Button.new()
	sell_tab.text = ("SELL (Held %d)" % held) if price > 0 else ("DUMP (Held %d)" % held)
	sell_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_tab.custom_minimum_size = Vector2(0, 68)
	sell_tab.disabled = (held <= 0)
	var target_sell_mode := "sell" if price > 0 else "dump"
	UiPalette.style_button(sell_tab, UiPalette.BTN_SUCCESS if _mode == target_sell_mode else UiPalette.CARD_BG, UiPalette.CASH_EMERALD if _mode == target_sell_mode else UiPalette.BORDER_SLATE)
	sell_tab.pressed.connect(func() -> void:
		Audio.play(&"tap")
		_switch_mode(target_sell_mode)
	)
	mode_row.add_child(sell_tab)

	# Quantity Readout & Slider
	_qty_label = UiPalette.add_label(vbox, "Quantity: 0", UiPalette.FONT_HEADER, UiPalette.TEXT_PRIMARY)
	_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_qty_slider = HSlider.new()
	_qty_slider.custom_minimum_size = Vector2(0, 56)
	_qty_slider.step = 1
	_qty_slider.value_changed.connect(func(_v: float) -> void:
		_update_preview()
	)
	vbox.add_child(_qty_slider)

	# Preset Percentage Buttons (25%, 50%, 75%, MAX)
	var pct_row := HBoxContainer.new()
	pct_row.add_theme_constant_override("separation", 12)
	vbox.add_child(pct_row)
	for pair in [["1", 0.0], ["25%", 0.25], ["50%", 0.50], ["75%", 0.75], ["MAX", 1.0]]:
		var b := Button.new()
		b.text = String(pair[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 64)
		UiPalette.style_button(b, UiPalette.CARD_BG, UiPalette.BORDER_SLATE)
		var frac := float(pair[1])
		b.pressed.connect(func() -> void:
			Audio.play(&"tap")
			if frac <= 0.01:
				_qty_slider.value = mini(1, _max_qty)
			else:
				_qty_slider.value = maxi(1, int(round(float(_max_qty) * frac)))
			_update_preview()
		)
		pct_row.add_child(b)

	_preview_label = UiPalette.add_label(vbox, "", UiPalette.FONT_SUBHEAD, UiPalette.CASH_EMERALD)
	_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Confirm Button
	var confirm_btn := Button.new()
	confirm_btn.text = "CONFIRM TRADE"
	confirm_btn.custom_minimum_size = Vector2(0, 84)
	UiPalette.style_button(confirm_btn, UiPalette.BTN_SUCCESS, UiPalette.CASH_EMERALD, UiPalette.TEXT_PRIMARY, UiPalette.FONT_HEADER)
	confirm_btn.pressed.connect(func() -> void:
		_commit_trade()
	)
	vbox.add_child(confirm_btn)

	_configure_mode_bounds()
	visible = true


func _switch_mode(new_mode: String) -> void:
	_mode = new_mode
	open_for_product(_state, _product_id)
	_mode = new_mode
	_configure_mode_bounds()


func _configure_mode_bounds() -> void:
	var entry: Dictionary = _state.inventory.get(_product_id, {"qty": 0, "avg_paid": 0})
	var held := int(entry["qty"])
	var max_buy := _state.get_max_buyable(_product_id)

	if _mode == "buy":
		_max_qty = max_buy
	else:
		_max_qty = held

	_qty_slider.min_value = 0
	_qty_slider.max_value = maxi(1, _max_qty)
	_qty_slider.editable = (_max_qty > 0)
	_qty_slider.value = _max_qty
	_update_preview()


func _update_preview() -> void:
	var qty := clampi(int(_qty_slider.value), 0, _max_qty)
	var price := int(_state.market_prices.get(_product_id, 0))
	var entry: Dictionary = _state.inventory.get(_product_id, {"qty": 0, "avg_paid": 0})
	var avg_paid := int(entry["avg_paid"])

	_qty_label.text = "%s Quantity: %d / %d" % [_mode.to_upper(), qty, _max_qty]
	if _mode == "buy":
		var cost := qty * price
		_preview_label.text = "Total Cost: %s  (Cash After: %s)" % [Money.format(cost), Money.format(_state.cash - cost)]
		_preview_label.add_theme_color_override("font_color", UiPalette.BANK_CYAN)
	elif _mode == "sell":
		var rev := qty * price
		var pl := qty * (price - avg_paid)
		_preview_label.text = "Revenue: %s  (Net P/L: %s)" % [Money.format(rev), Money.format_pl(pl)]
		_preview_label.add_theme_color_override("font_color", UiPalette.CASH_EMERALD if pl >= 0 else UiPalette.SPIKE_AMBER)
	else:
		_preview_label.text = "Dump %d units down storm drain ($0 recovery)" % qty
		_preview_label.add_theme_color_override("font_color", UiPalette.DEBT_CRIMSON)


func _commit_trade() -> void:
	var qty := clampi(int(_qty_slider.value), 0, _max_qty)
	if qty <= 0:
		visible = false
		return
	if _mode == "buy":
		var res := _state.buy_product(_product_id, qty)
		if bool(res.get("ok", false)):
			Audio.play(&"buy")
			Haptics.pulse(22.0)
	elif _mode == "sell":
		var res := _state.sell_product(_product_id, qty)
		if bool(res.get("ok", false)):
			var pl := int(res.get("profit", 0))
			Audio.play(&"sell_profit" if pl >= 0 else &"sell_loss")
			Haptics.pulse(30.0)
	else:
		var res := _state.dump_product(_product_id, qty)
		if bool(res.get("ok", false)):
			Audio.play(&"sell_loss")
			Haptics.pulse(20.0)
	visible = false
	trade_committed.emit()
