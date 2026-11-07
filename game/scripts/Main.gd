extends Control

# Root 1080x2400 Portrait Dashboard for Dope Wars: Omaha Metro Edition.
# Uses a high-contrast 3-Tab Bottom Navigation Bar (like American Tycoon) with large, legible controls:
#   Tab 0: MARKET (Filtered 7-11 Active Product Rows with 2-line details + Enhanced Travel popup)
#   Tab 1: SPOT & BANK (Current District Facility + First National Bank / Big Sal inline)
#   Tab 2: KINGPIN (Status, Perks, New Run, Hall of Fame, Sound, Dev Tuning)

var tuning: TuningConfig
var meta: Dictionary
var state: GameState

# Active Tab Index (0 = Market, 1 = Spot & Bank, 2 = Kingpin)
var _current_tab: int = 0
var _tab_containers: Array[Control] = []
var _tab_buttons: Array[Button] = []

# Top Hero Telemetry Controls
var _hero_card: PanelContainer
var _cash_lbl: Label
var _bank_lbl: Label
var _debt_lbl: Label
var _loc_lbl: Label
var _day_lbl: Label
var _space_lbl: Label
var _hp_lbl: Label
var _heat_lbl: Label

# Market Tab Controls
var _travel_btn: Button
var _finish_run_btn: Button
var _scanner_card: PanelContainer
var _log_line_1: Label
var _log_line_2: Label
var _product_rows: Dictionary = {} # product_id -> Dictionary of nodes

# Spot & Bank Tab Dynamic VBox
var _spot_vbox: VBoxContainer

# Kingpin Tab Dynamic VBox
var _kingpin_vbox: VBoxContainer

# Modal Overlays
var _travel_overlay: ColorRect
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
	_show_tab(0)
	_refresh_all()


func _build_dashboard_ui() -> void:
	var bg := ColorRect.new()
	bg.color = UiPalette.SLATE_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(root_vbox)

	# 1. HIGH-CONTRAST 2-ROW HERO HEADER (Always visible)
	_build_hero_header(root_vbox)

	# 2. CENTER TAB CONTENT AREA
	var content_holder := Control.new()
	content_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(content_holder)

	var market_tab := _build_market_tab()
	var spot_tab := _build_spot_tab()
	var kingpin_tab := _build_kingpin_tab()
	_tab_containers = [market_tab, spot_tab, kingpin_tab]
	for t in _tab_containers:
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content_holder.add_child(t)

	# 3. BOTTOM TAB BAR (American Tycoon style)
	_build_bottom_tab_bar(root_vbox)

	# 4. MODAL OVERLAYS
	_travel_overlay = ColorRect.new()
	_travel_overlay.color = UiPalette.MODAL_BACKDROP
	_travel_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_travel_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_travel_overlay.visible = false
	add_child(_travel_overlay)

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
		_refresh_all()
	)
	_legacy_overlay.start_new_run_requested.connect(func(mode_days: int) -> void:
		_start_new_run(mode_days)
	)
	add_child(_legacy_overlay)

	_summary_overlay = RunSummaryOverlay.new()
	_summary_overlay.play_again_requested.connect(func() -> void:
		_show_tab(2)
	)
	add_child(_summary_overlay)

	_dev_tuning_overlay = DevTuningOverlay.new()
	_dev_tuning_overlay.tuning_applied.connect(func() -> void:
		_refresh_all()
	)
	add_child(_dev_tuning_overlay)


func _build_hero_header(parent: VBoxContainer) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 304)
	card.add_theme_stylebox_override("panel", UiPalette.make_hero_header_box())
	parent.add_child(card)
	_hero_card = card

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	# Row 1: Edge-Pinned Left (Cash) and Right (Debt) with a wide empty center gap
	# so nothing ever renders under the Pixel 10 Pro XL's center punch-hole camera cutout.
	var r1 := HBoxContainer.new()
	r1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_theme_constant_override("separation", 16)
	vbox.add_child(r1)

	_cash_lbl = UiPalette.add_hero_label(r1, "💵 $2,000", UiPalette.FONT_HERO_CASH, UiPalette.CASH_EMERALD, HORIZONTAL_ALIGNMENT_LEFT)

	var camera_gap := Control.new()
	camera_gap.custom_minimum_size = Vector2(150, 0)
	camera_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(camera_gap)

	_debt_lbl = UiPalette.add_hero_label(r1, "🦈 $5,500", UiPalette.FONT_HERO_DEBT, UiPalette.DEBT_CRIMSON, HORIZONTAL_ALIGNMENT_RIGHT)

	# Centered Location Row (Below camera cutout): Red pin icon + Full District Name (no numbers)
	_loc_lbl = UiPalette.add_hero_label(vbox, "📍 North Omaha", UiPalette.FONT_HERO, UiPalette.GOLD_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_loc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Row 2: Left (Bank) | Right (Calendar Icon + x/y)
	var r2 := HBoxContainer.new()
	r2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.add_theme_constant_override("separation", 16)
	vbox.add_child(r2)

	_bank_lbl = UiPalette.add_hero_label(r2, "🏦 $0", UiPalette.FONT_HERO, UiPalette.BANK_CYAN, HORIZONTAL_ALIGNMENT_LEFT)
	_bank_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_day_lbl = UiPalette.add_hero_label(r2, "📅 1/31", UiPalette.FONT_HERO_ROW2, UiPalette.GOLD_ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)

	var divider := ColorRect.new()
	divider.color = UiPalette.BORDER_SLATE
	divider.custom_minimum_size = Vector2(0, 3)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(divider)

	# Row 3: Coat Space (Left) | HP (Center) | Heat (Right)
	var r3 := HBoxContainer.new()
	r3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r3.add_theme_constant_override("separation", 16)
	vbox.add_child(r3)

	_space_lbl = UiPalette.add_hero_label(r3, "🧥 0/100", UiPalette.FONT_HERO_ROW3, UiPalette.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_LEFT)
	_space_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_hp_lbl = UiPalette.add_hero_label(r3, "❤️ 100", UiPalette.FONT_HERO_ROW3, UiPalette.CASH_EMERALD, HORIZONTAL_ALIGNMENT_CENTER)
	_hp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_heat_lbl = UiPalette.add_hero_label(r3, "🚨 0%", UiPalette.FONT_HERO_ROW3, UiPalette.SPIKE_AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
	_heat_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _build_market_tab() -> Control:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)

	# Action Row: Prominent Travel Bar (+ Finish Run on Final Day)
	var act_row := HBoxContainer.new()
	act_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_row.add_theme_constant_override("separation", 12)
	vbox.add_child(act_row)

	_travel_btn = Button.new()
	_travel_btn.text = "🚗 TRAVEL — North Omaha 🏦"
	_travel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_travel_btn.custom_minimum_size = Vector2(0, 88)
	UiPalette.style_button(_travel_btn, UiPalette.BTN_PRIMARY, UiPalette.GOLD_ACCENT, UiPalette.GOLD_ACCENT, UiPalette.FONT_SUBHEAD, 14)
	_travel_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		_open_travel_modal()
	)
	act_row.add_child(_travel_btn)

	_finish_run_btn = Button.new()
	_finish_run_btn.text = "🏁 FINISH RUN"
	_finish_run_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_finish_run_btn.custom_minimum_size = Vector2(0, 88)
	_finish_run_btn.visible = false
	UiPalette.style_button(_finish_run_btn, UiPalette.BTN_SUCCESS, UiPalette.CASH_EMERALD, UiPalette.TEXT_PRIMARY, UiPalette.FONT_SUBHEAD, 14)
	_finish_run_btn.pressed.connect(func() -> void:
		_on_finish_run_pressed()
	)
	act_row.add_child(_finish_run_btn)

	# High-Visibility 2-Line Police Scanner & Spike/Flood Alert Banner
	_scanner_card = PanelContainer.new()
	_scanner_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scanner_card.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_BG, UiPalette.BORDER_BRIGHT, 14, 3, 18, 10))
	vbox.add_child(_scanner_card)

	var scan_vbox := VBoxContainer.new()
	scan_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scan_vbox.add_theme_constant_override("separation", 4)
	_scanner_card.add_child(scan_vbox)

	_log_line_1 = UiPalette.add_label(scan_vbox, "📻 Welcome to Omaha.", UiPalette.FONT_ROW_SUB, UiPalette.GOLD_ACCENT, true, true)
	_log_line_2 = UiPalette.add_label(scan_vbox, "", UiPalette.FONT_TINY, UiPalette.TEXT_SECONDARY, true, false)

	# Filtered Active Product Board (Only shows available or held products so rows expand ~35% taller)
	var board := PanelContainer.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.PANEL_BG, UiPalette.BORDER_SLATE, 16, 3, 12, 10))
	vbox.add_child(board)

	var board_vbox := VBoxContainer.new()
	board_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_vbox.add_theme_constant_override("separation", 8)
	board.add_child(board_vbox)

	for p_def in OmahaCatalog.PRODUCTS:
		var pid := String(p_def["id"])
		var row_idx := int(p_def["row"])
		var row_bg_col := UiPalette.CARD_BG if (row_idx % 2 == 1) else UiPalette.CARD_ALT_BG

		var row_panel := PanelContainer.new()
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row_panel.add_theme_stylebox_override("panel", UiPalette.make_box(row_bg_col, UiPalette.BORDER_SLATE, 12, 2, 16, 8))
		board_vbox.add_child(row_panel)

		var row_hbox := HBoxContainer.new()
		row_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row_hbox.add_theme_constant_override("separation", 12)
		row_panel.add_child(row_hbox)

		# Left/Middle clickable area to open the Trade Slider Modal
		var row_tap_btn := Button.new()
		UiPalette.style_flat_inert_button(row_tap_btn)
		row_tap_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_tap_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row_tap_btn.pressed.connect(func() -> void:
			var cur_entry: Dictionary = state.inventory.get(pid, {"qty": 0, "avg_paid": 0})
			if int(cur_entry["qty"]) <= 0 and state.get_max_buyable(pid) <= 0:
				return
			Audio.play(&"tap")
			_trade_overlay.open_for_product(state, pid)
		)
		row_hbox.add_child(row_tap_btn)

		var info_hbox := HBoxContainer.new()
		info_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		info_hbox.add_theme_constant_override("separation", 12)
		info_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_tap_btn.add_child(info_hbox)

		# 2-Line Left Column: Line 1 = Drug Name + Spike/Flood Badge; Line 2 = Held/Avg/P&L or Normal Range
		var left_vbox := VBoxContainer.new()
		left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		left_vbox.add_theme_constant_override("separation", 2)
		left_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_hbox.add_child(left_vbox)

		var name_lbl := UiPalette.add_label(left_vbox, String(p_def["name"]), UiPalette.FONT_DRUG_NAME, UiPalette.TEXT_PRIMARY, false, true)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var sub_lbl := UiPalette.add_label(left_vbox, "", UiPalette.FONT_TINY, UiPalette.TEXT_SECONDARY, false, false)
		sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Big Price Display
		var price_lbl := UiPalette.add_label(info_hbox, "$0", UiPalette.FONT_DRUG_PRICE, UiPalette.TEXT_PRIMARY, false, true)
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Right-edge 1-Tap Quick Action Button ([BUY N] / [SELL] / [DUMP N])
		var quick_btn := Button.new()
		quick_btn.custom_minimum_size = Vector2(296, 0)
		quick_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		UiPalette.style_button(quick_btn, UiPalette.BTN_PRIMARY, UiPalette.BANK_CYAN, UiPalette.TEXT_PRIMARY, UiPalette.FONT_DRUG_BTN, 12)
		quick_btn.pressed.connect(func() -> void:
			_on_quick_action_pressed(pid)
		)
		row_hbox.add_child(quick_btn)

		_product_rows[pid] = {
			"panel": row_panel,
			"base_bg": row_bg_col,
			"row_tap_btn": row_tap_btn,
			"name_lbl": name_lbl,
			"sub_lbl": sub_lbl,
			"price_lbl": price_lbl,
			"quick_btn": quick_btn,
			"min_price": int(tuning.get(String(p_def["min_prop"]))),
			"max_price": int(tuning.get(String(p_def["max_prop"])))
		}

	return vbox


func _build_spot_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_spot_vbox = VBoxContainer.new()
	_spot_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spot_vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(_spot_vbox)
	return scroll


func _build_kingpin_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_kingpin_vbox = VBoxContainer.new()
	_kingpin_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kingpin_vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(_kingpin_vbox)
	return scroll


func _build_bottom_tab_bar(parent: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_constant_override("separation", 12)
	parent.add_child(bar)

	var tab_defs := [
		["💊\nMARKET", 0],
		["🏦 SPOT\n& BANK", 1],
		["👑\nKINGPIN", 2]
	]

	for t_def in tab_defs:
		var btn := Button.new()
		btn.text = String(t_def[0])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 196)
		var idx := int(t_def[1])
		btn.pressed.connect(func() -> void:
			Audio.play(&"tap")
			_show_tab(idx)
		)
		bar.add_child(btn)
		_tab_buttons.append(btn)


func _show_tab(tab_idx: int) -> void:
	_current_tab = clampi(tab_idx, 0, _tab_containers.size() - 1)
	for i in range(_tab_containers.size()):
		_tab_containers[i].visible = (i == _current_tab)
		var btn := _tab_buttons[i]
		UiPalette.style_bottom_tab_button(btn, i == _current_tab, i)

	if _current_tab == 1:
		_rebuild_spot_tab()
	elif _current_tab == 2:
		_rebuild_kingpin_tab()


func _format_product_list_short(ids: Array) -> String:
	var names: Array[String] = []
	for id_val in ids:
		var p := OmahaCatalog.get_product(String(id_val))
		names.append(String(p.get("name", id_val)))
	return ", ".join(names)


func _open_travel_modal() -> void:
	for c in _travel_overlay.get_children():
		c.queue_free()

	var vbox := UiPalette.build_modal_shell(_travel_overlay, "🚗 OMAHA METRO TRANSIT", UiPalette.GOLD_ACCENT, true)

	var cur_d := OmahaCatalog.get_district(state.current_district_id)
	UiPalette.add_label(vbox, "Current Neighborhood: %s %s  •  Tap any destination to drive (advances 1 Day)." % [
		cur_d["icon"], cur_d["name"]
	], UiPalette.FONT_SMALL, UiPalette.TEXT_SECONDARY)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	vbox.add_child(grid)

	for d_def in OmahaCatalog.DISTRICTS:
		var did := String(d_def["id"])
		var is_here := (did == state.current_district_id)
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_bg := UiPalette.BTN_PRIMARY if is_here else UiPalette.CARD_BG
		var card_border := UiPalette.GOLD_ACCENT if is_here else UiPalette.BORDER_BRIGHT
		card.add_theme_stylebox_override("panel", UiPalette.make_box(card_bg, card_border, 16, 3, 16, 14))
		grid.add_child(card)

		var cv := VBoxContainer.new()
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.add_theme_constant_override("separation", 6)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cv)

		var title_str := ("📍 %s (HERE)" % d_def["name"]) if is_here else ("%s %s" % [d_def["icon"], d_def["name"]])
		UiPalette.add_label(cv, title_str, UiPalette.FONT_BUTTON, UiPalette.GOLD_ACCENT if is_here else UiPalette.TEXT_PRIMARY, true, true)

		var spot_str := String(d_def["facility_btn"])
		UiPalette.add_label(cv, spot_str, UiPalette.FONT_TINY, UiPalette.BANK_CYAN, true, false)

		var cheap_ids: Array = d_def.get("cheap_products", [])
		var high_ids: Array = d_def.get("pricy_products", [])
		var cheap_str := _format_product_list_short(cheap_ids) if not cheap_ids.is_empty() else "Standard"
		var high_str := "All +20%" if bool(d_def.get("west_o_pricy", false)) else (_format_product_list_short(high_ids) if not high_ids.is_empty() else "Standard")
		UiPalette.add_label(cv, "🏷️ Cheap: %s" % cheap_str, UiPalette.FONT_TINY, UiPalette.CASH_EMERALD, true, false)
		UiPalette.add_label(cv, "📈 Pricy: %s" % high_str, UiPalette.FONT_TINY, UiPalette.SPIKE_AMBER, true, false)

		var go_btn := Button.new()
		go_btn.text = "📍 CURRENT SPOT" if is_here else "🚗 DRIVE HERE"
		go_btn.custom_minimum_size = Vector2(0, 68)
		go_btn.disabled = is_here or state.is_final_day()
		UiPalette.style_button(
			go_btn,
			UiPalette.BTN_DISABLED if is_here else UiPalette.BTN_SUCCESS,
			UiPalette.GOLD_ACCENT if is_here else UiPalette.CASH_EMERALD,
			UiPalette.GOLD_ACCENT if is_here else UiPalette.TEXT_PRIMARY,
			UiPalette.FONT_SMALL,
			10
		)
		go_btn.pressed.connect(func() -> void:
			_travel_overlay.visible = false
			_on_district_button_pressed(did)
		)
		cv.add_child(go_btn)

	_travel_overlay.visible = true


func _rebuild_spot_tab() -> void:
	for c in _spot_vbox.get_children():
		c.queue_free()

	var cur_d := OmahaCatalog.get_district(state.current_district_id)

	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 12)
	_spot_vbox.add_child(top_row)

	var loc_btn := Button.new()
	loc_btn.text = "🚗 Travel from %s (%s)" % [cur_d["name"], cur_d["icon"]]
	loc_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loc_btn.custom_minimum_size = Vector2(0, 86)
	loc_btn.disabled = state.is_final_day()
	UiPalette.style_button(loc_btn, UiPalette.BTN_PRIMARY, UiPalette.GOLD_ACCENT, UiPalette.GOLD_ACCENT, UiPalette.FONT_SUBHEAD)
	loc_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		_open_travel_modal()
	)
	top_row.add_child(loc_btn)

	FacilityOverlay.build_district_facility_cards(_spot_vbox, state, func() -> void:
		_auto_save()
		_refresh_all()
	)


func _rebuild_kingpin_tab() -> void:
	for c in _kingpin_vbox.get_children():
		c.queue_free()

	var status_card := PanelContainer.new()
	status_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_card.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_BG, UiPalette.BORDER_BRIGHT, 16, 3, 20, 18))
	_kingpin_vbox.add_child(status_card)

	var sv := VBoxContainer.new()
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.add_theme_constant_override("separation", 10)
	status_card.add_child(sv)

	var nw := state.get_net_worth()
	UiPalette.add_label(sv, "💎 Net Worth: %s" % Money.format(nw), UiPalette.FONT_HEADER, UiPalette.CASH_EMERALD if nw >= 0 else UiPalette.DEBT_CRIMSON)

	var v_name: String = OmahaCatalog.get_vehicle(state.vehicle_tier)["name"]
	var top_gun := "Unarmed"
	if not state.weapons.is_empty():
		top_gun = String(OmahaCatalog.get_weapon(state.weapons[0])["name"])
	UiPalette.add_label(sv, "🚗 Ride: %s\n🔫 Guns: %d/%d (%s)  •  👥 Crew: %d\n🛡️ Armor: %d" % [
		v_name, state.weapons.size(), state.get_max_weapon_slots(), top_gun, state.crew_count, state.armor
	], UiPalette.FONT_ROW_SUB, UiPalette.TEXT_PRIMARY)

	var util_row := HBoxContainer.new()
	util_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	util_row.add_theme_constant_override("separation", 12)
	_kingpin_vbox.add_child(util_row)

	var hof_btn := Button.new()
	hof_btn.text = "🏆 Hall of Fame"
	hof_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hof_btn.custom_minimum_size = Vector2(0, 84)
	UiPalette.style_button(hof_btn, UiPalette.CARD_BG, UiPalette.GOLD_ACCENT, UiPalette.GOLD_ACCENT, UiPalette.FONT_SMALL)
	hof_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		_summary_overlay.open_summary(state, meta, false)
	)
	util_row.add_child(hof_btn)

	var tune_btn := Button.new()
	tune_btn.text = "⚙️ Tuning"
	tune_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tune_btn.custom_minimum_size = Vector2(0, 84)
	UiPalette.style_button(tune_btn, UiPalette.CARD_BG, UiPalette.BANK_CYAN, UiPalette.BANK_CYAN, UiPalette.FONT_SMALL)
	tune_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		_dev_tuning_overlay.open_panel(tuning)
	)
	util_row.add_child(tune_btn)

	var mute_btn := Button.new()
	mute_btn.text = "🔇 Muted" if Audio.muted else "🔊 Audio ON"
	mute_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mute_btn.custom_minimum_size = Vector2(0, 84)
	UiPalette.style_button(mute_btn, UiPalette.CARD_BG, UiPalette.BORDER_SLATE, UiPalette.TEXT_PRIMARY, UiPalette.FONT_SMALL)
	mute_btn.pressed.connect(func() -> void:
		Audio.muted = not Audio.muted
		meta["muted"] = Audio.muted
		SaveManager.save_data(meta)
		_rebuild_kingpin_tab()
	)
	util_row.add_child(mute_btn)

	var legacy_card := PanelContainer.new()
	legacy_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legacy_card.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.PANEL_BG, UiPalette.GOLD_ACCENT, 16, 3, 20, 18))
	_kingpin_vbox.add_child(legacy_card)

	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 14)
	legacy_card.add_child(lv)

	LegacyOverlay.build_legacy_section(
		lv,
		meta,
		func() -> void:
			SaveManager.save_data(meta)
			_rebuild_kingpin_tab(),
		func(days_val: int) -> void:
			_start_new_run(days_val)
			_show_tab(0)
	)


func _start_new_run(mode_days: int) -> void:
	meta["preferred_mode_days"] = mode_days
	var perks: Array = meta.get("active_perks", [])
	state.new_run(mode_days, perks)
	_auto_save()
	_refresh_all()


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
	var cur_d := OmahaCatalog.get_district(state.current_district_id)

	# 1. Hero Header
	_cash_lbl.text = "💵 %s" % Money.format_short(state.cash)
	_bank_lbl.text = "🏦 %s" % Money.format_short(state.bank)
	_debt_lbl.text = "🦈 %s" % Money.format_short(state.debt)
	_debt_lbl.add_theme_color_override("font_color", UiPalette.DEBT_CRIMSON if state.debt > 0 else UiPalette.CASH_EMERALD)

	_loc_lbl.text = "📍 %s" % cur_d["name"]

	var day_str := ("📅 %d" % state.day) if state.is_endless else ("📅 %d/%d" % [state.day, state.max_days])
	_day_lbl.text = day_str
	_day_lbl.add_theme_color_override("font_color", UiPalette.SPIKE_AMBER if state.is_final_day() else UiPalette.GOLD_ACCENT)

	_space_lbl.text = "🧥 %d/%d" % [state.get_used_capacity(), state.get_max_capacity()]
	_hp_lbl.text = "❤️ %d" % state.health
	_hp_lbl.add_theme_color_override("font_color", UiPalette.CASH_EMERALD if state.health > 40 else UiPalette.DEBT_CRIMSON)
	_heat_lbl.text = "🚨 %.0f%%" % state.heat
	_heat_lbl.add_theme_color_override("font_color", UiPalette.POLICE_RED if state.heat >= 35.0 else UiPalette.SPIKE_AMBER)

	# 2. Market Tab Travel & High-Contrast Scanner Alert Banner
	_travel_btn.text = "🚗 TRAVEL — %s %s" % [cur_d["name"], cur_d["icon"]]
	_travel_btn.disabled = state.is_final_day()
	_finish_run_btn.visible = state.is_final_day() and not state.run_completed and not state.game_over

	var has_spike := state.active_market_events.values().has("spike")
	var has_flood := state.active_market_events.values().has("flood")
	if has_spike:
		_scanner_card.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.SPIKE_BG, UiPalette.SPIKE_AMBER, 14, 4, 18, 10))
		_log_line_1.add_theme_color_override("font_color", UiPalette.SPIKE_AMBER)
	elif has_flood:
		_scanner_card.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.FLOOD_BG, UiPalette.FLOOD_CYAN, 14, 4, 18, 10))
		_log_line_1.add_theme_color_override("font_color", UiPalette.FLOOD_CYAN)
	else:
		_scanner_card.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_BG, UiPalette.BORDER_BRIGHT, 14, 3, 18, 10))
		_log_line_1.add_theme_color_override("font_color", UiPalette.GOLD_ACCENT)

	_log_line_1.text = "📻 " + (state.scanner_log[0] if state.scanner_log.size() > 0 else "Ready.")
	if state.scanner_log.size() > 1 and not String(state.scanner_log[1]).is_empty():
		_log_line_2.visible = true
		_log_line_2.text = "↳ " + String(state.scanner_log[1])
	else:
		_log_line_2.visible = false

	# 3. Filtered Active Product Board (Only show available or held products so rows expand ~35% taller)
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
		var row_tap_btn: Button = ui["row_tap_btn"]
		var name_lbl: Label = ui["name_lbl"]
		var sub_lbl: Label = ui["sub_lbl"]
		var price_lbl: Label = ui["price_lbl"]
		var quick_btn: Button = ui["quick_btn"]

		# Hide unlisted rows unless the player is carrying that product
		var show_row := (price > 0) or (held > 0)
		panel.visible = show_row
		if not show_row:
			continue

		var can_interact := (held > 0) or (price > 0 and max_buy > 0)
		row_tap_btn.disabled = not can_interact
		row_tap_btn.mouse_filter = Control.MOUSE_FILTER_STOP if can_interact else Control.MOUSE_FILTER_IGNORE
		quick_btn.mouse_filter = Control.MOUSE_FILTER_STOP if can_interact else Control.MOUSE_FILTER_IGNORE

		var row_bg: Color = ui["base_bg"]
		var row_border := UiPalette.BORDER_SLATE
		var bw := 2
		if sig == "spike":
			row_bg = UiPalette.SPIKE_BG
			row_border = UiPalette.SPIKE_AMBER
			bw = 4
		elif sig == "flood":
			row_bg = UiPalette.FLOOD_BG
			row_border = UiPalette.FLOOD_CYAN
			bw = 4
		elif held > 0:
			row_border = UiPalette.CASH_EMERALD
			bw = 3
		panel.add_theme_stylebox_override("panel", UiPalette.make_box(row_bg, row_border, 12, bw, 16, 8))

		# Line 1: Product Name + Event Badge
		var badge := ""
		match sig:
			"spike":
				badge = "  🔥 4× SPIKE!"
			"flood":
				badge = "  ❄️ 1/4 FLOOD!"
			"high":
				badge = "  📈 PRICY"
			"low":
				badge = "  🏷️ CHEAP"
		name_lbl.text = "%s%s" % [p_def["name"], badge]

		# Line 2: Held Qty + Avg Paid + P/L (if owned) OR Normal Price Range (if unowned)
		if held > 0 and price > 0:
			var pl := held * (price - avg_paid)
			sub_lbl.text = "Held: %d  •  Avg %s  •  %s" % [held, Money.format_short(avg_paid), Money.format_pl(pl)]
			sub_lbl.add_theme_color_override("font_color", UiPalette.CASH_EMERALD if pl >= 0 else UiPalette.SPIKE_AMBER)
		elif held > 0 and price <= 0:
			sub_lbl.text = "Held: %d (Avg %s)  •  No Local Buyers" % [held, Money.format_short(avg_paid)]
			sub_lbl.add_theme_color_override("font_color", UiPalette.GOLD_ACCENT)
		else:
			sub_lbl.text = "Norm: %s–%s" % [Money.format_short(int(ui["min_price"])), Money.format_short(int(ui["max_price"]))]
			sub_lbl.add_theme_color_override("font_color", UiPalette.TEXT_SECONDARY)

		# Price Column
		if price > 0:
			name_lbl.add_theme_color_override("font_color", UiPalette.TEXT_PRIMARY)
			price_lbl.text = Money.format(price)
			price_lbl.add_theme_color_override("font_color", UiPalette.SPIKE_AMBER if sig == "spike" else (UiPalette.FLOOD_CYAN if sig == "flood" else (UiPalette.CASH_EMERALD if held > 0 else UiPalette.TEXT_PRIMARY)))
		else:
			name_lbl.add_theme_color_override("font_color", UiPalette.TEXT_SECONDARY)
			price_lbl.text = "No Buyers"
			price_lbl.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)

		# Smart Quick Action Button
		if held > 0 and price > 0:
			var pl := held * (price - avg_paid)
			quick_btn.text = "SELL"
			quick_btn.disabled = false
			UiPalette.style_button(
				quick_btn,
				UiPalette.BTN_SUCCESS if pl >= 0 else UiPalette.BTN_AMBER,
				UiPalette.CASH_EMERALD if pl >= 0 else UiPalette.SPIKE_AMBER,
				UiPalette.TEXT_PRIMARY,
				UiPalette.FONT_SELL_BTN,
				12
			)
		elif held > 0 and price <= 0:
			quick_btn.text = "DUMP %d" % held
			quick_btn.disabled = false
			UiPalette.style_button(quick_btn, UiPalette.BTN_DANGER, UiPalette.DEBT_CRIMSON, UiPalette.TEXT_PRIMARY, UiPalette.FONT_DRUG_BTN, 12)
		elif price > 0 and max_buy > 0:
			quick_btn.text = "BUY %d" % max_buy
			quick_btn.disabled = false
			UiPalette.style_button(quick_btn, UiPalette.BTN_PRIMARY, UiPalette.BANK_CYAN, UiPalette.TEXT_PRIMARY, UiPalette.FONT_DRUG_BTN, 12)
		else:
			quick_btn.text = "Coat Full" if state.get_free_capacity() <= 0 else "Too Pricy"
			quick_btn.disabled = true
			UiPalette.style_button(quick_btn, UiPalette.BTN_DISABLED, UiPalette.BORDER_SLATE, UiPalette.TEXT_MUTED, 36, 12)

	# 4. Update Spot & Kingpin Tabs if visible
	if _current_tab == 1:
		_rebuild_spot_tab()
	elif _current_tab == 2:
		_rebuild_kingpin_tab()

	# 5. Update Tab 1 button label with current neighborhood spot icon
	if _tab_buttons.size() >= 2:
		_tab_buttons[1].text = "%s SPOT\n& BANK" % cur_d["icon"]

	# 6. Refresh Active Modals (Combat or Street Encounter)
	_combat_overlay.refresh(state)
	_encounter_overlay.refresh(state)


func _auto_save() -> void:
	meta["current_run"] = state.to_dict()
	SaveManager.save_data(meta)
