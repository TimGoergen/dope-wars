class_name FacilityOverlay
extends ColorRect

# Contextual modal AND reusable panel builder for the Universal Street ATM
# and all 8 Omaha Metro district signature facilities.

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

	var d_def := OmahaCatalog.get_district(_state.current_district_id)
	var header_title := "🏧 Street ATM" if _mode == "atm" else ("%s %s" % [d_def["icon"], d_def["facility_name"]])

	var vbox := UiPalette.build_modal_shell(self, header_title, UiPalette.BORDER_BRIGHT, true)

	var on_act := func() -> void:
		facility_action_performed.emit()
		_rebuild()

	if _mode == "atm":
		build_banking_card(vbox, _state, on_act)
	else:
		build_district_facility_cards(vbox, _state, on_act)


static func build_district_facility_cards(vbox: VBoxContainer, state: GameState, on_action: Callable) -> void:
	var d_def := OmahaCatalog.get_district(state.current_district_id)
	var fac_id := String(d_def["facility_id"])

	# Always show the Neighbourhood Spot first
	match fac_id:
		"bank_and_loans":
			build_banking_card(vbox, state, on_action)
			build_loan_shark_card(vbox, state, on_action)
		"pawn_gun":
			build_pawn_gun_card(vbox, state, on_action)
			build_banking_card(vbox, state, on_action)
		"clinic":
			build_clinic_card(vbox, state, on_action)
			build_banking_card(vbox, state, on_action)
		"lounge":
			build_lounge_card(vbox, state, on_action)
			build_banking_card(vbox, state, on_action)
		"casino":
			build_casino_card(vbox, state, on_action)
			build_banking_card(vbox, state, on_action)
		"lawyer":
			build_lawyer_card(vbox, state, on_action)
			build_banking_card(vbox, state, on_action)
		"vip_booth":
			build_vip_booth_card(vbox, state, on_action)
			build_banking_card(vbox, state, on_action)
		"chop_shop":
			build_chop_shop_card(vbox, state, on_action)
			build_banking_card(vbox, state, on_action)


static func build_banking_card(vbox: VBoxContainer, state: GameState, on_action: Callable) -> void:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_BG, UiPalette.BANK_CYAN, 20, 3, 26, 24))
	vbox.add_child(box)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 18)
	box.add_child(inner)

	var fee_pct := int(round(state.get_street_atm_fee_rate() * 100.0))
	var int_pct := int(round(state.get_bank_interest_rate() * 100.0))
	UiPalette.add_label(inner, "🏦 First National Bank", 44, UiPalette.BANK_CYAN, false, true)
	UiPalette.add_label(inner, "Balance: %s  (+%d%%/day)  •  Deposit Fee Here: %d%%" % [
		Money.format(state.bank), int_pct, fee_pct
	], 32, UiPalette.TEXT_SECONDARY)

	var dep_row := HBoxContainer.new()
	dep_row.add_theme_constant_override("separation", 14)
	inner.add_child(dep_row)
	for pair in [["Dep 25%", 0.25], ["Dep 50%", 0.50], ["Dep 100%", 1.0]]:
		var b := Button.new()
		b.text = String(pair[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 96)
		b.disabled = (state.cash <= 0)
		UiPalette.style_button(b, UiPalette.BTN_PRIMARY, UiPalette.BANK_CYAN, UiPalette.TEXT_PRIMARY, 34)
		var frac := float(pair[1])
		b.pressed.connect(func() -> void:
			var amt := maxi(1, int(round(float(state.cash) * frac)))
			state.deposit_bank(amt)
			Audio.play(&"cash_register")
			Haptics.pulse(20.0)
			on_action.call()
		)
		dep_row.add_child(b)

	var can_wd := state.can_withdraw_bank()
	if not can_wd:
		UiPalette.add_label(inner, "🔒 Withdrawals require visiting Florence Branch (or VIP Perk)", 30, UiPalette.TEXT_MUTED)
	var wd_row := HBoxContainer.new()
	wd_row.add_theme_constant_override("separation", 14)
	inner.add_child(wd_row)
	for pair in [["Pull 25%", 0.25], ["Pull 50%", 0.50], ["Pull 100%", 1.0]]:
		var b := Button.new()
		b.text = String(pair[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 96)
		b.disabled = (not can_wd) or (state.bank <= 0)
		UiPalette.style_button(b, UiPalette.CARD_ALT_BG, UiPalette.BORDER_BRIGHT, UiPalette.TEXT_PRIMARY, 34)
		var frac := float(pair[1])
		b.pressed.connect(func() -> void:
			var amt := maxi(1, int(round(float(state.bank) * frac)))
			state.withdraw_bank(amt)
			Audio.play(&"cash_register")
			Haptics.pulse(20.0)
			on_action.call()
		)
		wd_row.add_child(b)


static func build_loan_shark_card(vbox: VBoxContainer, state: GameState, on_action: Callable) -> void:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_BG, UiPalette.DEBT_CRIMSON, 20, 3, 26, 24))
	vbox.add_child(box)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 18)
	box.add_child(inner)

	var rate_pct := int(round(state.get_loan_interest_rate() * 100.0))
	var credit_avail := state.get_max_credit_line()
	UiPalette.add_label(inner, "🦈 Big Sal's Loan Shark", 44, UiPalette.DEBT_CRIMSON, false, true)
	UiPalette.add_label(inner, "Debt: %s  (+%d%%/day)  •  Unpaid Days: %d/7" % [
		Money.format(state.debt), rate_pct, state.days_since_loan_payment
	], 32, UiPalette.TEXT_SECONDARY)

	var pay_row := HBoxContainer.new()
	pay_row.add_theme_constant_override("separation", 14)
	inner.add_child(pay_row)
	var max_pay := mini(state.cash, state.debt)
	for pair in [["Pay 10%", 0.10], ["Pay 50%", 0.50], ["Pay Max", 1.0]]:
		var b := Button.new()
		b.text = String(pair[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 96)
		b.disabled = (max_pay <= 0)
		UiPalette.style_button(b, UiPalette.BTN_SUCCESS, UiPalette.CASH_EMERALD, UiPalette.TEXT_PRIMARY, 34)
		var frac := float(pair[1])
		b.pressed.connect(func() -> void:
			var target := int(ceil(float(state.debt) * frac)) if frac < 0.99 else max_pay
			state.pay_loan(mini(state.cash, target))
			Audio.play(&"cash_register")
			Haptics.pulse(25.0)
			on_action.call()
		)
		pay_row.add_child(b)

	if not state.initial_debt_cleared:
		UiPalette.add_label(inner, "🔒 Pay off your starting $5,500 debt to unlock Big Sal's credit line.", 30, UiPalette.SPIKE_AMBER)
	else:
		UiPalette.add_label(inner, "💳 Credit Line Available: %s" % Money.format(credit_avail), 32, UiPalette.GOLD_ACCENT)

	var borrow_row := HBoxContainer.new()
	borrow_row.add_theme_constant_override("separation", 14)
	inner.add_child(borrow_row)
	for pair in [["+$10K", 10000], ["+$25K", 25000], ["Borrow Max", credit_avail]]:
		var b := Button.new()
		var val := int(pair[1])
		b.text = String(pair[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 96)
		b.disabled = (not state.initial_debt_cleared) or (val <= 0) or (val > credit_avail)
		UiPalette.style_button(b, UiPalette.BTN_AMBER, UiPalette.SPIKE_AMBER, UiPalette.TEXT_PRIMARY, 34)
		b.pressed.connect(func() -> void:
			state.borrow_loan(val)
			Audio.play(&"cash_register")
			Haptics.pulse(25.0)
			on_action.call()
		)
		borrow_row.add_child(b)


static func build_pawn_gun_card(vbox: VBoxContainer, state: GameState, on_action: Callable) -> void:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_BG, UiPalette.GOLD_ACCENT, 20, 3, 26, 24))
	vbox.add_child(box)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 18)
	box.add_child(inner)

	UiPalette.add_label(inner, "🔫 24th St Pawn & Gun", 44, UiPalette.GOLD_ACCENT, false, true)
	UiPalette.add_label(inner, "Weapon Slots: %d / %d  (50%% trade-in when full)" % [
		state.weapons.size(), state.get_max_weapon_slots()
	], 32, UiPalette.TEXT_SECONDARY)

	for w_def in OmahaCatalog.WEAPONS:
		var wid := String(w_def["id"])
		var price := int(w_def["price"])
		var trade_in := 0
		if state.weapons.size() >= state.get_max_weapon_slots() and not state.weapons.is_empty():
			var weakest := OmahaCatalog.get_weapon(state.weapons.back())
			if int(w_def["damage"]) > int(weakest["damage"]):
				trade_in = int(round(float(weakest["price"]) * state.tuning.weapon_trade_in_pct))
		var net_price := maxi(0, price - trade_in)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		inner.add_child(row)

		var info := UiPalette.add_label(row, "%s\n%d Dmg • %d%% Hit" % [
			w_def["name"], int(w_def["damage"]), int(round(float(w_def["hit_chance"]) * 100.0))
		], 34, UiPalette.TEXT_PRIMARY)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(300, 92)
		var slots_full := (state.weapons.size() >= state.get_max_weapon_slots())
		var can_upgrade := (not slots_full) or (trade_in > 0)
		btn.text = ("Buy %s" % Money.format_short(price)) if trade_in == 0 else ("Upgr %s" % Money.format_short(net_price))
		btn.disabled = (not can_upgrade) or (state.cash < net_price)
		UiPalette.style_button(btn, UiPalette.BTN_PRIMARY, UiPalette.BANK_CYAN, UiPalette.TEXT_PRIMARY, 34)
		btn.pressed.connect(func() -> void:
			var res := state.buy_weapon(wid)
			if bool(res.get("ok", false)):
				Audio.play(&"cash_register")
				Haptics.pulse(25.0)
				on_action.call()
		)
		row.add_child(btn)

	var vest_btn := Button.new()
	vest_btn.text = "🛡️ Kevlar Vest (+50 Armor) — %s" % Money.format(state.tuning.armor_vest_price)
	vest_btn.custom_minimum_size = Vector2(0, 104)
	vest_btn.disabled = (state.armor >= 50) or (state.cash < state.tuning.armor_vest_price)
	UiPalette.style_button(vest_btn, UiPalette.BTN_SUCCESS, UiPalette.CASH_EMERALD, UiPalette.TEXT_PRIMARY, 38)
	vest_btn.pressed.connect(func() -> void:
		state.buy_armor(false)
		Audio.play(&"cash_register")
		on_action.call()
	)
	inner.add_child(vest_btn)

	var plate_btn := Button.new()
	plate_btn.text = "🛡️ Plate Carrier (100 Armor) — %s" % Money.format(state.tuning.armor_plate_price)
	plate_btn.custom_minimum_size = Vector2(0, 104)
	plate_btn.disabled = (state.armor >= 100) or (state.cash < state.tuning.armor_plate_price)
	UiPalette.style_button(plate_btn, UiPalette.BTN_SUCCESS, UiPalette.CASH_EMERALD, UiPalette.TEXT_PRIMARY, 38)
	plate_btn.pressed.connect(func() -> void:
		state.buy_armor(true)
		Audio.play(&"cash_register")
		on_action.call()
	)
	inner.add_child(plate_btn)


static func build_clinic_card(vbox: VBoxContainer, state: GameState, on_action: Callable) -> void:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_BG, UiPalette.CASH_EMERALD, 20, 3, 26, 24))
	vbox.add_child(box)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 20)
	box.add_child(inner)

	var cost_per_hp := state.get_heal_cost_per_hp()
	var missing := maxi(0, state.max_health - state.health)
	var full_cost := missing * cost_per_hp

	UiPalette.add_label(inner, "🏥 Benson Back-Alley Clinic", 44, UiPalette.CASH_EMERALD, false, true)
	UiPalette.add_label(inner, "Health: %d / %d HP  •  Rate: %s / HP" % [
		state.health, state.max_health, Money.format(cost_per_hp)
	], 34, UiPalette.TEXT_SECONDARY)

	var heal_btn := Button.new()
	heal_btn.text = ("💉 FULL HEAL (+%d HP • %s)" % [missing, Money.format(mini(state.cash, full_cost))]) if missing > 0 else "❤️ Full Health"
	heal_btn.custom_minimum_size = Vector2(0, 112)
	heal_btn.disabled = (missing <= 0) or (state.cash < cost_per_hp)
	UiPalette.style_button(heal_btn, UiPalette.BTN_SUCCESS, UiPalette.CASH_EMERALD, UiPalette.TEXT_PRIMARY, 42)
	heal_btn.pressed.connect(func() -> void:
		state.heal_player(missing)
		Audio.play(&"buy")
		Haptics.pulse(25.0)
		on_action.call()
	)
	inner.add_child(heal_btn)

	var kidney_btn := Button.new()
	kidney_btn.text = ("🔪 SELL KIDNEY (+%s • Max HP 80)" % Money.format(state.tuning.kidney_sale_payout)) if not state.kidney_sold else "🔪 Kidney Already Sold"
	kidney_btn.custom_minimum_size = Vector2(0, 104)
	kidney_btn.disabled = state.kidney_sold
	UiPalette.style_button(kidney_btn, UiPalette.BTN_DANGER, UiPalette.DEBT_CRIMSON, UiPalette.TEXT_PRIMARY, 38)
	kidney_btn.pressed.connect(func() -> void:
		state.sell_kidney()
		Audio.play(&"enforcer_hit")
		Haptics.pulse(40.0)
		on_action.call()
	)
	inner.add_child(kidney_btn)


static func build_lounge_card(vbox: VBoxContainer, state: GameState, on_action: Callable) -> void:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_BG, UiPalette.GOLD_ACCENT, 20, 3, 26, 24))
	vbox.add_child(box)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 20)
	box.add_child(inner)

	var cost := state.get_next_crew_cost()
	UiPalette.add_label(inner, "🍸 Old Market Crew Lounge", 44, UiPalette.GOLD_ACCENT, false, true)
	UiPalette.add_label(inner, "Active Crew: %d / %d Runners\n+10 Coat Space, +1 Gun Slot, 30 HP shared combat shield." % [
		state.crew_count, state.tuning.crew_max_count
	], 32, UiPalette.TEXT_SECONDARY)

	var hire_btn := Button.new()
	hire_btn.text = ("👥 HIRE RUNNER #%d (%s)" % [state.crew_count + 1, Money.format(cost)]) if state.crew_count < state.tuning.crew_max_count else "👥 Crew Roster Full"
	hire_btn.custom_minimum_size = Vector2(0, 112)
	hire_btn.disabled = (state.crew_count >= state.tuning.crew_max_count) or (state.cash < cost)
	UiPalette.style_button(hire_btn, UiPalette.BTN_PRIMARY, UiPalette.GOLD_ACCENT, UiPalette.TEXT_PRIMARY, 42)
	hire_btn.pressed.connect(func() -> void:
		state.hire_crew()
		Audio.play(&"cash_register")
		Haptics.pulse(25.0)
		on_action.call()
	)
	inner.add_child(hire_btn)


static func build_casino_card(vbox: VBoxContainer, state: GameState, on_action: Callable) -> void:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_BG, UiPalette.GOLD_ACCENT, 20, 3, 26, 24))
	vbox.add_child(box)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 18)
	box.add_child(inner)

	UiPalette.add_label(inner, "🎰 Ameristar Riverboat Casino", 44, UiPalette.GOLD_ACCENT, false, true)
	UiPalette.add_label(inner, "🃏 High-Card Double-or-Nothing (50/50):", 34, UiPalette.TEXT_PRIMARY)

	var bet_row := HBoxContainer.new()
	bet_row.add_theme_constant_override("separation", 14)
	inner.add_child(bet_row)
	var max_b := mini(state.cash, state.tuning.casino_max_bet)
	for pair in [["Bet $5K", 5000], ["Bet $25K", 25000], ["Bet Max", max_b]]:
		var val := int(pair[1])
		var b := Button.new()
		b.text = String(pair[0]) if not state.casino_bet_used_today else "Played"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 96)
		b.disabled = state.casino_bet_used_today or (val < state.tuning.casino_min_bet) or (state.cash < val)
		UiPalette.style_button(b, UiPalette.BTN_AMBER, UiPalette.GOLD_ACCENT, UiPalette.TEXT_PRIMARY, 34)
		b.pressed.connect(func() -> void:
			var res := state.casino_high_card_bet(val)
			if bool(res.get("won", false)):
				Audio.play(&"victory_fanfare")
			else:
				Audio.play(&"sell_loss")
			Haptics.pulse(30.0)
			on_action.call()
		)
		bet_row.add_child(b)

	UiPalette.add_label(inner, "🧼 Chip Wash (90% to Bank + -15% Heat):", 34, UiPalette.BANK_CYAN)
	var wash_row := HBoxContainer.new()
	wash_row.add_theme_constant_override("separation", 14)
	inner.add_child(wash_row)
	for pair in [["Wash $5K", 5000], ["Wash $25K", 25000], ["Wash All", state.cash]]:
		var val := int(pair[1])
		var b := Button.new()
		b.text = String(pair[0]) if not state.casino_launder_used_today else "Washed"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 96)
		b.disabled = state.casino_launder_used_today or (val < 2000) or (state.cash < val)
		UiPalette.style_button(b, UiPalette.BTN_PRIMARY, UiPalette.BANK_CYAN, UiPalette.TEXT_PRIMARY, 34)
		b.pressed.connect(func() -> void:
			state.casino_launder_chips(val)
			Audio.play(&"cash_register")
			Haptics.pulse(25.0)
			on_action.call()
		)
		wash_row.add_child(b)


static func build_lawyer_card(vbox: VBoxContainer, state: GameState, on_action: Callable) -> void:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_BG, UiPalette.POLICE_RED, 20, 3, 26, 24))
	vbox.add_child(box)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 20)
	box.add_child(inner)

	var cost_part := state.get_lawyer_cost(false)
	var cost_all := state.get_lawyer_cost(true)
	var supp_pct_int := int(round(state.tuning.lawyer_relative_suppress_pct * 100.0))
	var drop_pct := state.heat * state.tuning.lawyer_relative_suppress_pct

	UiPalette.add_label(inner, "⚖️ West O Defense Attorney", 44, UiPalette.POLICE_RED, false, true)
	UiPalette.add_label(inner, "Police Heat: %.1f%% (%s)" % [
		state.heat,
		CombatEngine.get_cop_tier_for_heat(state.heat)["leader_name"]
	], 34, UiPalette.TEXT_SECONDARY)

	var part_btn := Button.new()
	part_btn.text = "📂 Suppress Warrants (-%d%% • -%.1f%% Heat) — %s" % [supp_pct_int, drop_pct, Money.format(cost_part)]
	part_btn.custom_minimum_size = Vector2(0, 104)
	part_btn.disabled = (state.heat <= 0.1) or (state.cash < cost_part)
	UiPalette.style_button(part_btn, UiPalette.BTN_PRIMARY, UiPalette.BANK_CYAN, UiPalette.TEXT_PRIMARY, 36)
	part_btn.pressed.connect(func() -> void:
		state.hire_lawyer(false)
		Audio.play(&"cash_register")
		on_action.call()
	)
	inner.add_child(part_btn)

	var all_btn := Button.new()
	all_btn.text = "⚖️ Expunge All (Clear to 0%% Heat) — %s" % Money.format(cost_all)
	all_btn.custom_minimum_size = Vector2(0, 108)
	all_btn.disabled = (state.heat <= 0.1) or (state.cash < cost_all)
	UiPalette.style_button(all_btn, UiPalette.BTN_SUCCESS, UiPalette.CASH_EMERALD, UiPalette.TEXT_PRIMARY, 38)
	all_btn.pressed.connect(func() -> void:
		state.hire_lawyer(true)
		Audio.play(&"victory_fanfare")
		on_action.call()
	)
	inner.add_child(all_btn)


static func build_vip_booth_card(vbox: VBoxContainer, state: GameState, on_action: Callable) -> void:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_BG, UiPalette.PURPLE_VIP, 20, 3, 26, 24))
	vbox.add_child(box)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 20)
	box.add_child(inner)

	var cost := state.get_vip_intel_cost()
	UiPalette.add_label(inner, "🥂 Blackstone VIP Insider Booth", 44, UiPalette.PURPLE_VIP, false, true)
	UiPalette.add_label(inner, "Guarantee tomorrow's market event (%s):" % Money.format(cost), 32, UiPalette.TEXT_SECONDARY)

	if not state.pending_forecast_event.is_empty():
		var f := state.pending_forecast_event
		UiPalette.add_label(inner, "🔒 Locked Forecast: %s (%s)!" % [
			String(f.get("product_name", "")),
			"4x SPIKE" if String(f.get("event_type", "")) == "spike" else "1/4 FLOOD"
		], 36, UiPalette.GOLD_ACCENT, true, true)

	var spike_btn := Button.new()
	spike_btn.text = "🔥 Lock Tomorrow 4x SPIKE — %s" % Money.format(cost)
	spike_btn.custom_minimum_size = Vector2(0, 104)
	spike_btn.disabled = state.vip_intel_bought_today or (state.cash < cost) or state.is_final_day()
	UiPalette.style_button(spike_btn, UiPalette.BTN_AMBER, UiPalette.SPIKE_AMBER, UiPalette.TEXT_PRIMARY, 38)
	spike_btn.pressed.connect(func() -> void:
		state.buy_vip_intel("spike_buy_now")
		Audio.play(&"event_spike")
		on_action.call()
	)
	inner.add_child(spike_btn)

	var flood_btn := Button.new()
	flood_btn.text = "❄️ Lock Tomorrow 1/4 FLOOD — %s" % Money.format(cost)
	flood_btn.custom_minimum_size = Vector2(0, 104)
	flood_btn.disabled = state.vip_intel_bought_today or (state.cash < cost) or state.is_final_day()
	UiPalette.style_button(flood_btn, UiPalette.BTN_PRIMARY, UiPalette.FLOOD_CYAN, UiPalette.TEXT_PRIMARY, 38)
	flood_btn.pressed.connect(func() -> void:
		state.buy_vip_intel("flood_tomorrow")
		Audio.play(&"event_flood")
		on_action.call()
	)
	inner.add_child(flood_btn)


static func build_chop_shop_card(vbox: VBoxContainer, state: GameState, on_action: Callable) -> void:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_BG, UiPalette.CASH_EMERALD, 20, 3, 26, 24))
	vbox.add_child(box)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 18)
	box.add_child(inner)

	var cur_v := OmahaCatalog.get_vehicle(state.vehicle_tier)
	UiPalette.add_label(inner, "🚗 Bellevue Hwy 75 Auto & Chop Shop", 44, UiPalette.CASH_EMERALD, false, true)
	UiPalette.add_label(inner, "Current Ride: %s (+%d Space, +%.0f%% Escape)" % [
		cur_v["name"], int(cur_v["bonus_capacity"]), float(cur_v["escape_bonus"]) * 100.0
	], 32, UiPalette.TEXT_SECONDARY)

	for i in range(1, OmahaCatalog.VEHICLES.size()):
		var v_def: Dictionary = OmahaCatalog.VEHICLES[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		inner.add_child(row)

		var extra_note := " • -20% Cop Dmg" if float(v_def.get("cop_dmg_reduction", 0.0)) > 0.0 else ""
		var lbl := UiPalette.add_label(row, "%s\n+%d Space • +%.0f%% Run%s" % [
			v_def["name"],
			int(v_def["bonus_capacity"]),
			float(v_def["escape_bonus"]) * 100.0,
			extra_note
		], 34, UiPalette.TEXT_PRIMARY)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var price := int(v_def["price"])
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(280, 92)
		if state.vehicle_tier >= i:
			btn.text = "OWNED"
			btn.disabled = true
		else:
			btn.text = Money.format_short(price)
			btn.disabled = (state.cash < price)
		UiPalette.style_button(btn, UiPalette.BTN_SUCCESS, UiPalette.CASH_EMERALD, UiPalette.TEXT_PRIMARY, 34)
		var tier_idx := i
		btn.pressed.connect(func() -> void:
			state.buy_vehicle(tier_idx)
			Audio.play(&"drive_engine")
			Haptics.pulse(30.0)
			on_action.call()
		)
		row.add_child(btn)
