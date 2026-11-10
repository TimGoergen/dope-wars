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
		var target_w := mini(int(_board_rect.size.x), 1040)
		var target_x := clampi(int(_board_rect.position.x), 20, 1080 - target_w - 20)
		panel.position = Vector2(target_x, _board_rect.position.y)
		panel.size = Vector2(target_w, _board_rect.size.y)
		panel.custom_minimum_size = Vector2(target_w, _board_rect.size.y)
	else:
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var p_def := OmahaCatalog.get_product(_product_id)
	var price := int(_state.market_prices.get(_product_id, 0))
	var entry: Dictionary = _state.inventory.get(_product_id, {"qty": 0, "avg_paid": 0})
	var held := int(entry["qty"])
	var avg_paid := int(entry["avg_paid"])
	var max_buy := _state.get_max_buyable(_product_id)

	var min_p := int(_state.tuning.get(String(p_def["min_prop"])))
	var max_p := int(_state.tuning.get(String(p_def["max_prop"])))
	var sig := String(_state.market_signals.get(_product_id, "normal"))
	var tier_info := MarketEngine.calc_price_tier(price, min_p, max_p)
	var a_cnt := int(tier_info["active_count"])
	var t_col: Color = tier_info["color"]
	var t_bg: Color = tier_info["bg"]
	var t_lbl: String = tier_info["label"]

	var tag_text := t_lbl
	var price_color := UiPalette.TEXT_PRIMARY
	if sig == "spike":
		tag_text = "🔥 4× SPIKE!"
		t_col = UiPalette.SPIKE_AMBER
		t_bg = UiPalette.SPIKE_BG
		a_cnt = 5
		price_color = UiPalette.SPIKE_AMBER
	elif sig == "flood":
		tag_text = "❄️ 1/4 FLOOD!"
		t_col = UiPalette.FLOOD_CYAN
		t_bg = UiPalette.FLOOD_BG
		a_cnt = 1
		price_color = UiPalette.FLOOD_CYAN
	elif a_cnt <= 2:
		price_color = UiPalette.CASH_EMERALD
	elif a_cnt >= 4:
		price_color = UiPalette.SPIKE_AMBER

	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 18)
	panel.add_child(main_vbox)

	# 1. Header Row: Large Drug SVG Art Card + Product Name & Category + Close X button
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 18)
	main_vbox.add_child(header)

	var art_card := PanelContainer.new()
	art_card.custom_minimum_size = Vector2(160, 160)
	art_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var card_border: Color = UiPalette.BORDER_BRIGHT
	if sig == "spike":
		card_border = UiPalette.SPIKE_AMBER
	elif sig == "flood":
		card_border = UiPalette.FLOOD_CYAN
	art_card.add_theme_stylebox_override("panel", UiPalette.make_box(Color("#0C131F"), card_border, 16, 2, 8, 8))
	header.add_child(art_card)

	var drug_icon_rect := TextureRect.new()
	drug_icon_rect.texture = UiIcons.get_drug_icon(_product_id, 144)
	drug_icon_rect.custom_minimum_size = Vector2(144, 144)
	drug_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drug_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drug_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_card.add_child(drug_icon_rect)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_vbox.add_theme_constant_override("separation", 4)
	header.add_child(title_vbox)

	var title_lbl := UiPalette.add_label(title_vbox, String(p_def["name"]), 62, UiPalette.GOLD_ACCENT, false, true)
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF

	var cat_str := "Tier %d Contraband" % int(p_def.get("row", 1))
	var cat_lbl := UiPalette.add_label(title_vbox, cat_str, 32, UiPalette.TEXT_MUTED, false, false)
	cat_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF

	var close_btn := Button.new()
	close_btn.text = ""
	close_btn.icon = UiIcons.get_icon("close_x", 62)
	close_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_btn.custom_minimum_size = Vector2(90, 90)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiPalette.style_close_button(close_btn)
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

	# 2. Market & Stash Summary with Price Rating & Dollar Sign Meter
	var summary_vbox := VBoxContainer.new()
	summary_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_vbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(summary_vbox)

	var mkt_str := Money.format(price) if price > 0 else "No Local Buyers"
	var avg_str := Money.format(avg_paid) if held > 0 else "—"

	# Line 1: Market Price (Large 50px stat)
	var mkt_lbl := UiPalette.add_label(summary_vbox, "Market Price: %s" % mkt_str, 50, price_color, false, true)
	mkt_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF

	# Line 2: Dollar Sign Rating Meter ($$$$$) + Companion Price Tag Pill
	var rating_row := HBoxContainer.new()
	rating_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rating_row.add_theme_constant_override("separation", 12)
	summary_vbox.add_child(rating_row)

	var r_title := Label.new()
	r_title.text = "Price Rating:"
	r_title.add_theme_font_override("font", UiPalette.make_bold_font())
	r_title.add_theme_font_size_override("font_size", 40)
	r_title.add_theme_color_override("font_color", UiPalette.TEXT_SECONDARY)
	r_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rating_row.add_child(r_title)

	if price > 0:
		var meter_hbox := HBoxContainer.new()
		meter_hbox.add_theme_constant_override("separation", 0)
		meter_hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rating_row.add_child(meter_hbox)

		var active_dollars := Label.new()
		active_dollars.text = "$".repeat(a_cnt)
		active_dollars.add_theme_font_override("font", UiPalette.make_bold_font())
		active_dollars.add_theme_font_size_override("font_size", 42)
		active_dollars.add_theme_color_override("font_color", t_col)
		active_dollars.add_theme_constant_override("shadow_offset_x", 0)
		active_dollars.add_theme_constant_override("shadow_offset_y", 0)
		active_dollars.add_theme_constant_override("shadow_outline_size", 6)
		active_dollars.add_theme_color_override("font_shadow_color", Color(t_col.r, t_col.g, t_col.b, 0.40))
		meter_hbox.add_child(active_dollars)

		var inactive_dollars := Label.new()
		inactive_dollars.text = "$".repeat(maxi(0, 5 - a_cnt))
		inactive_dollars.add_theme_font_override("font", UiPalette.make_bold_font())
		inactive_dollars.add_theme_font_size_override("font_size", 42)
		inactive_dollars.add_theme_color_override("font_color", Color(0.24, 0.30, 0.42, 0.45))
		meter_hbox.add_child(inactive_dollars)

		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", UiPalette.make_box(t_bg, t_col, 8, 2, 12, 4))
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rating_row.add_child(pill)

		var tag_lbl := Label.new()
		tag_lbl.text = tag_text
		tag_lbl.add_theme_font_override("font", UiPalette.make_bold_font())
		tag_lbl.add_theme_font_size_override("font_size", 32)
		tag_lbl.add_theme_color_override("font_color", t_col)
		pill.add_child(tag_lbl)
	else:
		var no_buy_lbl := Label.new()
		no_buy_lbl.text = "NO LOCAL BUYERS"
		no_buy_lbl.add_theme_font_override("font", UiPalette.make_bold_font())
		no_buy_lbl.add_theme_font_size_override("font_size", 36)
		no_buy_lbl.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
		no_buy_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rating_row.add_child(no_buy_lbl)

	# Line 3: Normal Market Range context
	var norm_lbl := UiPalette.add_label(summary_vbox, "Normal Market Range: %s – %s" % [Money.format(min_p), Money.format(max_p)], 38, UiPalette.TEXT_MUTED, false, false)
	norm_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF

	# Line 4: Stash Held + Avg Paid (Large 44px stat)
	var stash_lbl := UiPalette.add_label(summary_vbox, "Stash Held: %d  •  Avg Paid: %s" % [held, avg_str], 44, UiPalette.BANK_CYAN, false, false)
	stash_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF

	# Line 5: Coat Space Free (Large 44px stat)
	var coat_lbl := UiPalette.add_label(summary_vbox, "Coat Free Space: %d" % _state.get_free_capacity(), 44, UiPalette.TEXT_SECONDARY, false, false)
	coat_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF

	# 3. Mode Toggle Buttons: [BUY] | [SELL] | [🗑️ DROP]
	var mode_row := HBoxContainer.new()
	mode_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_row.add_theme_constant_override("separation", 14)
	main_vbox.add_child(mode_row)

	var buy_tab := Button.new()
	buy_tab.text = "BUY (%d)" % max_buy
	buy_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_tab.custom_minimum_size = Vector2(0, 104)
	buy_tab.clip_text = true
	buy_tab.disabled = (max_buy <= 0)
	UiPalette.style_button(
		buy_tab,
		UiPalette.BTN_PRIMARY if _mode == "buy" else UiPalette.CARD_BG,
		UiPalette.BANK_CYAN if _mode == "buy" else UiPalette.BORDER_SLATE,
		UiPalette.TEXT_PRIMARY,
		42
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
	sell_tab.custom_minimum_size = Vector2(0, 104)
	sell_tab.clip_text = true
	sell_tab.disabled = (held <= 0) or (price <= 0)
	UiPalette.style_button(
		sell_tab,
		UiPalette.BTN_SUCCESS if _mode == "sell" else UiPalette.CARD_BG,
		UiPalette.CASH_EMERALD if _mode == "sell" else UiPalette.BORDER_SLATE,
		UiPalette.TEXT_PRIMARY,
		42
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
		drop_tab.custom_minimum_size = Vector2(0, 104)
		drop_tab.clip_text = true
		UiPalette.style_button(
			drop_tab,
			UiPalette.BTN_DANGER if _mode == "dump" else UiPalette.CARD_BG,
			UiPalette.DEBT_CRIMSON if _mode == "dump" else UiPalette.BORDER_SLATE,
			UiPalette.TEXT_PRIMARY,
			42
		)
		drop_tab.pressed.connect(func() -> void:
			Audio.play(&"tap")
			_mode = "dump"
			_rebuild()
		)
		mode_row.add_child(drop_tab)

	# 4. Quantity Readout & Chunky Slider (58px quantity title, tactile grabber)
	_qty_label = UiPalette.add_label(main_vbox, "Quantity: 0", 58, UiPalette.GOLD_ACCENT, false, true)
	_qty_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_qty_slider = HSlider.new()
	_qty_slider.custom_minimum_size = Vector2(0, 60)
	_qty_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_qty_slider.step = 1
	UiPalette.style_slider(_qty_slider)
	_qty_slider.value_changed.connect(func(_v: float) -> void:
		_update_preview()
	)
	main_vbox.add_child(_qty_slider)

	# 5. Large Preview Label (50px)
	_preview_label = UiPalette.add_label(main_vbox, "", 50, UiPalette.CASH_EMERALD)
	_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# 6. Big Confirm Action Button (116px tall, 56px font)
	_confirm_btn = Button.new()
	_confirm_btn.custom_minimum_size = Vector2(0, 116)
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
		UiPalette.style_button(_confirm_btn, UiPalette.BTN_PRIMARY, UiPalette.BANK_CYAN, UiPalette.TEXT_PRIMARY, 56)
	elif _mode == "sell":
		var rev := qty * price
		var pl := qty * (price - avg_paid)
		_preview_label.text = "Payout: %s  •  Profit/Loss: %s" % [Money.format(rev), Money.format_pl(pl)]
		_preview_label.add_theme_color_override("font_color", UiPalette.CASH_EMERALD if pl >= 0 else UiPalette.SPIKE_AMBER)
		_confirm_btn.text = "💵 SELL %d" % qty
		UiPalette.style_button(_confirm_btn, UiPalette.BTN_SUCCESS, UiPalette.CASH_EMERALD, UiPalette.TEXT_PRIMARY, 56)
	else:
		_preview_label.text = "Drop %d units down storm drain ($0 recovery • Frees %d Space)" % [qty, qty]
		_preview_label.add_theme_color_override("font_color", UiPalette.DEBT_CRIMSON)
		_confirm_btn.text = "🗑️ DROP %d UNITS" % qty
		UiPalette.style_button(_confirm_btn, UiPalette.BTN_DANGER, UiPalette.DEBT_CRIMSON, UiPalette.TEXT_PRIMARY, 56)
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
