class_name TradeOverlay
extends Control

# Modal slider overlay when tapping a product row on the Trading Board.
# Includes 3 tabs when a drug is owned: [BUY], [SELL], and [🗑️ DROP].
# Automatically closes on outside clicks, covers the product board without obscuring the hero header,
# and uses generous, readable fonts and button sizing.

signal trade_committed()

var _state: GameState
var _product_id: String = ""
var _qty_slider: HSlider
var _qty_label: Label
var _preview_label: Label
var _confirm_btn: Button
var _mode: String = "buy" # "buy" | "sell" | "dump"
var _max_qty: int = 0
var _board_rect: Rect2 = Rect2()


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	visible = false


func open_for_product(state: GameState, product_id: String, bounds_rect: Rect2 = Rect2()) -> void:
	_state = state
	_product_id = product_id
	_board_rect = bounds_rect

	var price := int(_state.market_prices.get(product_id, 0))
	var entry: Dictionary = _state.inventory.get(product_id, {"qty": 0, "avg_paid": 0})
	var held := int(entry["qty"])

	if held > 0 and price > 0:
		_mode = "sell"
	elif price > 0:
		_mode = "buy"
	elif held > 0:
		_mode = "dump"
	else:
		return

	_rebuild()
	visible = true


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()

	# Full-screen outside-click button to dismiss dialog
	var outside_btn := Button.new()
	outside_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiPalette.style_flat_inert_button(outside_btn)
	outside_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		visible = false
	)
	add_child(outside_btn)

	# Dialog panel positioned over the board area (or centered full width if bounds unset)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.PANEL_BG, UiPalette.TEXT_SECONDARY, 20, 3, 24, 20))
	add_child(panel)

	if _board_rect.size.x > 0.0 and _board_rect.size.y > 0.0:
		panel.position = _board_rect.position
		panel.size = _board_rect.size
		panel.custom_minimum_size = _board_rect.size
	else:
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var p_def := OmahaCatalog.get_product(_product_id)
	var price := int(_state.market_prices.get(_product_id, 0))
	var entry: Dictionary = _state.inventory.get(_product_id, {"qty": 0, "avg_paid": 0})
	var held := int(entry["qty"])
	var avg_paid := int(entry["avg_paid"])
	var max_buy := _state.get_max_buyable(_product_id)

	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 18)
	panel.add_child(main_vbox)

	# 1. Header Row: Big Product Name + Top-right X button
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 12)
	main_vbox.add_child(header)

	var title_lbl := UiPalette.add_label(header, String(p_def["name"]), 52, UiPalette.GOLD_ACCENT, false, true)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var close_btn := Button.new()
	close_btn.text = ""
	close_btn.icon = UiIcons.get_icon("close_x", 48)
	close_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_btn.custom_minimum_size = Vector2(68, 68)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiPalette.style_flat_inert_button(close_btn)
	close_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		visible = false
	)
	header.add_child(close_btn)

	var div := ColorRect.new()
	div.color = UiPalette.BORDER_SLATE
	div.custom_minimum_size = Vector2(0, 3)
	div.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(div)

	# 2. Market & Stash Summary (Large 34px stats)
	var summary_vbox := VBoxContainer.new()
	summary_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_vbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(summary_vbox)

	var mkt_str := Money.format(price) if price > 0 else "No Local Buyers"
	var avg_str := Money.format(avg_paid) if held > 0 else "—"
	UiPalette.add_label(summary_vbox, "Market Price: %s" % mkt_str, 34, UiPalette.TEXT_PRIMARY, true, true)
	UiPalette.add_label(summary_vbox, "Stash Held: %d  •  Avg Paid: %s" % [held, avg_str], 32, UiPalette.BANK_CYAN, true, false)
	UiPalette.add_label(summary_vbox, "Coat Space Free: %d" % _state.get_free_capacity(), 32, UiPalette.TEXT_SECONDARY, true, false)

	# 3. Mode Toggle Buttons: [BUY] | [SELL] | [🗑️ DROP] (Enlarged to 96px height)
	var mode_row := HBoxContainer.new()
	mode_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_row.add_theme_constant_override("separation", 14)
	main_vbox.add_child(mode_row)

	var buy_tab := Button.new()
	buy_tab.text = "BUY (%d)" % max_buy
	buy_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_tab.custom_minimum_size = Vector2(0, 96)
	buy_tab.disabled = (max_buy <= 0)
	UiPalette.style_button(
		buy_tab,
		UiPalette.BTN_PRIMARY if _mode == "buy" else UiPalette.CARD_BG,
		UiPalette.BANK_CYAN if _mode == "buy" else UiPalette.BORDER_SLATE,
		UiPalette.TEXT_PRIMARY,
		UiPalette.FONT_SUBHEAD
	)
	buy_tab.pressed.connect(func() -> void:
		Audio.play(&"tap")
		_mode = "buy"
		_rebuild()
	)
	mode_row.add_child(buy_tab)

	var sell_tab := Button.new()
	sell_tab.text = "SELL (%d)" % held
	sell_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_tab.custom_minimum_size = Vector2(0, 96)
	sell_tab.disabled = (held <= 0) or (price <= 0)
	UiPalette.style_button(
		sell_tab,
		UiPalette.BTN_SUCCESS if _mode == "sell" else UiPalette.CARD_BG,
		UiPalette.CASH_EMERALD if _mode == "sell" else UiPalette.BORDER_SLATE,
		UiPalette.TEXT_PRIMARY,
		UiPalette.FONT_SUBHEAD
	)
	sell_tab.pressed.connect(func() -> void:
		Audio.play(&"tap")
		_mode = "sell"
		_rebuild()
	)
	mode_row.add_child(sell_tab)

	if held > 0:
		var drop_tab := Button.new()
		drop_tab.text = "🗑️ DROP (%d)" % held
		drop_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		drop_tab.custom_minimum_size = Vector2(0, 96)
		UiPalette.style_button(
			drop_tab,
			UiPalette.BTN_DANGER if _mode == "dump" else UiPalette.CARD_BG,
			UiPalette.DEBT_CRIMSON if _mode == "dump" else UiPalette.BORDER_SLATE,
			UiPalette.TEXT_PRIMARY,
			UiPalette.FONT_SUBHEAD
		)
		drop_tab.pressed.connect(func() -> void:
			Audio.play(&"tap")
			_mode = "dump"
			_rebuild()
		)
		mode_row.add_child(drop_tab)

	# 4. Quantity Readout & Chunky Slider (48px quantity title, 84px slider)
	_qty_label = UiPalette.add_label(main_vbox, "Quantity: 0", 48, UiPalette.GOLD_ACCENT)
	_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_qty_slider = HSlider.new()
	_qty_slider.custom_minimum_size = Vector2(0, 84)
	_qty_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_qty_slider.step = 1
	_qty_slider.value_changed.connect(func(_v: float) -> void:
		_update_preview()
	)
	main_vbox.add_child(_qty_slider)

	# 5. Preset Percentage Buttons (1, 25%, 50%, 75%, MAX) (Enlarged to 88px height, 32px font)
	var pct_row := HBoxContainer.new()
	pct_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pct_row.add_theme_constant_override("separation", 12)
	main_vbox.add_child(pct_row)
	for pair in [["1", 0.0], ["25%", 0.25], ["50%", 0.50], ["75%", 0.75], ["MAX", 1.0]]:
		var b := Button.new()
		b.text = String(pair[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 88)
		UiPalette.style_button(b, UiPalette.CARD_BG, UiPalette.BORDER_SLATE, UiPalette.TEXT_PRIMARY, 32)
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

	# 6. Large Preview Label (42px)
	_preview_label = UiPalette.add_label(main_vbox, "", 42, UiPalette.CASH_EMERALD)
	_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 7. Big Confirm Action Button (112px tall, 48px font)
	_confirm_btn = Button.new()
	_confirm_btn.custom_minimum_size = Vector2(0, 112)
	_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_btn.pressed.connect(func() -> void:
		_commit_trade()
	)
	main_vbox.add_child(_confirm_btn)

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

	var mode_title := "DROP" if _mode == "dump" else _mode.to_upper()
	_qty_label.text = "%s: %d / %d" % [mode_title, qty, _max_qty]
	if _mode == "buy":
		var cost := qty * price
		_preview_label.text = "Cost: %s  •  Cash Left: %s" % [Money.format(cost), Money.format(_state.cash - cost)]
		_preview_label.add_theme_color_override("font_color", UiPalette.BANK_CYAN)
		_confirm_btn.text = "✅ BUY %d" % qty
		UiPalette.style_button(_confirm_btn, UiPalette.BTN_PRIMARY, UiPalette.BANK_CYAN, UiPalette.TEXT_PRIMARY, 46)
	elif _mode == "sell":
		var rev := qty * price
		var pl := qty * (price - avg_paid)
		_preview_label.text = "Payout: %s  •  Profit/Loss: %s" % [Money.format(rev), Money.format_pl(pl)]
		_preview_label.add_theme_color_override("font_color", UiPalette.CASH_EMERALD if pl >= 0 else UiPalette.SPIKE_AMBER)
		_confirm_btn.text = "💵 SELL %d" % qty
		UiPalette.style_button(_confirm_btn, UiPalette.BTN_SUCCESS, UiPalette.CASH_EMERALD, UiPalette.TEXT_PRIMARY, 46)
	else:
		_preview_label.text = "Drop %d units down storm drain ($0 recovery • Frees %d Space)" % [qty, qty]
		_preview_label.add_theme_color_override("font_color", UiPalette.DEBT_CRIMSON)
		_confirm_btn.text = "🗑️ DROP %d UNITS" % qty
		UiPalette.style_button(_confirm_btn, UiPalette.BTN_DANGER, UiPalette.DEBT_CRIMSON, UiPalette.TEXT_PRIMARY, 46)
	_confirm_btn.disabled = (qty <= 0)


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
