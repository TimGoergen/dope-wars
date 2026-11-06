class_name FacilityOverlay
extends ColorRect

# Contextual modal for the Universal Street ATM and all 8 Omaha Metro district signature facilities.

signal facility_action_performed()

var _state: GameState
var _mode: String = "district" # "district" | "atm"


func _init() -> void:
	color = UiPalette.MODAL_BACKDROP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func open_atm(state: GameState) -> void:
	_state = state
	_mode = "atm"
	_rebuild()
	visible = true


func open_district_facility(state: GameState) -> void:
	_state = state
	_mode = "district"
	_rebuild()
	visible = true


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(960, 0)
	card.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.PANEL_BG, UiPalette.BORDER_BRIGHT, 18, 3, 30, 26))
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	card.add_child(vbox)

	var d_def := OmahaCatalog.get_district(_state.current_district_id)
	var header_title := "🏧 Street ATM & Remote Banking" if _mode == "atm" else ("%s %s" % [d_def["icon"], d_def["facility_name"]])

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title_lbl := UiPalette.add_label(header, header_title, UiPalette.FONT_HEADER, UiPalette.GOLD_ACCENT)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(64, 54)
	UiPalette.style_button(close_btn, UiPalette.CARD_BG, UiPalette.BORDER_SLATE)
	close_btn.pressed.connect(func() -> void:
		Audio.play(&"tap")
		visible = false
	)
	header.add_child(close_btn)

	# Top financial summary bar inside facility
	UiPalette.add_label(vbox, "💵 Cash: %s   |   🏦 Bank: %s   |   🦈 Debt: %s   |   🚨 Heat: %.0f%%" % [
		Money.format(_state.cash),
		Money.format(_state.bank),
		Money.format(_state.debt),
		_state.heat
	], UiPalette.FONT_ROW_SUB, UiPalette.TEXT_SECONDARY)

	if _mode == "atm":
		_build_banking_section(vbox)
		return

	var fac_id := String(d_def["facility_id"])
	match fac_id:
		"bank_and_loans":
			_build_banking_section(vbox)
			_build_loan_shark_section(vbox)
		"pawn_gun":
			_build_pawn_gun_section(vbox)
		"clinic":
			_build_clinic_section(vbox)
		"lounge":
			_build_lounge_section(vbox)
		"casino":
			_build_casino_section(vbox)
		"lawyer":
			_build_lawyer_section(vbox)
		"vip_booth":
			_build_vip_booth_section(vbox)
		"chop_shop":
			_build_chop_shop_section(vbox)


func _build_banking_section(vbox: VBoxContainer) -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_BG, UiPalette.BORDER_SLATE, 12, 2, 18, 14))
	vbox.add_child(box)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	box.add_child(inner)

	var fee_pct := int(round(_state.get_street_atm_fee_rate() * 100.0))
	var int_pct := int(round(_state.get_bank_interest_rate() * 100.0))
	UiPalette.add_label(inner, "🏦 First National Bank (+%d%%/day Compound Interest | Deposit Fee Here: %d%%)" % [int_pct, fee_pct], UiPalette.FONT_SUBHEAD, UiPalette.BANK_CYAN)

	var dep_row := HBoxContainer.new()
	dep_row.add_theme_constant_override("separation", 10)
	inner.add_child(dep_row)
	for pair in [["Deposit 25%", 0.25], ["Deposit 50%", 0.50], ["Deposit 100%", 1.0]]:
		var b := Button.new()
		b.text = String(pair[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 62)
		b.disabled = (_state.cash <= 0)
		UiPalette.style_button(b, UiPalette.BTN_PRIMARY, UiPalette.BANK_CYAN)
		var frac := float(pair[1])
		b.pressed.connect(func() -> void:
			var amt := maxi(1, int(round(float(_state.cash) * frac)))
			_state.deposit_bank(amt)
			Audio.play(&"cash_register")
			Haptics.pulse(20.0)
			facility_action_performed.emit()
			_rebuild()
		)
		dep_row.add_child(b)

	var can_wd := _state.can_withdraw_bank()
	var wd_row := HBoxContainer.new()
	wd_row.add_theme_constant_override("separation", 10)
	inner.add_child(wd_row)
	for pair in [["Withdraw 25%", 0.25], ["Withdraw 50%", 0.50], ["Withdraw 100%", 1.0]]:
		var b := Button.new()
		b.text = String(pair[0]) if can_wd else "Withdraw (North O Only)"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 62)
		b.disabled = (not can_wd) or (_state.bank <= 0)
		UiPalette.style_button(b, UiPalette.CARD_ALT_BG, UiPalette.BORDER_BRIGHT)
		var frac := float(pair[1])
		b.pressed.connect(func() -> void:
			var amt := maxi(1, int(round(float(_state.bank) * frac)))
			_state.withdraw_bank(amt)
			Audio.play(&"cash_register")
			Haptics.pulse(20.0)
			facility_action_performed.emit()
			_rebuild()
		)
		wd_row.add_child(b)


func _build_loan_shark_section(vbox: VBoxContainer) -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_BG, UiPalette.BORDER_SLATE, 12, 2, 18, 14))
	vbox.add_child(box)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	box.add_child(inner)

	var rate_pct := int(round(_state.get_loan_interest_rate() * 100.0))
	var credit_avail := _state.get_max_credit_line()
	UiPalette.add_label(inner, "🦈 Big Sal's Loans (+%d%%/day Interest | Unpaid Days: %d/7 | Credit Avail: %s)" % [
		rate_pct, _state.days_since_loan_payment, Money.format_short(credit_avail)
	], UiPalette.FONT_SUBHEAD, UiPalette.DEBT_CRIMSON)

	var pay_row := HBoxContainer.new()
	pay_row.add_theme_constant_override("separation", 10)
	inner.add_child(pay_row)
	var max_pay := mini(_state.cash, _state.debt)
	for pair in [["Pay 10% Min", 0.10], ["Pay 50%", 0.50], ["Pay Off All (%s)" % Money.format_short(max_pay), 1.0]]:
		var b := Button.new()
		b.text = String(pair[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 62)
		b.disabled = (max_pay <= 0)
		UiPalette.style_button(b, UiPalette.BTN_SUCCESS, UiPalette.CASH_EMERALD)
		var frac := float(pair[1])
		b.pressed.connect(func() -> void:
			var target := int(ceil(float(_state.debt) * frac)) if frac < 0.99 else max_pay
			_state.pay_loan(mini(_state.cash, target))
			Audio.play(&"cash_register")
			Haptics.pulse(25.0)
			facility_action_performed.emit()
			_rebuild()
		)
		pay_row.add_child(b)

	var borrow_row := HBoxContainer.new()
	borrow_row.add_theme_constant_override("separation", 10)
	inner.add_child(borrow_row)
	for amt in [10000, 25000, credit_avail]:
		var b := Button.new()
		var val := int(amt)
		b.text = ("Borrow %s" % Money.format_short(val)) if _state.initial_debt_cleared else "Pay $5.5K Debt to Unlock Credit"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 62)
		b.disabled = (not _state.initial_debt_cleared) or (val <= 0) or (val > credit_avail)
		UiPalette.style_button(b, UiPalette.BTN_AMBER, UiPalette.SPIKE_AMBER)
		b.pressed.connect(func() -> void:
			_state.borrow_loan(val)
			Audio.play(&"cash_register")
			Haptics.pulse(25.0)
			facility_action_performed.emit()
			_rebuild()
		)
		borrow_row.add_child(b)


func _build_pawn_gun_section(vbox: VBoxContainer) -> void:
	UiPalette.add_label(vbox, "🔫 Weapon Slots: %d / %d (Strongest gun equipped by you; rest arm Crew; 50%% trade-in when full)" % [
		_state.weapons.size(), _state.get_max_weapon_slots()
	], UiPalette.FONT_ROW_SUB, UiPalette.GOLD_ACCENT)

	for w_def in OmahaCatalog.WEAPONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		vbox.add_child(row)

		var wid := String(w_def["id"])
		var price := int(w_def["price"])
		var trade_in := 0
		if _state.weapons.size() >= _state.get_max_weapon_slots() and not _state.weapons.is_empty():
			var weakest := OmahaCatalog.get_weapon(_state.weapons.back())
			if int(w_def["damage"]) > int(weakest["damage"]):
				trade_in = int(round(float(weakest["price"]) * _state.tuning.weapon_trade_in_pct))
		var net_price := maxi(0, price - trade_in)

		var info := UiPalette.add_label(row, "%s  —  %d Dmg (%d%% Hit)" % [
			w_def["name"], int(w_def["damage"]), int(round(float(w_def["hit_chance"]) * 100.0))
		], UiPalette.FONT_ROW_MAIN, UiPalette.TEXT_PRIMARY)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(260, 58)
		var slots_full := (_state.weapons.size() >= _state.get_max_weapon_slots())
		var can_upgrade := (not slots_full) or (trade_in > 0)
		btn.text = ("Buy %s" % Money.format(price)) if trade_in == 0 else ("Upgrade %s" % Money.format(net_price))
		btn.disabled = (not can_upgrade) or (_state.cash < net_price)
		UiPalette.style_button(btn, UiPalette.BTN_PRIMARY, UiPalette.BANK_CYAN)
		btn.pressed.connect(func() -> void:
			var res := _state.buy_weapon(wid)
			if bool(res.get("ok", false)):
				Audio.play(&"cash_register")
				Haptics.pulse(25.0)
				facility_action_performed.emit()
				_rebuild()
		)
		row.add_child(btn)

	# Body Armor Row
	var armor_row := HBoxContainer.new()
	armor_row.add_theme_constant_override("separation", 12)
	vbox.add_child(armor_row)

	var vest_btn := Button.new()
	vest_btn.text = "🛡️ Kevlar Vest (+50 Arm) — %s" % Money.format(_state.tuning.armor_vest_price)
	vest_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vest_btn.custom_minimum_size = Vector2(0, 68)
	vest_btn.disabled = (_state.armor >= 50) or (_state.cash < _state.tuning.armor_vest_price)
	UiPalette.style_button(vest_btn, UiPalette.BTN_SUCCESS, UiPalette.CASH_EMERALD)
	vest_btn.pressed.connect(func() -> void:
		_state.buy_armor(false)
		Audio.play(&"cash_register")
		facility_action_performed.emit()
		_rebuild()
	)
	armor_row.add_child(vest_btn)

	var plate_btn := Button.new()
	plate_btn.text = "🛡️ Plate Carrier (100 Arm) — %s" % Money.format(_state.tuning.armor_plate_price)
	plate_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plate_btn.custom_minimum_size = Vector2(0, 68)
	plate_btn.disabled = (_state.armor >= 100) or (_state.cash < _state.tuning.armor_plate_price)
	UiPalette.style_button(plate_btn, UiPalette.BTN_SUCCESS, UiPalette.CASH_EMERALD)
	plate_btn.pressed.connect(func() -> void:
		_state.buy_armor(true)
		Audio.play(&"cash_register")
		facility_action_performed.emit()
		_rebuild()
	)
	armor_row.add_child(plate_btn)


func _build_clinic_section(vbox: VBoxContainer) -> void:
	var cost_per_hp := _state.get_heal_cost_per_hp()
	var missing := maxi(0, _state.max_health - _state.health)
	var full_cost := missing * cost_per_hp

	UiPalette.add_label(vbox, "❤️ Current Health: %d / %d   |   Treatment Rate: %s / HP" % [
		_state.health, _state.max_health, Money.format(cost_per_hp)
	], UiPalette.FONT_SUBHEAD, UiPalette.CASH_EMERALD)

	var heal_btn := Button.new()
	heal_btn.text = ("💉 1-TAP FULL HEAL (+%d HP for %s)" % [missing, Money.format(mini(_state.cash, full_cost))]) if missing > 0 else "❤️ Already at Full Health"
	heal_btn.custom_minimum_size = Vector2(0, 78)
	heal_btn.disabled = (missing <= 0) or (_state.cash < cost_per_hp)
	UiPalette.style_button(heal_btn, UiPalette.BTN_SUCCESS, UiPalette.CASH_EMERALD, UiPalette.TEXT_PRIMARY, UiPalette.FONT_SUBHEAD)
	heal_btn.pressed.connect(func() -> void:
		_state.heal_player(missing)
		Audio.play(&"buy")
		Haptics.pulse(25.0)
		facility_action_performed.emit()
		_rebuild()
	)
	vbox.add_child(heal_btn)

	var kidney_btn := Button.new()
	kidney_btn.text = ("🔪 SELL A KIDNEY (+%s Emergency Cash | Caps Max HP at 80)" % Money.format(_state.tuning.kidney_sale_payout)) if not _state.kidney_sold else "🔪 Kidney Already Sold (Max HP 80)"
	kidney_btn.custom_minimum_size = Vector2(0, 74)
	kidney_btn.disabled = _state.kidney_sold
	UiPalette.style_button(kidney_btn, UiPalette.BTN_DANGER, UiPalette.DEBT_CRIMSON)
	kidney_btn.pressed.connect(func() -> void:
		_state.sell_kidney()
		Audio.play(&"enforcer_hit")
		Haptics.pulse(40.0)
		facility_action_performed.emit()
		_rebuild()
	)
	vbox.add_child(kidney_btn)


func _build_lounge_section(vbox: VBoxContainer) -> void:
	var cost := _state.get_next_crew_cost()
	UiPalette.add_label(vbox, "👥 Active Crew: %d / %d Runners\nEach Runner adds +10 Carry Space, +1 Weapon Slot, fires in shootouts, and has 30 HP (50/50 shared target pool; auto-heals after surviving combat)." % [
		_state.crew_count, _state.tuning.crew_max_count
	], UiPalette.FONT_ROW_MAIN, UiPalette.TEXT_PRIMARY)

	var hire_btn := Button.new()
	hire_btn.text = ("🍸 HIRE RUNNER #%d (%s)" % [_state.crew_count + 1, Money.format(cost)]) if _state.crew_count < _state.tuning.crew_max_count else "👥 Crew Roster Full (10/10)"
	hire_btn.custom_minimum_size = Vector2(0, 82)
	hire_btn.disabled = (_state.crew_count >= _state.tuning.crew_max_count) or (_state.cash < cost)
	UiPalette.style_button(hire_btn, UiPalette.BTN_PRIMARY, UiPalette.GOLD_ACCENT, UiPalette.TEXT_PRIMARY, UiPalette.FONT_HEADER)
	hire_btn.pressed.connect(func() -> void:
		_state.hire_crew()
		Audio.play(&"cash_register")
		Haptics.pulse(25.0)
		facility_action_performed.emit()
		_rebuild()
	)
	vbox.add_child(hire_btn)


func _build_casino_section(vbox: VBoxContainer) -> void:
	UiPalette.add_label(vbox, "🃏 High-Card Double-or-Nothing (50% Chance — Once per Visit)", UiPalette.FONT_SUBHEAD, UiPalette.GOLD_ACCENT)
	var bet_row := HBoxContainer.new()
	bet_row.add_theme_constant_override("separation", 10)
	vbox.add_child(bet_row)
	var max_b := mini(_state.cash, _state.tuning.casino_max_bet)
	for bet_amt in [5000, 25000, max_b]:
		var val := int(bet_amt)
		var b := Button.new()
		b.text = ("Bet %s" % Money.format_short(val)) if not _state.casino_bet_used_today else "Played Today"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 68)
		b.disabled = _state.casino_bet_used_today or (val < _state.tuning.casino_min_bet) or (_state.cash < val)
		UiPalette.style_button(b, UiPalette.BTN_AMBER, UiPalette.GOLD_ACCENT)
		b.pressed.connect(func() -> void:
			var res := _state.casino_high_card_bet(val)
			if bool(res.get("won", false)):
				Audio.play(&"victory_fanfare")
			else:
				Audio.play(&"sell_loss")
			Haptics.pulse(30.0)
			facility_action_performed.emit()
			_rebuild()
		)
		bet_row.add_child(b)

	UiPalette.add_label(vbox, "🧼 Cage Chip Laundering (10% House Cut -> 90% Wired Straight to Bank & -15% Heat)", UiPalette.FONT_SUBHEAD, UiPalette.BANK_CYAN)
	var wash_row := HBoxContainer.new()
	wash_row.add_theme_constant_override("separation", 10)
	vbox.add_child(wash_row)
	for wash_amt in [5000, 25000, _state.cash]:
		var val := int(wash_amt)
		var b := Button.new()
		b.text = ("Wash %s" % Money.format_short(val)) if not _state.casino_launder_used_today else "Washed Today"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 68)
		b.disabled = _state.casino_launder_used_today or (val < 2000) or (_state.cash < val)
		UiPalette.style_button(b, UiPalette.BTN_PRIMARY, UiPalette.BANK_CYAN)
		b.pressed.connect(func() -> void:
			_state.casino_launder_chips(val)
			Audio.play(&"cash_register")
			Haptics.pulse(25.0)
			facility_action_performed.emit()
			_rebuild()
		)
		wash_row.add_child(b)


func _build_lawyer_section(vbox: VBoxContainer) -> void:
	var cost_part := _state.get_lawyer_cost(false)
	var cost_all := _state.get_lawyer_cost(true)

	UiPalette.add_label(vbox, "⚖️ Current Police Heat: %.0f%% (%s)" % [
		_state.heat,
		CombatEngine.get_cop_tier_for_heat(_state.heat)["leader_name"]
	], UiPalette.FONT_SUBHEAD, UiPalette.POLICE_RED)

	var part_btn := Button.new()
	part_btn.text = "📂 File Motion to Suppress (-35% Heat) — %s" % Money.format(cost_part)
	part_btn.custom_minimum_size = Vector2(0, 74)
	part_btn.disabled = (_state.heat <= 0.1) or (_state.cash < cost_part)
	UiPalette.style_button(part_btn, UiPalette.BTN_PRIMARY, UiPalette.BANK_CYAN)
	part_btn.pressed.connect(func() -> void:
		_state.hire_lawyer(false)
		Audio.play(&"cash_register")
		facility_action_performed.emit()
		_rebuild()
	)
	vbox.add_child(part_btn)

	var all_btn := Button.new()
	all_btn.text = "⚖️ Expunge All Warrants (Reset Heat to 0%) — %s" % Money.format(cost_all)
	all_btn.custom_minimum_size = Vector2(0, 78)
	all_btn.disabled = (_state.heat <= 0.1) or (_state.cash < cost_all)
	UiPalette.style_button(all_btn, UiPalette.BTN_SUCCESS, UiPalette.CASH_EMERALD)
	all_btn.pressed.connect(func() -> void:
		_state.hire_lawyer(true)
		Audio.play(&"victory_fanfare")
		facility_action_performed.emit()
		_rebuild()
	)
	vbox.add_child(all_btn)


func _build_vip_booth_section(vbox: VBoxContainer) -> void:
	var cost := _state.get_vip_intel_cost()
	UiPalette.add_label(vbox, "🥂 Buy a round for connected Blackstone insiders (%s) to lock in tomorrow's market event:" % Money.format(cost), UiPalette.FONT_ROW_MAIN, UiPalette.TEXT_PRIMARY)

	if not _state.pending_forecast_event.is_empty():
		var f := _state.pending_forecast_event
		UiPalette.add_label(vbox, "🔒 Active Tomorrow Forecast: %s (%s)!" % [
			String(f.get("product_name", "")),
			"4x SPIKE" if String(f.get("event_type", "")) == "spike" else "1/4 FLOOD"
		], UiPalette.FONT_SUBHEAD, UiPalette.GOLD_ACCENT)

	var spike_btn := Button.new()
	spike_btn.text = "🔥 Tip on Tomorrow's 4x SPIKE (Picks from Drugs Sold Here Today) — %s" % Money.format(cost)
	spike_btn.custom_minimum_size = Vector2(0, 78)
	spike_btn.disabled = _state.vip_intel_bought_today or (_state.cash < cost) or _state.is_final_day()
	UiPalette.style_button(spike_btn, UiPalette.BTN_AMBER, UiPalette.SPIKE_AMBER)
	spike_btn.pressed.connect(func() -> void:
		_state.buy_vip_intel("spike_buy_now")
		Audio.play(&"event_spike")
		facility_action_performed.emit()
		_rebuild()
	)
	vbox.add_child(spike_btn)

	var flood_btn := Button.new()
	flood_btn.text = "❄️ Tip on Tomorrow's 1/4 FLOOD (Clear Space for Tomorrow) — %s" % Money.format(cost)
	flood_btn.custom_minimum_size = Vector2(0, 78)
	flood_btn.disabled = _state.vip_intel_bought_today or (_state.cash < cost) or _state.is_final_day()
	UiPalette.style_button(flood_btn, UiPalette.BTN_PRIMARY, UiPalette.FLOOD_CYAN)
	flood_btn.pressed.connect(func() -> void:
		_state.buy_vip_intel("flood_tomorrow")
		Audio.play(&"event_flood")
		facility_action_performed.emit()
		_rebuild()
	)
	vbox.add_child(flood_btn)


func _build_chop_shop_section(vbox: VBoxContainer) -> void:
	var cur_v := OmahaCatalog.get_vehicle(_state.vehicle_tier)
	UiPalette.add_label(vbox, "🚗 Current Ride: %s (+%d Space, +%.0f%% Escape)" % [
		cur_v["name"], int(cur_v["bonus_capacity"]), float(cur_v["escape_bonus"]) * 100.0
	], UiPalette.FONT_SUBHEAD, UiPalette.GOLD_ACCENT)

	for i in range(1, OmahaCatalog.VEHICLES.size()):
		var v_def: Dictionary = OmahaCatalog.VEHICLES[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		vbox.add_child(row)

		var extra_note := " (-20% Cop Dmg)" if float(v_def.get("cop_dmg_reduction", 0.0)) > 0.0 else ""
		var lbl := UiPalette.add_label(row, "%s  —  +%d Trunk Space, +%.0f%% Run%s" % [
			v_def["name"],
			int(v_def["bonus_capacity"]),
			float(v_def["escape_bonus"]) * 100.0,
			extra_note
		], UiPalette.FONT_ROW_MAIN, UiPalette.TEXT_PRIMARY)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var price := int(v_def["price"])
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(240, 60)
		if _state.vehicle_tier >= i:
			btn.text = "OWNED"
			btn.disabled = true
		else:
			btn.text = Money.format(price)
			btn.disabled = (_state.cash < price)
		UiPalette.style_button(btn, UiPalette.BTN_SUCCESS, UiPalette.CASH_EMERALD)
		var tier_idx := i
		btn.pressed.connect(func() -> void:
			_state.buy_vehicle(tier_idx)
			Audio.play(&"drive_engine")
			Haptics.pulse(30.0)
			facility_action_performed.emit()
			_rebuild()
		)
		row.add_child(btn)
