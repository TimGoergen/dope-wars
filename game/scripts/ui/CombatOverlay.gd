class_name CombatOverlay
extends ColorRect

# Police Ambush shootout modal (Fight / Run / Surrender) with Shared 50/50 Crew Target Pool telemetry.

signal combat_updated()

var _state: GameState


func _init() -> void:
	color = UiPalette.MODAL_BACKDROP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func refresh(state: GameState) -> void:
	_state = state
	for c in get_children():
		c.queue_free()

	if not _state.is_in_combat():
		visible = false
		return

	visible = true
	var enc := _state.active_combat
	var cops: Array = enc.get("cop_hp_list", [])
	var front_cop_hp := int(cops[0]) if not cops.is_empty() else 0
	var unit_max_hp := int(enc.get("unit_hp", 25))
	var backup_count := maxi(0, cops.size() - 1)
	var escape_pct := int(round(CombatEngine.get_escape_chance(enc, _state.vehicle_tier, _state.tuning) * 100.0))

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(960, 0)
	card.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.PANEL_BG, UiPalette.POLICE_RED, 20, 4, 34, 30))
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	card.add_child(vbox)

	# Police Siren Header
	var title := UiPalette.add_label(vbox, "🚨 POLICE AMBUSH — %s 🚨" % String(enc.get("short_badge", "OPD")), UiPalette.FONT_TITLE, UiPalette.POLICE_RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var sub := UiPalette.add_label(vbox, "%s  |  Officers Remaining: %d (Backup: %d)" % [
		String(enc.get("leader_name", "Officer Hardass")),
		cops.size(),
		backup_count
	], UiPalette.FONT_SUBHEAD, UiPalette.TEXT_PRIMARY)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Pursuing Unit vs Player/Crew Status Box
	var status_box := PanelContainer.new()
	status_box.add_theme_stylebox_override("panel", UiPalette.make_box(UiPalette.CARD_BG, UiPalette.BORDER_SLATE, 12, 2, 20, 16))
	vbox.add_child(status_box)

	var status_vbox := VBoxContainer.new()
	status_vbox.add_theme_constant_override("separation", 10)
	status_box.add_child(status_vbox)

	UiPalette.add_label(status_vbox, "🚓 Lead Target HP: %d / %d   |   Unit Firepower: %d–%d dmg" % [
		front_cop_hp, unit_max_hp, int(enc.get("min_dmg", 4)), int(enc.get("max_dmg", 9))
	], UiPalette.FONT_ROW_MAIN, UiPalette.POLICE_BLUE)

	var gun_summary := "Unarmed (0 Guns)"
	if not _state.weapons.is_empty():
		var top_w := OmahaCatalog.get_weapon(_state.weapons[0])
		gun_summary = "%s (%d dmg) | %d/%d Armed Shooters" % [
			top_w["short_name"],
			int(top_w["damage"]),
			mini(_state.weapons.size(), 1 + _state.crew_count),
			1 + _state.crew_count
		]

	var crew_shield_str := "No Crew"
	if _state.crew_count > 0:
		crew_shield_str = "%d Crew (Front Runner: %d/%d HP, 50%% Shared Target)" % [
			_state.crew_count,
			int(enc.get("front_crew_hp", _state.tuning.crew_encounter_hp)),
			_state.tuning.crew_encounter_hp
		]

	UiPalette.add_label(status_vbox, "❤️ Your HP: %d/%d   |   🛡️ Armor: %d   |   👥 %s" % [
		_state.health, _state.max_health, _state.armor, crew_shield_str
	], UiPalette.FONT_ROW_MAIN, UiPalette.CASH_EMERALD)

	UiPalette.add_label(status_vbox, "🔫 Arsenal: %s   |   🚗 Escape Chance: %d%%" % [
		gun_summary, escape_pct
	], UiPalette.FONT_ROW_SUB, UiPalette.GOLD_ACCENT)

	# Combat Log Line
	var log_lbl := UiPalette.add_label(vbox, String(enc.get("last_log", "")), UiPalette.FONT_ROW_MAIN, UiPalette.SPIKE_AMBER)
	log_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Action Buttons: FIGHT / RUN / SURRENDER
	var btn_vbox := VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 14)
	vbox.add_child(btn_vbox)

	var fight_btn := Button.new()
	fight_btn.text = "🔫 FIGHT BACK (Fire %d Weapon%s)" % [
		mini(_state.weapons.size(), 1 + _state.crew_count),
		"s" if mini(_state.weapons.size(), 1 + _state.crew_count) != 1 else ""
	]
	fight_btn.custom_minimum_size = Vector2(0, 82)
	fight_btn.disabled = _state.weapons.is_empty()
	UiPalette.style_button(fight_btn, UiPalette.BTN_DANGER, UiPalette.POLICE_RED, UiPalette.TEXT_PRIMARY, UiPalette.FONT_HEADER)
	fight_btn.pressed.connect(func() -> void:
		Audio.play(&"gunshot")
		Haptics.pulse(45.0)
		_state.combat_fight()
		combat_updated.emit()
	)
	btn_vbox.add_child(fight_btn)

	var run_btn := Button.new()
	var v_name: String = OmahaCatalog.get_vehicle(_state.vehicle_tier)["short_name"]
	run_btn.text = "💨 FLOOR IT & RUN (%d%% Chance — %s)" % [escape_pct, v_name]
	run_btn.custom_minimum_size = Vector2(0, 78)
	UiPalette.style_button(run_btn, UiPalette.BTN_PRIMARY, UiPalette.BANK_CYAN, UiPalette.TEXT_PRIMARY, UiPalette.FONT_SUBHEAD)
	run_btn.pressed.connect(func() -> void:
		Audio.play(&"drive_engine")
		Haptics.pulse(30.0)
		_state.combat_run()
		combat_updated.emit()
	)
	btn_vbox.add_child(run_btn)

	var surr_btn := Button.new()
	surr_btn.text = "🏳️ SURRENDER (Forfeit Stash & 25% Pocket Cash, Reset Heat to 10%)"
	surr_btn.custom_minimum_size = Vector2(0, 68)
	UiPalette.style_button(surr_btn, UiPalette.CARD_BG, UiPalette.BORDER_SLATE, UiPalette.TEXT_SECONDARY, UiPalette.FONT_ROW_SUB)
	surr_btn.pressed.connect(func() -> void:
		Audio.play(&"sell_loss")
		Haptics.pulse(35.0)
		_state.combat_surrender()
		combat_updated.emit()
	)
	btn_vbox.add_child(surr_btn)
