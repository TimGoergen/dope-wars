extends Control

# Root 1080x2400 Zero-Scroll Portrait Dashboard for Dope Wars: Omaha Metro Edition.
# Connects the headless GameState engine to the Sleek Dark OLED "Omaha Street Noir" UI.

var tuning: TuningConfig
var meta: Dictionary
var state: GameState

# Top Bar Controls
var _day_label: Label
var _mute_btn: Button

# Telemetry Labels
var _cash_lbl: Label
var _bank_lbl: Label
var _debt_lbl: Label
var _net_lbl: Label
var _hp_lbl: Label
var _armor_lbl: Label
var _heat_lbl: Label
var _space_lbl: Label
var _arsenal_lbl: Label

# Map & Facility Controls
var _district_btns: Dictionary = {} # district_id -> Button
var _facility_btn: Button
var _finish_run_btn: Button

# Scanner Log Labels
var _log_line_1: Label
var _log_line_2: Label

# Unified 12-Row Trading Board UI references: product_id -> Dictionary of nodes
var _product_rows: Dictionary = {}

# Modal Overlays
var _trade_overlay: TradeOverlay
var _facility_overlay: FacilityOverlay
var _combat_overlay: CombatOverlay
var _encounter_overlay: EncounterOverlay
var _legacy_overlay: LegacyOverlay
var _summary_overlay: RunSummaryOverlay
var _dev_tuning_overlay: DevTuningOverlay


func _ready() -> void:
	tuning = ConfigLoader.load_tuning(true)
	meta = SaveManager.load_save()
	Audio.muted = bool(meta.get("muted", false))
	Haptics.scale = 1.0 if bool(meta.get("haptics_enabled", true)) else 0.0

	state = GameState.new(tuning)
	var saved_run: Dictionary = meta.get("current_run", {})
	if not saved_run.is_empty() and not bool(saved_run.get("game_over", false)) and not bool(saved_run.get("run_completed", false)):
		state.from_dict(saved_run)
	else:
		var pref_days := int(meta.get("preferred_mode_days", tuning.default_run_days))
		var perks: Array = meta.get("active_perks", [])
		state.new_run(pref_days, perks)
		_auto_save()

	_build_dashboard_ui()
	_refresh_all()


func _build_dashboard_ui() -> void:
	var bg := ColorRect.new()
	bg.color = UiPalette.SLATE_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	# 1. TOP HEADER BAR
	_build_top_bar(root_vbox)

	# 2. TELEMETRY & ARSENAL CARD
	_build_telemetry_card(root_vbox)

	# 3. 8-DISTRICT OMAHA METRO MAP & FACILITY BAR
	_build_map_and_facility_card(root_vbox)

	# 4. LIVE METRO SCANNER TICKER
	_build_scanner_card(root_vbox)

	# 5. UNIFIED 12-ROW FIXED-POSITION TRADING BOARD
	_build_unified_trading_board(root_vbox)

	# 6. MODAL OVERLAYS
	_trade_overlay = TradeOverlay.new()
	_trade_overlay.trade_committed.connect(func() -> void:
		_auto_save()
		_refresh_all()
	)
	add_child(_trade_overlay)

	_facility_overlay = FacilityOverlay.new()
	_facility_overlay.facility_action_performed.connect(func() -> void:
		_auto_save()
		_refresh_all()
	)
	add_child(_facility_overlay)

	_combat_overlay = CombatOverlay.new()
	_combat_overlay.combat_updated.connect(func() -> void:
		if state.game_over:
			SaveManager.record_finished_run(meta, state)
			SaveManager.save_data(meta)
			_summary_overlay.open_summary(state, meta, true)
		else:
			_auto_save()
		_refresh_all()
	)
	add_child(_combat_overlay)

	_encounter_overlay = EncounterOverlay.new()
	_encounter_overlay.encounter_resolved.connect(func() -> void:
		_auto_save()
		_refresh_all()
	)
	add_child(_encounter_overlay)

	_legacy_overlay = LegacyOverlay.new()
	_legacy_overlay.meta_updated.connect(func() -> void:
		SaveManager.save_data(meta)
	)
	_legacy_overlay.start_new_run_requested.connect(func(mode_days: int) -> void:
		meta["preferred_mode_days"] = mode_days
		var perks: Array = meta.get("active_perks", [])
		state.new_run(mode_days, perks)
		_auto_save()
		_refresh_all()
	)
	add_child(_legacy_overlay)

	_summary_overlay = RunSummaryOverlay.new()
	_summary_overlay.play_again_requested.connect(func() -> void:
		_legacy_overlay.open_modal(meta)
	)
	add_child(_summary_overlay)

	_dev_tuning_overlay = DevTuningOverlay.new()
	_dev_tuning_overlay.tuning_applied.connect(func() -> void:
		_refresh_all()
	)
	add_child(_dev_tuning_overlay)


func _build_top_bar(parent: VBoxContainer) -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.PANEL_BG, UiPalette.BORDER_SLATE, 12, 2, 16, 10))
	parent.add_child(bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	bar.add_child(hbox)

	var title := UiPalette.add_label(hbox, "DOPE WARS: OMAHA", UiPalette.FONT_HEADER, UiPalette.GOLD_ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_day_label = UiPalette.add_label(hbox, "Day 1/31", UiPalette.FONT_SUBHEAD, UiPalette.TEXT_PRIMARY)

	var atm_btn := Button.new()
	atm_btn.text = "🏧 ATM"
	atm_btn.custom_minimum_size = Vector2(115, 52)
	UiPalette.style_button(atm_btn, UiPalette.BTN_PRIMARY, UiPalette.BANK_CYAN, UiPalette.TEXT_PRIMARY, UiPalette.FONT_SMALL)
	atm_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		_facility_overlay.open_atm(state)
	)
	hbox.add_child(atm_btn)

	var legacy_btn := Button.new()
	legacy_btn.text = "🎖️ New/Perks"
	legacy_btn.custom_minimum_size = Vector2(155, 52)
	UiPalette.style_button(legacy_btn, UiPalette.CARD_BG, UiPalette.GOLD_ACCENT, UiPalette.GOLD_ACCENT, UiPalette.FONT_SMALL)
	legacy_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		_legacy_overlay.open_modal(meta)
	)
	hbox.add_child(legacy_btn)

	var hof_btn := Button.new()
	hof_btn.text = "🏆"
	hof_btn.custom_minimum_size = Vector2(60, 52)
	UiPalette.style_button(hof_btn, UiPalette.CARD_BG, UiPalette.BORDER_SLATE, UiPalette.TEXT_PRIMARY, UiPalette.FONT_SMALL)
	hof_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		_summary_overlay.open_summary(state, meta, false)
	)
	hbox.add_child(hof_btn)

	var tune_btn := Button.new()
	tune_btn.text = "⚙️"
	tune_btn.custom_minimum_size = Vector2(60, 52)
	UiPalette.style_button(tune_btn, UiPalette.CARD_BG, UiPalette.BORDER_SLATE, UiPalette.TEXT_PRIMARY, UiPalette.FONT_SMALL)
	tune_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		_dev_tuning_overlay.open_panel(tuning)
	)
	hbox.add_child(tune_btn)

	_mute_btn = Button.new()
	_mute_btn.text = "🔇" if Audio.muted else "🔊"
	_mute_btn.custom_minimum_size = Vector2(60, 52)
	UiPalette.style_button(_mute_btn, UiPalette.CARD_BG, UiPalette.BORDER_SLATE, UiPalette.TEXT_PRIMARY, UiPalette.FONT_SMALL)
	_mute_btn.pressed.connect(func() -> void:
		Audio.muted = not Audio.muted
		meta["muted"] = Audio.muted
		_mute_btn.text = "🔇" if Audio.muted else "🔊"
		SaveManager.save_data(meta)
	)
	hbox.add_child(_mute_btn)


func _build_telemetry_card(parent: VBoxContainer) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.PANEL_BG, UiPalette.BORDER_SLATE, 12, 2, 16, 10))
	parent.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# Row 1: Cash | Bank | Debt | Net Worth
	var r1 := HBoxContainer.new()
	vbox.add_child(r1)
	_cash_lbl = UiPalette.add_label(r1, "💵 Cash: $2,000", UiPalette.FONT_ROW_MAIN, UiPalette.CASH_EMERALD)
	_cash_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bank_lbl = UiPalette.add_label(r1, "🏦 Bank: $0 (+5%)", UiPalette.FONT_ROW_MAIN, UiPalette.BANK_CYAN)
	_bank_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_debt_lbl = UiPalette.add_label(r1, "🦈 Debt: $5,500", UiPalette.FONT_ROW_MAIN, UiPalette.DEBT_CRIMSON)
	_debt_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_net_lbl = UiPalette.add_label(r1, "💎 Net: -$3,500", UiPalette.FONT_ROW_MAIN, UiPalette.GOLD_ACCENT)
	_net_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Row 2: HP | Armor | Heat & Pursuing Unit
	var r2 := HBoxContainer.new()
	vbox.add_child(r2)
	_hp_lbl = UiPalette.add_label(r2, "❤️ HP: 100/100", UiPalette.FONT_ROW_SUB, UiPalette.CASH_EMERALD)
	_hp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_armor_lbl = UiPalette.add_label(r2, "🛡️ Armor: 0", UiPalette.FONT_ROW_SUB, UiPalette.BANK_CYAN)
	_armor_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heat_lbl = UiPalette.add_label(r2, "🚨 Heat: 0% (OPD Patrol)", UiPalette.FONT_ROW_SUB, UiPalette.SPIKE_AMBER)
	_heat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Row 3: Space & Vehicle | Arsenal & Crew
	var r3 := HBoxContainer.new()
	vbox.add_child(r3)
	_space_lbl = UiPalette.add_label(r3, "🧥 Space: 0 / 100 (ORBT Bus)", UiPalette.FONT_ROW_SUB, UiPalette.TEXT_PRIMARY)
	_space_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_arsenal_lbl = UiPalette.add_label(r3, "🔫 Guns: 0/1 (Unarmed)  |  👥 Crew: 0", UiPalette.FONT_ROW_SUB, UiPalette.GOLD_ACCENT)
	_arsenal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _build_map_and_facility_card(parent: VBoxContainer) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.PANEL_BG, UiPalette.BORDER_SLATE, 12, 2, 14, 10))
	parent.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)

	for d_def in OmahaCatalog.DISTRICTS:
		var did := String(d_def["id"])
		var btn := Button.new()
		btn.text = "%s %s" % [d_def["short_name"], d_def["icon"]]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 62)
		UiPalette.style_button(btn, UiPalette.CARD_BG, UiPalette.BORDER_SLATE, UiPalette.TEXT_PRIMARY, UiPalette.FONT_SMALL)
		btn.pressed.connect(func() -> void:
			_on_district_button_pressed(did)
		)
		grid.add_child(btn)
		_district_btns[did] = btn

	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 10)
	vbox.add_child(act_row)

	_facility_btn = Button.new()
	_facility_btn.text = "🏦 Visit First National Bank & Big Sal's Loans"
	_facility_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_facility_btn.custom_minimum_size = Vector2(0, 64)
	UiPalette.style_button(_facility_btn, UiPalette.BTN_PRIMARY, UiPalette.GOLD_ACCENT, UiPalette.GOLD_ACCENT, UiPalette.FONT_ROW_MAIN)
	_facility_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		Haptics.pulse(20.0)
		_facility_overlay.open_district_facility(state)
	)
	act_row.add_child(_facility_btn)

	_finish_run_btn = Button.new()
	_finish_run_btn.text = "🏁 FINISH RUN & SETTLE"
	_finish_run_btn.custom_minimum_size = Vector2(340, 64)
	_finish_run_btn.visible = false
	UiPalette.style_button(_finish_run_btn, UiPalette.BTN_SUCCESS, UiPalette.CASH_EMERALD, UiPalette.TEXT_PRIMARY, UiPalette.FONT_ROW_MAIN)
	_finish_run_btn.pressed.connect(func() -> void:
		_on_finish_run_pressed()
	)
	act_row.add_child(_finish_run_btn)


func _build_scanner_card(parent: VBoxContainer) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_ALT_BG, UiPalette.BORDER_SLATE, 10, 2, 14, 8))
	parent.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	_log_line_1 = UiPalette.add_label(vbox, "📻 > Welcome to Omaha.", UiPalette.FONT_ROW_SUB, UiPalette.GOLD_ACCENT)
	_log_line_1.clip_text = true
	_log_line_2 = UiPalette.add_label(vbox, "   > Tap any product row for slider or tap Buy Max / Sell.", UiPalette.FONT_SMALL, UiPalette.TEXT_SECONDARY)
	_log_line_2.clip_text = true


func _build_unified_trading_board(parent: VBoxContainer) -> void:
	var board := PanelContainer.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.PANEL_BG, UiPalette.BORDER_SLATE, 12, 2, 12, 10))
	parent.add_child(board)

	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	board.add_child(vbox)

	# Column Header Bar
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	vbox.add_child(hdr)

	var h_prod := UiPalette.add_label(hdr, "PRODUCT", UiPalette.FONT_TINY, UiPalette.TEXT_SECONDARY)
	h_prod.custom_minimum_size = Vector2(215, 0)
	var h_price := UiPalette.add_label(hdr, "MKT PRICE", UiPalette.FONT_TINY, UiPalette.TEXT_SECONDARY)
	h_price.custom_minimum_size = Vector2(165, 0)
	var h_sig := UiPalette.add_label(hdr, "SIGNAL", UiPalette.FONT_TINY, UiPalette.TEXT_SECONDARY)
	h_sig.custom_minimum_size = Vector2(125, 0)
	var h_held := UiPalette.add_label(hdr, "HELD (AVG / LIVE P&L)", UiPalette.FONT_TINY, UiPalette.TEXT_SECONDARY)
	h_held.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h_act := UiPalette.add_label(hdr, "QUICK ACT", UiPalette.FONT_TINY, UiPalette.TEXT_SECONDARY)
	h_act.custom_minimum_size = Vector2(210, 0)
	h_act.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# 12 Fixed-Position Product Rows
	for p_def in OmahaCatalog.PRODUCTS:
		var pid := String(p_def["id"])
		var row_idx := int(p_def["row"])
		var row_bg_col := UiPalette.CARD_BG if (row_idx % 2 == 1) else UiPalette.CARD_ALT_BG

		var row_panel := PanelContainer.new()
		row_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row_panel.add_theme_stylebox_override("panel", UiPalette.make_box(row_bg_col, UiPalette.BORDER_SLATE, 8, 1, 10, 4))
		vbox.add_child(row_panel)

		var row_hbox := HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 8)
		row_panel.add_child(row_hbox)

		# Left/Middle clickable button to open the Trade Slider Modal
		var row_tap_btn := Button.new()
		row_tap_btn.flat = true
		row_tap_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_tap_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row_tap_btn.pressed.connect(func() -> void:
			Audio.play(&"tap")
			_trade_overlay.open_for_product(state, pid)
		)
		row_hbox.add_child(row_tap_btn)

		var info_hbox := HBoxContainer.new()
		info_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		info_hbox.add_theme_constant_override("separation", 8)
		info_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_tap_btn.add_child(info_hbox)

		var name_lbl := UiPalette.add_label(info_hbox, "%d. %s" % [row_idx, p_def["name"]], UiPalette.FONT_ROW_MAIN, UiPalette.TEXT_PRIMARY)
		name_lbl.custom_minimum_size = Vector2(210, 0)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var price_lbl := UiPalette.add_label(info_hbox, "$0", UiPalette.FONT_ROW_MAIN, UiPalette.TEXT_PRIMARY)
		price_lbl.custom_minimum_size = Vector2(165, 0)
		price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var sig_lbl := UiPalette.add_label(info_hbox, "Normal", UiPalette.FONT_SMALL, UiPalette.TEXT_SECONDARY)
		sig_lbl.custom_minimum_size = Vector2(125, 0)
		sig_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var held_lbl := UiPalette.add_label(info_hbox, "—", UiPalette.FONT_SMALL, UiPalette.TEXT_SECONDARY)
		held_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		held_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Right-edge 1-Tap Quick Action Button ([Buy Max] / [Sell Qty] / [Dump Qty])
		var quick_btn := Button.new()
		quick_btn.custom_minimum_size = Vector2(210, 0)
		quick_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		UiPalette.style_button(quick_btn, UiPalette.BTN_PRIMARY, UiPalette.BANK_CYAN, UiPalette.TEXT_PRIMARY, UiPalette.FONT_SMALL, 8)
		quick_btn.pressed.connect(func() -> void:
			_on_quick_action_pressed(pid)
		)
		row_hbox.add_child(quick_btn)

		_product_rows[pid] = {
			"panel": row_panel,
			"base_bg": row_bg_col,
			"name_lbl": name_lbl,
			"price_lbl": price_lbl,
			"sig_lbl": sig_lbl,
			"held_lbl": held_lbl,
			"quick_btn": quick_btn
		}


# --- Dashboard Interactions & State Refresh -----------------------------------------------------

func _on_district_button_pressed(district_id: String) -> void:
	if district_id == state.current_district_id:
		return
	var res := state.drive_to_district(district_id)
	if not bool(res.get("ok", false)):
		return

	if state.game_over:
		Audio.play(&"enforcer_hit")
		Haptics.pulse(60.0)
		SaveManager.record_finished_run(meta, state)
		SaveManager.save_data(meta)
		_refresh_all()
		_summary_overlay.open_summary(state, meta, true)
		return

	if bool(res.get("ambushed", false)):
		Audio.play(&"cop_siren")
		Haptics.pulse(50.0)
	elif not state.active_market_events.is_empty():
		var ev_vals := state.active_market_events.values()
		if ev_vals.has("spike"):
			Audio.play(&"event_spike")
		else:
			Audio.play(&"event_flood")
		Haptics.pulse(28.0)
	else:
		Audio.play(&"drive_engine")
		Haptics.pulse(18.0)

	_auto_save()
	_refresh_all()


func _on_quick_action_pressed(product_id: String) -> void:
	var entry: Dictionary = state.inventory.get(product_id, {"qty": 0, "avg_paid": 0})
	var held := int(entry["qty"])
	var price := int(state.market_prices.get(product_id, 0))

	if held > 0 and price > 0:
		var res := state.sell_all(product_id)
		if bool(res.get("ok", false)):
			var pl := int(res.get("profit", 0))
			Audio.play(&"sell_profit" if pl >= 0 else &"sell_loss")
			Haptics.pulse(30.0)
	elif held > 0 and price <= 0:
		var res := state.dump_product(product_id, held)
		if bool(res.get("ok", false)):
			Audio.play(&"sell_loss")
			Haptics.pulse(22.0)
	elif price > 0:
		var res := state.buy_max(product_id)
		if bool(res.get("ok", false)):
			Audio.play(&"buy")
			Haptics.pulse(24.0)
		else:
			_trade_overlay.open_for_product(state, product_id)
			return

	_auto_save()
	_refresh_all()


func _on_finish_run_pressed() -> void:
	var res := state.finish_run()
	if not bool(res.get("ok", false)):
		return
	if bool(res.get("survived", false)):
		Audio.play(&"victory_fanfare")
	else:
		Audio.play(&"enforcer_hit")
	Haptics.pulse(45.0)
	SaveManager.record_finished_run(meta, state)
	SaveManager.save_data(meta)
	_refresh_all()
	_summary_overlay.open_summary(state, meta, true)


func _refresh_all() -> void:
	# 1. Top Bar
	if state.is_endless:
		_day_label.text = "Day %d (Endless)" % state.day
	else:
		_day_label.text = "Day %d / %d" % [state.day, state.max_days]
	_day_label.add_theme_color_override("font_color", UiPalette.SPIKE_AMBER if state.is_final_day() else UiPalette.TEXT_PRIMARY)

	# 2. Telemetry Strip
	var bank_rate_pct := int(round(state.get_bank_interest_rate() * 100.0))
	var debt_rate_pct := int(round(state.get_loan_interest_rate() * 100.0))
	_cash_lbl.text = "💵 Cash: %s" % Money.format_short(state.cash)
	_bank_lbl.text = "🏦 Bank: %s (+%d%%)" % [Money.format_short(state.bank), bank_rate_pct]
	_debt_lbl.text = "🦈 Debt: %s (+%d%%)" % [Money.format_short(state.debt), debt_rate_pct]
	var nw := state.get_net_worth()
	_net_lbl.text = "💎 Net: %s" % Money.format_short(nw)
	_net_lbl.add_theme_color_override("font_color", UiPalette.CASH_EMERALD if nw >= 0 else UiPalette.DEBT_CRIMSON)

	_hp_lbl.text = "❤️ HP: %d/%d" % [state.health, state.max_health]
	_hp_lbl.add_theme_color_override("font_color", UiPalette.CASH_EMERALD if state.health > 40 else UiPalette.DEBT_CRIMSON)
	_armor_lbl.text = "🛡️ Armor: %d" % state.armor
	var cop_tier := CombatEngine.get_cop_tier_for_heat(state.heat)
	_heat_lbl.text = "🚨 Heat: %.0f%% (%s)" % [state.heat, cop_tier["short_badge"]]
	_heat_lbl.add_theme_color_override("font_color", UiPalette.POLICE_RED if state.heat >= 35.0 else UiPalette.SPIKE_AMBER)

	var v_name: String = OmahaCatalog.get_vehicle(state.vehicle_tier)["short_name"]
	_space_lbl.text = "🧥 Space: %d / %d (%s)" % [state.get_used_capacity(), state.get_max_capacity(), v_name]
	var top_gun := "Unarmed"
	if not state.weapons.is_empty():
		top_gun = String(OmahaCatalog.get_weapon(state.weapons[0])["short_name"])
	_arsenal_lbl.text = "🔫 %d/%d (%s)  |  👥 Crew: %d" % [
		state.weapons.size(), state.get_max_weapon_slots(), top_gun, state.crew_count
	]

	# 3. 8-Button Omaha Metro Map & Local Facility Bar
	for d_def in OmahaCatalog.DISTRICTS:
		var did := String(d_def["id"])
		var btn: Button = _district_btns[did]
		var is_here := (did == state.current_district_id)
		btn.text = ("📍 %s" % d_def["name"]) if is_here else ("%s %s" % [d_def["short_name"], d_def["icon"]])
		btn.disabled = is_here or state.is_final_day()
		if is_here:
			UiPalette.style_button(btn, UiPalette.BTN_PRIMARY, UiPalette.GOLD_ACCENT, UiPalette.GOLD_ACCENT, UiPalette.FONT_SMALL)
		else:
			UiPalette.style_button(btn, UiPalette.CARD_BG, UiPalette.BORDER_SLATE, UiPalette.TEXT_PRIMARY, UiPalette.FONT_SMALL)

	var cur_d := OmahaCatalog.get_district(state.current_district_id)
	_facility_btn.text = "📍 %s:  %s" % [cur_d["name"], cur_d["facility_btn"]]
	_finish_run_btn.visible = state.is_final_day() and not state.run_completed and not state.game_over

	# 4. Scanner Log
	_log_line_1.text = "📻 > " + (state.scanner_log[0] if state.scanner_log.size() > 0 else "Ready.")
	_log_line_2.text = "   > " + (state.scanner_log[1] if state.scanner_log.size() > 1 else "")

	# 5. Unified 12-Row Fixed-Position Trading Board
	for p_def in OmahaCatalog.PRODUCTS:
		var pid := String(p_def["id"])
		var ui: Dictionary = _product_rows[pid]
		var price := int(state.market_prices.get(pid, 0))
		var sig := String(state.market_signals.get(pid, "normal"))
		var entry: Dictionary = state.inventory.get(pid, {"qty": 0, "avg_paid": 0})
		var held := int(entry["qty"])
		var avg_paid := int(entry["avg_paid"])
		var max_buy := state.get_max_buyable(pid)

		var panel: PanelContainer = ui["panel"]
		var name_lbl: Label = ui["name_lbl"]
		var price_lbl: Label = ui["price_lbl"]
		var sig_lbl: Label = ui["sig_lbl"]
		var held_lbl: Label = ui["held_lbl"]
		var quick_btn: Button = ui["quick_btn"]

		# Row highlight for 4x Spikes & 1/4 Floods
		var row_bg: Color = ui["base_bg"]
		var row_border := UiPalette.BORDER_SLATE
		if sig == "spike":
			row_bg = UiPalette.SPIKE_BG
			row_border = UiPalette.SPIKE_AMBER
		elif sig == "flood":
			row_bg = UiPalette.FLOOD_BG
			row_border = UiPalette.FLOOD_CYAN
		elif held > 0:
			row_border = UiPalette.CASH_EMERALD
		panel.add_theme_stylebox_override("panel", UiPalette.make_box(row_bg, row_border, 8, 2 if sig in ["spike", "flood"] or held > 0 else 1, 10, 4))

		if price > 0:
			name_lbl.add_theme_color_override("font_color", UiPalette.TEXT_PRIMARY)
			price_lbl.text = Money.format(price)
			price_lbl.add_theme_color_override("font_color", UiPalette.SPIKE_AMBER if sig == "spike" else (UiPalette.FLOOD_CYAN if sig == "flood" else UiPalette.TEXT_PRIMARY))
		else:
			name_lbl.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
			price_lbl.text = "— (No Mkt)"
			price_lbl.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)

		match sig:
			"spike":
				sig_lbl.text = "🔥 4x!"
				sig_lbl.add_theme_color_override("font_color", UiPalette.SPIKE_AMBER)
			"flood":
				sig_lbl.text = "❄️ 1/4!"
				sig_lbl.add_theme_color_override("font_color", UiPalette.FLOOD_CYAN)
			"high":
				sig_lbl.text = "📈 Pricy"
				sig_lbl.add_theme_color_override("font_color", UiPalette.GOLD_ACCENT)
			"low":
				sig_lbl.text = "🏷️ Cheap"
				sig_lbl.add_theme_color_override("font_color", UiPalette.CASH_EMERALD)
			"unlisted":
				sig_lbl.text = "—"
				sig_lbl.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
			_:
				sig_lbl.text = "Normal"
				sig_lbl.add_theme_color_override("font_color", UiPalette.TEXT_SECONDARY)

		if held > 0:
			if price > 0:
				var pl := held * (price - avg_paid)
				held_lbl.text = "%d (%s | %s)" % [held, Money.format_short(avg_paid), Money.format_pl(pl)]
				held_lbl.add_theme_color_override("font_color", UiPalette.CASH_EMERALD if pl >= 0 else UiPalette.SPIKE_AMBER)
			else:
				held_lbl.text = "%d (Avg %s)" % [held, Money.format_short(avg_paid)]
				held_lbl.add_theme_color_override("font_color", UiPalette.GOLD_ACCENT)
		else:
			held_lbl.text = ("Can Buy: %d" % max_buy) if max_buy > 0 else "—"
			held_lbl.add_theme_color_override("font_color", UiPalette.TEXT_SECONDARY if max_buy > 0 else UiPalette.TEXT_MUTED)

		# Smart Quick Action Button
		if held > 0 and price > 0:
			var pl := held * (price - avg_paid)
			quick_btn.text = "Sell %d" % held
			quick_btn.disabled = false
			UiPalette.style_button(
				quick_btn,
				UiPalette.BTN_SUCCESS if pl >= 0 else UiPalette.BTN_AMBER,
				UiPalette.CASH_EMERALD if pl >= 0 else UiPalette.SPIKE_AMBER,
				UiPalette.TEXT_PRIMARY,
				UiPalette.FONT_SMALL,
				8
			)
		elif held > 0 and price <= 0:
			quick_btn.text = "Dump %d" % held
			quick_btn.disabled = false
			UiPalette.style_button(quick_btn, UiPalette.BTN_DANGER, UiPalette.DEBT_CRIMSON, UiPalette.TEXT_PRIMARY, UiPalette.FONT_SMALL, 8)
		elif price > 0 and max_buy > 0:
			quick_btn.text = "Buy Max (%d)" % max_buy
			quick_btn.disabled = false
			UiPalette.style_button(quick_btn, UiPalette.BTN_PRIMARY, UiPalette.BANK_CYAN, UiPalette.TEXT_PRIMARY, UiPalette.FONT_SMALL, 8)
		else:
			quick_btn.text = "—"
			quick_btn.disabled = true
			UiPalette.style_button(quick_btn, UiPalette.BTN_DISABLED, UiPalette.BORDER_SLATE, UiPalette.TEXT_MUTED, UiPalette.FONT_SMALL, 8)

	# 6. Refresh Active Modals (Combat or Street Encounter)
	_combat_overlay.refresh(state)
	_encounter_overlay.refresh(state)


func _auto_save() -> void:
	meta["current_run"] = state.to_dict()
	SaveManager.save_data(meta)
